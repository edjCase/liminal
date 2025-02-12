import Pipeline "Pipeline";
import HttpContext "HttpContext";
import Types "Types";
import Path "Path";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Blob "mo:base/Blob";
import DateTime "mo:datetime/DateTime";

module {
    public type Seconds = Nat;

    public type Options = {
        maxAge : Seconds;
    };

    public type StaticAsset = {
        path : Text;
        bytes : [Nat8];
        contentType : Text; // MIME type
        size : Nat; // File size in bytes
        lastModified : Time.Time;
        etag : Text; // Hash of content for caching
    };

    public type StableData = {
        assets : [StaticAsset];
    };

    public func use(pipeline : Pipeline.PipelineData, path : Text, assets : [StaticAsset], options : Options) : Pipeline.PipelineData {
        let staticAssetHander = StaticAssetHandler({
            assets = assets;
        });
        let rootPath = Path.parse(path);
        let middleware = {
            handle = func(httpContext : HttpContext.HttpContext, next : Pipeline.Next) : Types.HttpResponse {
                let requestPath = httpContext.getPath();
                let ?remainingPath = Path.match(rootPath, requestPath) else return next();
                let ?asset = staticAssetHander.get(remainingPath) else return {
                    statusCode = 404;
                    headers = [];
                    body = null;
                };
                {
                    statusCode = 200;
                    headers = [
                        ("Content-Type", asset.contentType),
                        ("Content-Length", Nat.toText(asset.size)),
                        ("Last-Modified", DateTime.DateTime(asset.lastModified).toText()),
                        ("Cache-Control", "public, max-age=" # Nat.toText(options.maxAge)),
                        ("ETag", asset.etag),
                    ];
                    body = ?Blob.fromArray(asset.bytes);
                };
            };
        };

        {
            middleware = Array.append(pipeline.middleware, [middleware]);
        };
    };

    public class StaticAssetHandler(data : StableData) = self {
        public func get(path : Path.Path) : ?StaticAsset {
            Array.find(
                data.assets,
                func(asset : StaticAsset) : Bool = Path.match(Path.parse(asset.path), path) != null,
            );
        };
    };
};
