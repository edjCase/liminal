import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Sha256 "mo:sha2/Sha256";
import IterTools "mo:itertools/Iter";
import Asset "./Asset";

module {

    public type StableData = {
        assets : [Asset.Asset];
    };

    public type ReadOnlyStore = {
        get : (Text) -> ?Asset.Asset;
    };

    public type ReadAndWriteStore = ReadOnlyStore and {
        addOrUpdateAsset : (key : Text, contentType : Text) -> ();
        addOrUpdateEncodingData : (key : Text, contentChunks : [Blob], encoding : Asset.Encoding, sha256 : ?Blob) -> ();
        deleteAsset : (key : Text) -> ();
        deleteEncodingData : (key : Text, encoding : Asset.Encoding) -> ();
        toStableData : () -> StableData;
    };

    public class Store(data : StableData) : ReadAndWriteStore {
        var assets = data.assets.vals()
        |> Iter.map<Asset.Asset, (Text, Asset.Asset)>(_, func(asset : Asset.Asset) : (Text, Asset.Asset) = (asset.key, asset))
        |> HashMap.fromIter<Text, Asset.Asset>(_, data.assets.size(), Text.equal, Text.hash);

        public func get(key : Text) : ?Asset.Asset {
            assets.get(key);
        };

        public func getAll() : Iter.Iter<Asset.Asset> {
            assets.vals();
        };

        public func addOrUpdateAsset(
            key : Text,
            contentType : Text,
        ) : () {
            assets.put(
                key,
                {
                    key;
                    contentType;
                    encodedData = [];
                },
            );
        };

        public func addOrUpdateEncodingData(
            key : Text,
            contentChunks : [Blob],
            encoding : Asset.Encoding,
            sha256 : ?Blob,
        ) : () {
            if (contentChunks.size() == 0) {
                return Debug.trap("Content chunks must not be empty");
            };
            let sha256NotNull = getOrComputeSha256(contentChunks, sha256);
            let ?asset = assets.get(key) else Debug.trap("Asset with id '" # key # "' not found");
            let updatedAsset : Asset.Asset = addOrUpdateEncoding(asset, encoding, contentChunks, sha256NotNull);
            assets.put(key, updatedAsset);
        };

        private func buildAssetData(
            encoding : Asset.Encoding,
            contentChunks : [Blob],
            sha256 : Blob,
        ) : Asset.AssetData {
            let ?totalContentSize = contentChunks.vals()
            |> Iter.map(_, func(chunk : Blob) : Nat = chunk.size())
            |> IterTools.sum(_, Nat.add) else Debug.trap("Content chunks must not be empty");
            {
                modifiedTime = Time.now();
                encoding = encoding;
                contentChunks;
                totalContentSize;
                sha256;
            };
        };

        public func deleteAsset(key : Text) : () {
            assets.delete(key);
        };

        public func deleteEncodingData(key : Text, encoding : Asset.Encoding) {
            let ?asset = assets.get(key) else return;

            let updatedEncodedData = asset.encodedData.vals()
            |> Iter.filter<Asset.AssetData>(_, func(encodedData : Asset.AssetData) : Bool = encodedData.encoding != encoding)
            |> Iter.toArray(_);
            assets.put(
                key,
                {
                    asset with
                    encodedData = updatedEncodedData;
                },
            );
        };

        public func deleteAllAssets() : () {
            assets := HashMap.HashMap<Text, Asset.Asset>(0, Text.equal, Text.hash);
        };

        public func toStableData() : StableData {
            {
                assets = assets.vals() |> Iter.toArray(_);
            };
        };

        private func getOrComputeSha256(contentChunks : [Blob], sha256 : ?Blob) : Blob = switch (sha256) {
            case (?sha256) sha256;
            case (null) {
                let hasher = Sha256.Digest(#sha256);
                for (contentChunk in contentChunks.vals()) {
                    hasher.writeBlob(contentChunk);
                };
                hasher.sum();
            };
        };

        private func addOrUpdateEncoding(
            asset : Asset.Asset,
            encoding : Asset.Encoding,
            contentChunks : [Blob],
            sha256 : Blob,
        ) : Asset.Asset {
            let exstingEncodingIndex = IterTools.findIndex(
                asset.encodedData.vals(),
                func(encodedData : Asset.AssetData) : Bool = encodedData.encoding == encoding,
            );
            let updatedEncodedData : [Asset.AssetData] = switch (exstingEncodingIndex) {
                case (?index) {
                    let mutableEncodedData = Array.thaw<Asset.AssetData>(asset.encodedData);
                    mutableEncodedData[index] := buildAssetData(encoding, contentChunks, sha256);
                    Array.freeze<Asset.AssetData>(mutableEncodedData);
                };
                case (null) Array.append(
                    asset.encodedData,
                    [buildAssetData(encoding, contentChunks, sha256)],
                );
            };
            {
                asset with
                encodedData = updatedEncodedData;
            };
        };
    };
};
