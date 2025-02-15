import Path "../../src/Path";
import HttpStaticAssets "../../src/StaticAssets";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Nat32 "mo:base/Nat32";

module {

    public type StableData = {
        assets : [HttpStaticAssets.StaticAsset];
    };

    public class Handler(stableData : StableData) = self {
        var assets = stableData.assets;
        public func get(path : Path.Path) : ?HttpStaticAssets.StaticAsset {
            let pathText = Path.toText(path);
            if (pathText == "/index.html") {
                let bytes = Text.encodeUtf8("<html><body><h1>Hello, World!</h1></body></html>");
                let etag = bytes
                |> Blob.hash(_)
                |> Nat32.toText(_);
                return ?{
                    path = pathText;
                    bytes = bytes;
                    contentType = "text/html";
                    size = bytes.size();
                    etag = etag;
                };
            };
            return null;
        };

        public func toStableData() : StableData {
            { assets = assets };
        };
    };
};
