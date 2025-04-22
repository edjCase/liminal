import HttpContext "../HttpContext";
import Types "../Types";
import Nat "mo:new-base/Nat";
import Blob "mo:new-base/Blob";
import Text "mo:new-base/Text";
import Nat16 "mo:new-base/Nat16";
import Debug "mo:new-base/Debug";
import HttpAssets "mo:http-assets";
import Path "../Path";

module {
    public type Seconds = Nat;

    public type Config = {
        prefix : ?Text;
        cache : CacheOptions;
        store : HttpAssets.Assets;
        indexAssetPath : ?Text;
    };

    public type StreamingStrategy = {
        #none;
        #callback : shared query (Blob) -> async Types.StreamingCallbackResponse;
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

    public func serve(
        httpContext : HttpContext.HttpContext,
        options : Config,
    ) : {
        #response : Types.HttpResponse;
        #stream : Types.StreamingStrategy;
        #noMatch;
    } {

        let requestPath = httpContext.getPath();
        Debug.print("Request path: " # debug_show requestPath);

        let ?remainingPath = switch (options.prefix) {
            case (?prefix) Path.match(Path.parse(prefix), requestPath);
            case (null) ?requestPath;
        } else return #noMatch;

        Debug.print("Remaining path: " # debug_show remainingPath);

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
        Debug.print("Asset path: " # debug_show assetPath);
        let request = {
            httpContext.request with url = assetPath;
            certificate_version = httpContext.certificateVersion;
        };
        switch (options.store.http_request(request)) {
            case (#err(e)) {
                Debug.print("Error: " # debug_show e);
                return #noMatch;
            }; // TODO handle error
            case (#ok(response)) {
                switch (response.streaming_strategy) {
                    case (null) ();
                    case (?streamingStrategy) switch (streamingStrategy) {
                        case (#Callback(callback)) {
                            return #stream(#callback(callback));
                        };
                    };
                };
                Debug.print("Response: " # debug_show response.status_code);
                #response({
                    statusCode = Nat16.toNat(response.status_code);
                    headers = response.headers;
                    body = ?response.body;
                });
            };
        };
    };
};
