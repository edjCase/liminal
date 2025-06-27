import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import List "mo:new-base/List";
import Runtime "mo:new-base/Runtime";
import Order "mo:new-base/Order";
import Nat "mo:new-base/Nat";
import Debug "mo:base/Debug";
import MimeType "MimeType";
import QualityFactor "QualityFactor";

module {

    public type RequestedEncoding = {
        #identity;
        #wildcard;
        #gzip;
        #deflate;
        #br;
        #compress;
        #zstd;
    };

    public type EncodingPreference = {
        requestedEncodings : [RequestedEncoding];
        disallowedEncodings : [RequestedEncoding];
    };

    public type ContentPreference = {
        requestedTypes : [MimeType.RawMimeType];
        disallowedTypes : [MimeType.RawMimeType];
    };

    type WeightedContentType = {
        contentType : MimeType.RawMimeType;
        qValue : Nat; // 0-1000
    };

    // === PARSE ACCEPT-ENCODING HEADER ===
    /// Parses the Accept-Encoding header to determine client encoding preferences.
    /// Returns a list of supported encodings ordered by client preference (quality values).
    /// Handles quality factors (q-values) and common encodings like gzip, deflate, br.
    ///
    /// ```motoko
    /// let preferences = ContentNegotiation.parseEncodingTypes("gzip, deflate;q=0.8, br;q=0.9");
    /// // Returns encodings ordered by preference: br (0.9), gzip (1.0), deflate (0.8)
    /// ```
    public func parseEncodingTypes(headerText : Text) : EncodingPreference {
        // Split by comma and trim each entry
        let entries = headerText
        |> Text.split(_, #char(','))
        |> Iter.toArray(_);

        type EncodingWithWeight = {
            encoding : RequestedEncoding;
            weight : Nat; // 0-1000
        };
        let encodings = List.empty<EncodingWithWeight>();
        label f for (entry in entries.vals()) {
            // Remove quality parameter if present
            let parts = Text.split(entry, #char(';'));
            let ?encodingText = parts.next() else Runtime.trap("Invalid Accept-Encoding header: " # headerText);
            let ?encoding = encodingFromText(encodingText) else {
                continue f;
            };
            let weight : Nat = parseHeaderWeight(parts);
            List.add(
                encodings,
                {
                    encoding = encoding;
                    weight;
                },
            );
        };
        let orderedEncodings = List.values(encodings)
        |> Iter.sort<EncodingWithWeight>(
            _,
            func(a : EncodingWithWeight, b : EncodingWithWeight) : Order.Order = Nat.compare(b.weight, a.weight),
        );

        let requestedEncodings = List.empty<RequestedEncoding>();
        let disallowedEncodings = List.empty<RequestedEncoding>();
        label f for (encoding in orderedEncodings) {
            if (encoding.weight == 0) {
                List.add(disallowedEncodings, encoding.encoding);
            } else {
                List.add(requestedEncodings, encoding.encoding);
            };
        };
        {
            requestedEncodings = List.toArray(requestedEncodings);
            disallowedEncodings = List.toArray(disallowedEncodings);
        };
    };

    // === PARSE ACCEPT HEADER ===
    /// Parses the Accept header to determine client content type preferences.
    /// Returns a list of MIME types ordered by client preference, including quality factors.
    /// Supports wildcard types and complex Accept header syntax.
    ///
    /// ```motoko
    /// let preferences = ContentNegotiation.parseContentTypes("application/json, text/html;q=0.9, */*;q=0.8");
    /// // Returns content types ordered by preference: application/json (1.0), text/html (0.9), */* (0.8)
    /// ```
    public func parseContentTypes(headerText : Text) : ContentPreference {
        if (headerText == "") {
            return {
                requestedTypes = [];
                disallowedTypes = [];
            };
        };

        // Split by comma and trim each entry
        let entries = headerText
        |> Text.split(_, #char(','))
        |> Iter.toArray(_);

        let contentTypes = List.empty<WeightedContentType>();
        label entryLoop for (entry in entries.vals()) {
            let ?(mimeType, qValue) = MimeType.fromTextRaw(entry) else {
                Debug.print("Invalid Accept header: " # entry # ", skipping...");
                continue entryLoop;
            };

            List.add(
                contentTypes,
                {
                    contentType = mimeType;
                    qValue = qValue;
                } : WeightedContentType,
            );
        };

        // Sort content types by weight (highest first)
        let orderedTypes = List.values(contentTypes)
        |> Iter.sort<WeightedContentType>(
            _,
            func(a : WeightedContentType, b : WeightedContentType) : Order.Order = Nat.compare(b.qValue, a.qValue),
        );

        // Separate into requested and disallowed types
        let requestedTypes = List.empty<MimeType.RawMimeType>();
        let disallowedTypes = List.empty<MimeType.RawMimeType>();

        for (weightedType in orderedTypes) {
            if (weightedType.qValue == 0) {
                List.add(disallowedTypes, weightedType.contentType);
            } else {
                List.add(requestedTypes, weightedType.contentType);
            };
        };

        {
            requestedTypes = List.toArray(requestedTypes);
            disallowedTypes = List.toArray(disallowedTypes);
        };
    };

    func encodingFromText(encoding : Text) : ?RequestedEncoding {
        let normalizedEncoding = encoding
        |> Text.trim(_, #char(' '))
        |> Text.toLower(_);
        let encodingVariant = switch (normalizedEncoding) {
            case ("identity") #identity;
            case ("gzip") #gzip;
            case ("deflate") #deflate;
            case ("br") #br;
            case ("compress") #compress;
            case ("zstd") #zstd;
            case ("*") #wildcard;
            case (_) {
                return null;
            };
        };
        ?encodingVariant;
    };

    // Extract weight from header parts (common function for both encodings and content types)
    func parseHeaderWeight(parts : Iter.Iter<Text>) : Nat {
        switch (parts.next()) {
            case (null) 1000; // Default q-value is 1.0
            case (?weightText) {
                let parts = Text.split(weightText, #char('='));
                let ?q : ?Nat = do ? {
                    let q = parts.next()!;
                    if (Text.trim(q, #char(' ')) != "q") {
                        null!;
                    } else {
                        let qValue = parts.next()!;
                        QualityFactor.fromText(qValue)!;
                    };
                } else return 1000; // Default if parsing fails

                q;
            };
        };
    };

};
