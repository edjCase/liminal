import Pipeline "../Pipeline";
import HttpContext "../HttpContext";
import Types "../Types";
import Path "../Path";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Order "mo:base/Order";
import Nat8 "mo:base/Nat8";
import Glob "mo:glob";
import NatX "mo:xtended-numbers/NatX";
import Asset "Asset";
import AssetStore "AssetStore";

module {
    public type Seconds = Nat;

    public type Options = {
        cache : CacheOptions;
        store : AssetStore.ReadOnlyStore;
    };

    public type CacheOptions = {
        default : CacheControl;
        rules : [CacheRule];
    };

    type CacheRule = {
        pattern : Text;
        cache : CacheControl;
    };

    public type CacheControl = {
        #noStore; // Never cache
        #noCache; // Must revalidate every time
        #public_ : {
            maxAge : Seconds;
            immutable : Bool;
        };
        #private_ : {
            maxAge : Seconds;
            mustRevalidate : Bool;
        };
        #revalidate : {
            maxAge : Seconds;
            staleWhileRevalidate : Seconds;
        };
    };

    private type HttpAsset = {
        path : Text;
        bytes : Blob;
        contentType : Text; // MIME type
        size : Nat; // File size in bytes
        etag : Text; // Hash of content for caching
    };

    // Helper to check if a resource has been modified
    private func isResourceModified(httpContext : HttpContext.HttpContext, asset : HttpAsset) : Bool {
        // Check If-None-Match header
        switch (httpContext.getHeader("If-None-Match")) {
            case (?clientEtag) {
                if (clientEtag == asset.etag) {
                    return false; // Not modified
                };
            };
            case null {};
        };

        // TODO ? If-Modified-Since header, seems outdated and replaced by ETag

        true // Modified or no conditional headers
    };
    private func formatCacheControl(cc : CacheControl) : Text {
        switch (cc) {
            case (#noStore) "no-store";
            case (#noCache) "no-cache";
            case (#public_({ maxAge; immutable })) {
                let base = "public, max-age=" # Nat.toText(maxAge);
                if (immutable) {
                    base # ", immutable";
                } else {
                    base;
                };
            };
            case (#private_({ maxAge; mustRevalidate })) {
                let base = "private, max-age=" # Nat.toText(maxAge);
                if (mustRevalidate) {
                    base # ", must-revalidate";
                } else {
                    base;
                };
            };
            case (#revalidate({ maxAge; staleWhileRevalidate })) {
                "max-age=" # Nat.toText(maxAge) #
                ", stale-while-revalidate=" # Nat.toText(staleWhileRevalidate);
            };
        };
    };

    public func use(pipeline : Pipeline.PipelineData, path : Text, options : Options) : Pipeline.PipelineData {
        let rootPath = Path.parse(path);

        let middleware : Pipeline.Middleware = {
            handleQuery = ?(
                func(httpContext : HttpContext.HttpContext, next : Pipeline.Next) : ?Types.HttpResponse {
                    next(); // TODO
                }
            );
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : Pipeline.NextAsync) : async* ?Types.HttpResponse {
                let requestPath = httpContext.getPath();

                let ?remainingPath = Path.match(rootPath, requestPath) else return await* next();

                let encodingTypes = switch (parseEncodingTypes(httpContext.getHeader("Accept-Encoding"))) {
                    case (#ok(encodings)) encodings;
                    case (#err(err)) {
                        Debug.print("Error parsing Accept-Encoding header: " # err);
                        return ?{
                            statusCode = 406; // Not Acceptable
                            headers = [];
                            body = null;
                        };
                    };
                };
                let remainingPathText = Path.toText(remainingPath);

                let ?asset = options.store.get(remainingPathText) else return null;

                var excludeIdentity = false;
                var assetDataOrNull : ?Asset.AssetData = null;
                // Already ordered by quality
                label f for (encoding in encodingTypes.vals()) {
                    // Weight 0 means exclude
                    if (encoding.weight == 0) {
                        if (encoding.encoding == #identity) {
                            excludeIdentity := true; // Only exclude identity if it is set to 0
                        };
                        continue f;
                    };
                    assetDataOrNull := Array.find(asset.encodedData, func(data : Asset.AssetData) : Bool = data.encoding == encoding.encoding);
                    if (assetDataOrNull != null) {
                        break f;
                    };
                };

                let assetData = switch (assetDataOrNull) {
                    case (null) return ?{
                        statusCode = 406; // Not Acceptable
                        headers = [];
                        body = null; // TODO error message?
                    };
                    case (?assetData) assetData;
                };

                let httpAsset : HttpAsset = {
                    path = remainingPathText;
                    bytes = assetData.content;
                    contentType = asset.contentType;
                    size = assetData.content.size();
                    etag = blobToHex(assetData.sha256);
                };

                // Get cache control for this asset
                let cacheRule = Array.find(
                    options.cache.rules,
                    // TODO optimize/cache
                    func(rule : CacheRule) : Bool = Glob.match(remainingPathText, rule.pattern),
                );
                let cacheControl = switch (cacheRule) {
                    case (?rule) rule.cache;
                    case (null) options.cache.default;
                };

                // Check if resource has been modified
                if (not isResourceModified(httpContext, httpAsset)) {
                    return ?{
                        statusCode = 304; // Not Modified
                        headers = [
                            ("ETag", httpAsset.etag),
                            ("Cache-Control", formatCacheControl(cacheControl)),
                        ];
                        body = null;
                    };
                };

                // Handle Range header if present
                switch (httpContext.getHeader("Range")) {
                    // TODO: Implement range requests
                    case (?_) return ?{
                        statusCode = 501;
                        headers = [
                            ("Accept-Ranges", "none"),
                        ];
                        body = ?Text.encodeUtf8("Range requests are not yet implemented");
                    };
                    case null {};
                };

                ?{
                    statusCode = 200;
                    headers = [
                        ("Content-Type", httpAsset.contentType),
                        ("Content-Length", Nat.toText(httpAsset.size)),
                        ("Cache-Control", formatCacheControl(cacheControl)),
                        ("ETag", httpAsset.etag),
                    ];
                    body = ?httpAsset.bytes;
                };
            };
        };

        {
            middleware = Array.append(pipeline.middleware, [middleware]);
        };
    };

    private func parseEncodingTypes(header : ?Text) : Result.Result<[Asset.EncodingWithWeight], Text> {
        let ?headerText = header else return #ok([]);
        // Split by comma and trim each entry
        let entries = headerText
        |> Text.split(_, #char(','))
        |> Iter.toArray(_);

        let encodings = Buffer.Buffer<Asset.EncodingWithWeight>(entries.size());
        label f for (entry in entries.vals()) {
            // Remove quality parameter if present
            let parts = Text.split(entry, #char(';'));
            let ?encoding = parts.next() else Debug.trap("Invalid Accept-Encoding header: " # headerText);
            let normalizedEncoding = encoding
            |> Text.trim(_, #char(' '))
            |> Text.toLowercase(_);
            let encodingVariant = switch (normalizedEncoding) {
                case ("identity") #identity;
                case ("gzip") #gzip;
                case ("deflate") #deflate;
                case ("br") #br;
                case ("compress") #compress;
                case ("zstd") #zstd;
                case ("*") #wildcard;
                case (_) {
                    Debug.print("Unknown http content encoding: " # encoding # " in header: " # headerText # ", skipping");
                    continue f;
                };
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
                    } else return #err("Invalid quality parameter in Accept-Encoding header: " # headerText);
                    q;
                };
            };
            encodings.add({
                encoding = encodingVariant;
                weight;
            });
        };
        let orderedEncodings = encodings.vals()
        |> Iter.sort<Asset.EncodingWithWeight>(
            _,
            func(a : Asset.EncodingWithWeight, b : Asset.EncodingWithWeight) : Order.Order = Nat.compare(a.weight, b.weight),
        )
        |> Iter.toArray(_);

        #ok(orderedEncodings);
    };

    // Parse a quality value from a text string
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

    private let hexChars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"];

    // Convert a single byte to a two-character hex string
    private func byteToHex(byte : Nat8) : Text {
        let high = byte >> 4;
        let low = byte & 15;
        hexChars[Nat8.toNat(high)] # hexChars[Nat8.toNat(low)];
    };

    // Convert a Blob to a hex string
    public func blobToHex(b : Blob) : Text {
        let bytes = Blob.toArray(b);
        var buffer = Buffer.Buffer<Text>(bytes.size() * 2);

        for (byte in bytes.vals()) {
            buffer.add(byteToHex(byte));
        };

        Text.join("", buffer.vals());
    };

};
