import HttpContext "../HttpContext";
import Types "../Types";
import Array "mo:new-base/Array";
import Nat "mo:new-base/Nat";
import Blob "mo:new-base/Blob";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Result "mo:new-base/Result";
import List "mo:new-base/List";
import Debug "mo:new-base/Debug";
import Int "mo:new-base/Int";
import Order "mo:new-base/Order";
import Nat8 "mo:new-base/Nat8";
import Runtime "mo:new-base/Runtime";
import Nat16 "mo:new-base/Nat16";
import Glob "mo:glob";
import NatX "mo:xtended-numbers/NatX";
import Asset "Asset";
import Assets "mo:ic-assets";
import Path "../Path";
import HttpMethod "../HttpMethod";

module {
    public type Seconds = Nat;

    public type Config = {
        prefix : ?Text;
        cache : CacheOptions;
        store : Assets.Assets;
        indexAssetPath : ?Text;
    };

    public type StreamingStrategy = {
        #none;
        #callback : shared query (Blob) -> async ?Types.StreamingCallbackResponse;
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

    type StreamingToken = {

    };

    public func streamingCallbackHandler(token : Blob, options : Config) : ?Types.StreamingCallbackResponse {
        let ?streamingToken : ?Assets.StreamingToken = from_candid (token) else return null;
        let response : Assets.StreamingCallbackResponse = options.store.http_request_streaming_callback(streamingToken);
        ?{
            body = response.body;
            token = switch (response.token) {
                case (?token) ?to_candid (token);
                case (null) null;
            };
        };
    };

    public func serve(
        httpContext : HttpContext.HttpContext,
        options : Config,
    ) : {
        #response : Types.HttpResponse;
        #stream : Types.StreamingStrategy;
        #noMatch;
    } {

        let requestPath = httpContext.getPath();

        let ?remainingPath = switch (options.prefix) {
            case (?prefix) Path.match(Path.parse(prefix), requestPath);
            case (null) ?requestPath;
        } else return #noMatch;

        var assetPath = Path.toText(remainingPath);
        switch (options.indexAssetPath) {
            case (?indexAssetPath) {
                if (remainingPath.size() == 0) {
                    // Override asset path with index asset
                    assetPath := indexAssetPath;
                };
            };
            case (null) {};
        };
        let request = {
            httpContext.request with url = assetPath;
            certificate_version = httpContext.certificateVersion;
        };
        switch (options.store.http_request(request)) {
            case (#err(e)) return #noMatch; // TODO handle error
            case (#ok(response)) {
                switch (response.streaming_strategy) {
                    case (null) ();
                    case (?streamingStrategy) switch (streamingStrategy) {
                        case (#Callback(callback)) {
                            return #stream(#callback({ callback = callback.callback; token = to_candid (response.streaming_strategy) }));
                        };
                    };
                };
                #response({
                    statusCode = Nat16.toNat(response.status_code);
                    headers = response.headers;
                    body = ?response.body;
                });
            };
        };
    };

    private type HttpAsset = {
        path : Text;
        bytes : Blob;
        contentType : Text; // MIME type
        contentEncoding : Text; // Encoding type
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

    private func parseEncodingTypes(header : ?Text) : Result.Result<[Asset.EncodingWithWeight], Text> {
        let ?headerText = header else return #ok([]);
        // Split by comma and trim each entry
        let entries = headerText
        |> Text.split(_, #char(','))
        |> Iter.toArray(_);

        let encodings = List.empty<Asset.EncodingWithWeight>();
        label f for (entry in entries.vals()) {
            // Remove quality parameter if present
            let parts = Text.split(entry, #char(';'));
            let ?encodingText = parts.next() else Runtime.trap("Invalid Accept-Encoding header: " # headerText);
            let ?encoding = Asset.encodingFromText(encodingText) else {
                Debug.print("Unknown http content encoding: " # encodingText # " in header: " # headerText # ", skipping");
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
                    } else return #err("Invalid quality parameter in Accept-Encoding header: " # headerText);
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
        b.vals()
        |> Iter.map<Nat8, Text>(
            _,
            byteToHex,
        )
        |> Text.join("", _);
    };

};
