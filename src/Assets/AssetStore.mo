import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Array "mo:base/Array";
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
        addOrUpdateAsset : (Text, Text, Blob, ?Blob) -> ();
        addOrUpdateAssetWithEncoding : (Text, Text, Blob, Asset.Encoding, ?Blob) -> ();
        delete : (Text) -> ();
        deleteEncoding : (Text, Asset.Encoding) -> ();
        toStableData : () -> StableData;
    };

    public class Store(data : StableData) : ReadAndWriteStore {
        let assets = data.assets.vals()
        |> Iter.map<Asset.Asset, (Text, Asset.Asset)>(_, func(asset : Asset.Asset) : (Text, Asset.Asset) = (asset.key, asset))
        |> HashMap.fromIter<Text, Asset.Asset>(_, data.assets.size(), Text.equal, Text.hash);

        public func get(key : Text) : ?Asset.Asset {
            assets.get(key);
        };

        public func addOrUpdateAsset(
            key : Text,
            contentType : Text,
            content : Blob,
            sha256 : ?Blob,
        ) : () {
            addOrUpdateAssetWithEncoding(key, contentType, content, #identity, sha256);
        };

        // Note that it updates the contentType of the asset if it already exists
        public func addOrUpdateAssetWithEncoding(
            key : Text,
            contentType : Text,
            content : Blob,
            encoding : Asset.Encoding,
            sha256 : ?Blob,
        ) : () {
            let sha256NotNull = getOrComputeSha256(content, sha256);
            let updatedAsset : Asset.Asset = switch (assets.get(key)) {
                case (?asset) {
                    let updatedAsset = addOrUpdateEncoding(asset, encoding, content, sha256NotNull);
                    {
                        updatedAsset with
                        contentType = contentType;
                    };
                };
                case (null) ({
                    key;
                    contentType;
                    encodedData = [{
                        encoding = encoding;
                        content;
                        sha256 = sha256NotNull;
                    }];
                });
            };
            assets.put(key, updatedAsset);
        };

        public func delete(key : Text) : () {
            assets.delete(key);
        };

        public func deleteEncoding(key : Text, encoding : Asset.Encoding) {
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

        public func toStableData() : StableData {
            {
                assets = assets.vals() |> Iter.toArray(_);
            };
        };

        private func getOrComputeSha256(content : Blob, sha256 : ?Blob) : Blob = switch (sha256) {
            case (?sha256) sha256;
            case (null) Sha256.fromBlob(#sha256, content);
        };

        private func addOrUpdateEncoding(
            asset : Asset.Asset,
            encoding : Asset.Encoding,
            content : Blob,
            sha256 : Blob,
        ) : Asset.Asset {
            let exstingEncodingIndex = IterTools.findIndex(
                asset.encodedData.vals(),
                func(encodedData : Asset.AssetData) : Bool = encodedData.encoding == encoding,
            );
            let updatedEncodedData : [Asset.AssetData] = switch (exstingEncodingIndex) {
                case (?index) {
                    let mutableEncodedData = Array.thaw<Asset.AssetData>(asset.encodedData);
                    mutableEncodedData[index] := {
                        encoding = encoding;
                        content;
                        sha256 = sha256;
                    };
                    Array.freeze<Asset.AssetData>(mutableEncodedData);
                };
                case (null) Array.append(
                    asset.encodedData,
                    [{ encoding = encoding; content; sha256 = sha256 }],
                );
            };
            {
                asset with
                encodedData = updatedEncodedData;
            };
        };
    };
};
