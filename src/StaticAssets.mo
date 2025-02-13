import Pipeline "Pipeline";
import HttpContext "HttpContext";
import Types "Types";
import Path "Path";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Glob "mo:glob";

module {
    public type Seconds = Nat;

    public type Options = {
        cache : CacheOptions;
        assetHandler : (Path.Path) -> ?StaticAsset;
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

    public type StaticAsset = {
        path : Text;
        bytes : Blob;
        contentType : Text; // MIME type
        size : Nat; // File size in bytes
        etag : Text; // Hash of content for caching
    };

    // Helper to check if a resource has been modified
    private func isResourceModified(httpContext : HttpContext.HttpContext, asset : StaticAsset) : Bool {
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

        let middleware = {
            handle = func(httpContext : HttpContext.HttpContext, next : Pipeline.Next) : Types.HttpResponse {
                let requestPath = httpContext.getPath();

                let ?remainingPath = Path.match(rootPath, requestPath) else return next();

                let ?asset = options.assetHandler(remainingPath) else return {
                    statusCode = 404;
                    headers = [];
                    body = null;
                };

                let remainingPathText = Path.toText(remainingPath);
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
                if (not isResourceModified(httpContext, asset)) {
                    return {
                        statusCode = 304; // Not Modified
                        headers = [
                            ("ETag", asset.etag),
                            ("Cache-Control", formatCacheControl(cacheControl)),
                        ];
                        body = null;
                    };
                };

                // Handle Range header if present
                switch (httpContext.getHeader("Range")) {
                    // TODO: Implement range requests
                    case (?_) return {
                        statusCode = 501;
                        headers = [
                            ("Accept-Ranges", "none"),
                        ];
                        body = ?Text.encodeUtf8("Range requests are not yet implemented");
                    };
                    case null {};
                };

                {
                    statusCode = 200;
                    headers = [
                        ("Content-Type", asset.contentType),
                        ("Content-Length", Nat.toText(asset.size)),
                        ("Cache-Control", formatCacheControl(cacheControl)),
                        ("ETag", asset.etag),
                    ];
                    body = ?asset.bytes;
                };
            };
        };

        {
            middleware = Array.append(pipeline.middleware, [middleware]);
        };
    };
};
