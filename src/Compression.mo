import HttpContext "./HttpContext";
import Gzip "mo:compression/Gzip";
// import Brotli "mo:compression/Brotli";
import Deflate "mo:compression/Deflate";
import Lzss "mo:compression/LZSS";
import Blob "mo:new-base/Blob";
import Text "mo:new-base/Text";
import Array "mo:new-base/Array";
import Buffer "mo:base/Buffer";
import List "mo:new-base/List";
import TextX "mo:xtended-text/TextX";
import Nat "mo:new-base/Nat";
import Iter "mo:new-base/Iter";
import Int "mo:new-base/Int";
import Order "mo:new-base/Order";
import Runtime "mo:new-base/Runtime";
import App "App";
import NatX "mo:xtended-numbers/NatX";

module {

    // Configuration for compression middleware
    public type Config = {
        // Minimum size in bytes before compression is applied
        minSize : Nat;

        // Mime types that should be compressed
        mimeTypes : [Text];

        // Whether to skip compression for certain requests
        skipCompressionIf : ?SkipFunction;
    };

    // Skip function determines if a request should skip compression
    public type SkipFunction = HttpContext.HttpContext -> Bool;

    public func compressResponse(
        context : HttpContext.HttpContext,
        response : App.HttpResponse,
        config : Config,
    ) : App.HttpResponse {
        // Skip if there's no body to compress
        let ?body = response.body else return response;
        // Skip if body is too small
        if (body.size() < config.minSize) {
            return response;
        };

        // Skip if response is already compressed
        if (isAlreadyCompressed(response.headers)) {
            return response;
        };

        // Skip if content type is not compressible
        let contentType = getContentType(response.headers);
        if (not isCompressibleContentType(contentType, config.mimeTypes)) {
            return response;
        };

        // Get client's accepted encodings in order of preference
        let ?encodingsHeader = context.getHeader("accept-encoding") else {
            // No Accept-Encoding header, so return the original response
            return response;
        };
        let acceptedEncodings = parseEncodingTypes(encodingsHeader);

        // Skip if custom skip function is provided and returns true
        switch (config.skipCompressionIf) {
            case (?skipFn) {
                if (skipFn(context)) {
                    return response;
                };
            };
            case (null) {};
        };

        // Try to compress with the first compatible encoding
        label f for (requestedEncoding in acceptedEncodings.requestedEncodings.vals()) {
            let outputCompressedEncoding = switch (requestedEncoding) {
                case (#identity) return response;
                case (#gzip) #gzip;
                case (#deflate) #deflate;
                case (#br) #br;
                case (#compress) #compress;
                case (#zstd) #zstd;
                case (#wildcard) {
                    let supportedEncodings = [
                        #gzip,
                        #deflate,
                    ]; // TODO make this dynamic
                    label f for (encoding in supportedEncodings.vals()) {
                        for (disallowedEncoding in acceptedEncodings.disallowedEncodings.vals()) {
                            if (encoding == disallowedEncoding) {
                                continue f; // Skip if encoding is disallowed
                            };
                        };
                        // Try to compress with the first compatible encoding
                        let ?compressedResponse = tryCompress(
                            response,
                            body,
                            encoding,
                        ) else continue f;
                        return compressedResponse;
                    };
                    continue f;
                };
            };
            let ?compressedResponse = tryCompress(
                response,
                body,
                outputCompressedEncoding,
            ) else continue f;
            return compressedResponse;
        };

        for (disallowedEncoding in acceptedEncodings.disallowedEncodings.vals()) {
            if (disallowedEncoding == #identity) {
                // If identity encoding is not allowed, return an error
                return context.buildErrorResponse(
                    #notAcceptable,
                    #message("No suitable encoding found for " # encodingsHeader # " in Accept-Encoding header"),
                );
            };
        };

        // Identity encoding, don't compress
        return response;
    };

    private func tryCompress(
        response : App.HttpResponse,
        body : Blob,
        encoding : OutputCompressedEncoding,
    ) : ?App.HttpResponse {
        let bytes = Blob.toArray(body);
        let ?compressedBody = compressWithEncoding(encoding, bytes) else return null;
        // Skip if compression didn't reduce size
        if (compressedBody.size() >= body.size()) {
            return null;
        };

        // Update headers
        let headers = response.headers
        |> removeHeader(_, "content-length")
        |> List.fromArray<(Text, Text)>(_);
        let encodingName = encodingToText(encoding);
        List.add(headers, ("Content-Encoding", encodingName));

        switch (getHeader(headers, "Vary")) {
            case (null) {
                List.add(headers, ("Vary", "Accept-Encoding"));
            };
            case (?(existing, i)) {
                List.put(headers, i, ("Vary", existing # ", Accept-Encoding"));
            };
        };
        List.add(headers, ("Content-Length", Nat.toText(compressedBody.size())));

        // Return compressed response
        return ?{
            response with
            headers = List.toArray(headers);
            body = ?compressedBody;
        };
    };

    // Convert encoding enum to text
    private func encodingToText(encoding : OutputCompressedEncoding) : Text {
        switch (encoding) {
            case (#gzip) "gzip";
            case (#deflate) "deflate";
            case (#br) "br";
            case (#compress) "compress";
            case (#zstd) "zstd";
        };
    };

    // Compress with specified encoding
    private func compressWithEncoding(encoding : OutputCompressedEncoding, data : [Nat8]) : ?Blob {
        switch (encoding) {
            case (#gzip) {
                let encoder = Gzip.EncoderBuilder().build();
                encoder.encode(data);
                let encoded = encoder.finish();
                return ?compressedBlobFromChunks(encoded.chunks);
            };
            case (#deflate) {
                let encoder = Deflate.buildEncoder({
                    block_size = 1048576; // 1MB
                    dynamic_huffman = false;
                    lzss = ?Lzss.Encoder(null);
                });
                encoder.encode(data);
                let encoded = encoder.finish();
                return ?Blob.fromArray(Iter.toArray(encoded.bytes()));
            };
            case (_) return null; // Unsupported encoding
        };
    };

    // Helper to convert encoder output chunks to blob
    private func compressedBlobFromChunks(chunks : [[Nat8]]) : Blob {
        var totalSize = 0;
        for (chunk in chunks.vals()) {
            totalSize += chunk.size();
        };

        let buffer = Buffer.Buffer<Nat8>(totalSize);
        for (chunk in chunks.vals()) {
            for (byte in chunk.vals()) {
                buffer.add(byte);
            };
        };

        return Blob.fromArray(Buffer.toArray(buffer));
    };

    type OutputCompressedEncoding = {
        #gzip;
        #deflate;
        #br;
        #compress;
        #zstd;
    };
    type RequestedEncoding = OutputCompressedEncoding or {
        #identity;
        #wildcard;
    };

    private func parseEncodingTypes(headerText : Text) : {
        requestedEncodings : [RequestedEncoding];
        disallowedEncodings : [RequestedEncoding];
    } {
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
            let weight : Nat = switch (parts.next()) {
                case (null) 1000;
                case (?weightText) {
                    let parts = Text.split(weightText, #char('='));
                    let ?q : ?Nat = do ? {
                        let q = parts.next()!;
                        if (q != "q") {
                            null!;
                        } else {
                            let qValue = parts.next()!;
                            parseQuality(qValue)!;
                        };
                    } else continue f;

                    q;
                };
            };
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
        }

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

    // Returns integer value between 0 and 1000, where 1000 is the highest quality
    private func parseQuality(text : Text) : ?Nat {
        let trimmed = Text.trim(text, #char(' '));

        // Handle empty string
        if (Text.size(trimmed) == 0) {
            return null;
        };

        // Split on decimal point
        let parts = Text.split(trimmed, #char('.'));
        let ?intPartText = parts.next() else return null; // Invalid format - no integer part
        let decimalPartTextOrNull = parts.next();
        let null = parts.next() else return null; // Invalid format - too many decimal points

        // Parse integer part
        switch (intPartText) {
            case ("" or "0") (); // Continue to decimal part
            case ("1") return ?1000; // Can't be higher than 1000, so just return early
            case (_) return null; // Has to be 0 or 1 or empty string
        };

        // If no decimal part, return early
        switch (decimalPartTextOrNull) {
            case (null or ?"" or ?"0") return ?0; // 0.0 or 0
            case (?decimalPartText) {
                let precision = Text.size(decimalPartText);

                // Convert decimal part to integer
                let decimalNat = switch (NatX.fromText(decimalPartText)) {
                    case (null) return null;
                    case (?val) val;
                };
                // Max precision is 3
                let precisionDiff : Int = 3 - precision;
                let value : Nat = if (precisionDiff == 0) {
                    // No change needed
                    decimalNat;
                } else if (precisionDiff > 0) {
                    // Add trailing zeros
                    decimalNat * Int.abs(Int.pow(10, precisionDiff));
                } else {
                    // Remove trailing values
                    decimalNat / Int.abs(Int.pow(10, Int.abs(precisionDiff)));
                };
                ?value;
            };
        };

    };

    // Check if a response already has compression
    private func isAlreadyCompressed(headers : [(Text, Text)]) : Bool {
        for ((key, value) in headers.vals()) {
            if (TextX.equalIgnoreCase(key, "content-encoding") and not TextX.equalIgnoreCase(value, "identity")) {
                return true;
            };
            if (TextX.equalIgnoreCase(key, "ic-certificate")) {
                // If the response is certified, we don't want to compress it or it will invalidate the certificate
                // TODO is this the best place to check for this?
                return true;
            };
        };
        return false;
    };

    // Get the content type from response headers
    private func getContentType(headers : [(Text, Text)]) : ?Text {
        for ((key, value) in headers.vals()) {
            if (TextX.equalIgnoreCase(key, "content-type")) {
                return ?value;
            };
        };
        return null;
    };

    // Check if a content type is compressible
    private func isCompressibleContentType(contentType : ?Text, compressibleTypes : [Text]) : Bool {
        switch (contentType) {
            case (null) return false;
            case (?ct) {
                let ctLower = Text.toLower(ct);
                for (prefix in compressibleTypes.vals()) {
                    if (Text.startsWith(ctLower, #text(Text.toLower(prefix)))) {
                        return true;
                    };
                };
                return false;
            };
        };
    };

    // Remove a header from the headers list
    private func removeHeader(headers : [(Text, Text)], nameToRemove : Text) : [(Text, Text)] {
        Array.filter(
            headers,
            func((key, _) : (Text, Text)) : Bool {
                not TextX.equalIgnoreCase(key, nameToRemove);
            },
        );
    };

    func getHeader(headers : List.List<(Text, Text)>, key : Text) : ?(Text, Nat) {
        var i = 0;
        for (((k, v), i) in List.entries(headers)) {
            if (k == key) return ?(v, i);
        };
        null;
    };
};
