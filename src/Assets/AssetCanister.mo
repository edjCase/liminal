import AssetStore "./AssetStore";
import Asset "./Asset";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Prelude "mo:base/Prelude";

module {
    public type StoreRequest = {
        key : Text;
        content_type : Text;
        content_encoding : Text;
        content : Blob;
        sha256 : ?Blob;
    };

    public type GetRequest = {
        key : Text;
        accept_encodings : [Text];
    };

    public type GetResponse = {
        content : Blob;
        content_type : Text;
        content_encoding : Text;
        total_length : Nat;
        sha256 : ?Blob;
    };

    public type GetChunkRequest = {
        key : Text;
        content_encoding : Text;
        index : Nat;
        sha256 : ?Blob;
    };

    public type GetChunkResponse = {
        content : Blob;
    };

    public type CreateBatchResponse = {
        batch_id : Nat;
    };

    public type CreateChunkRequest = {
        batch_id : Nat;
        content : Blob;
    };

    public type CreateChunkResponse = {
        chunk_id : Nat;
    };

    public type AuthorizeRequest = {
        caller : Principal;
        other : Principal;
    };

    public type BatchRequest = {
        caller : Principal;
        request : {};
    };

    public type StoreCallContext = {
        caller : Principal;
        request : StoreRequest;
    };

    public type AssetDetails = {
        key : Text;
        content_type : Text;
        encodings : [AssetEncodingDetails];
    };

    public type AssetEncodingDetails = {
        modified : Time.Time;
        content_encoding : Text;
        sha256 : ?Blob;
        length : Nat;
    };
    public type CommitBatchRequest = {
        batch_id : Nat;
        operations : [BatchRequestKind];
    };

    public type BatchRequestKind = {
        #CreateAsset : CreateAssetRequest;
        #SetAssetContent : SetAssetContentRequest;
        #UnsetAssetContent : UnsetAssetContentRequest;
        #DeleteAsset : DeleteAssetRequest;
        #Clear : ClearRequest;
    };

    public type CreateAssetRequest = {
        key : Text;
        content_type : Text;
    };

    public type SetAssetContentRequest = {
        key : Text;
        content_encoding : Text;
        chunk_ids : [Nat];
        sha256 : ?Blob;
    };

    public type UnsetAssetContentRequest = {
        key : Text;
        content_encoding : Text;
    };

    public type DeleteAssetRequest = {
        key : Text;
    };

    public type ClearRequest = {};

    public type CreateBatchRequest = {};

    public type ListRequest = {};

    public type StreamingCallbackRequest = {
        key : Text;
        content_encoding : Text;
        index : Nat;
        sha256 : ?Blob;
    };

    public type StreamingCallbackHttpResponse = {
        body : Blob;
        token : ?StreamingCallbackRequest;
    };

    public type StableData = {
        adminIds : [Principal];
        chunks : [Chunk];
    };

    public type Chunk = {

    };

    public class Handler(
        data : StableData,
        assetStore : AssetStore.Store,
    ) = self {
        let adminIds = Buffer.fromArray<Principal>(data.adminIds);

        public func authorize(newId : Principal, caller : Principal) : () {
            throwIfNotAdmin(caller);
            if (not Buffer.contains(adminIds, newId, Principal.equal)) {
                adminIds.add(newId);
            };
        };

        public func retrieve(key : Text) : Blob {
            let ?asset = assetStore.get(key) else Debug.trap("Asset with key '" # key # "' not found");
            let ?encoding = Asset.getEncoding(asset, #identity) else Debug.trap("Identity encoding not found for asset with key '" # key # "'");
            if (encoding.contentChunks.size() > 1) {
                Debug.trap("Asset too large. Use get() and get_chunk() instead.");
            };
            encoding.contentChunks[0];
        };

        public func store(request : StoreRequest, caller : Principal) : () {
            throwIfNotAdmin(caller);
            let ?encoding = Asset.encodingFromText(request.content_encoding) else Debug.trap("Unsupported encoding: " # request.content_encoding);
            assetStore.addOrUpdateAssetWithEncoding(
                request.key,
                request.content_type,
                [request.content],
                encoding,
                request.sha256,
            );
        };

        public func list(_ : ListRequest) : [AssetDetails] {
            assetStore.getAll()
            |> Iter.map<Asset.Asset, AssetDetails>(
                _,
                func(asset : Asset.Asset) : AssetDetails = {
                    key = asset.key;
                    content_type = asset.contentType;
                    encodings = asset.encodedData.vals()
                    |> Iter.map<Asset.AssetData, AssetEncodingDetails>(
                        _,
                        func(data : Asset.AssetData) : AssetEncodingDetails = {
                            modified = data.modifiedTime;
                            content_encoding = Asset.encodingToText(data.encoding);
                            sha256 = ?data.sha256;
                            length = data.totalContentSize;
                        },
                    )
                    |> Iter.toArray(_);
                },
            )
            |> Iter.toArray(_);
        };

        public func get(request : GetRequest) : GetResponse {
            let ?asset = assetStore.get(request.key) else Debug.trap("Asset with key '" # request.key # "' not found");
            label f for (encodingText in request.accept_encodings.vals()) {
                let ?encoding = Asset.encodingFromText(encodingText) else {
                    Debug.print("Unsupported encoding: " # encodingText # ", skipping");
                    continue f;
                };
                let ?assetData = Asset.getEncoding(asset, encoding) else continue f;
                return {
                    content = assetData.contentChunks[0]; // get the first chunk, then use get_chunk() to get the rest
                    content_type = asset.contentType;
                    content_encoding = encodingText;
                    total_length = assetData.totalContentSize;
                    sha256 = ?assetData.sha256;
                };
            };
            Debug.trap("No supported encoding found for asset with key '" # request.key # "'");
        };

        public func get_chunk(request : GetChunkRequest) : GetChunkResponse {
            // TODO
            Prelude.nyi();
        };

        public func create_batch(request : CreateBatchRequest, caller : Principal) : CreateBatchResponse {
            throwIfNotAdmin(caller);
            // TODO
            Prelude.nyi();
        };

        public func create_chunk(request : CreateChunkRequest, caller : Principal) : CreateChunkResponse {
            throwIfNotAdmin(caller);
            // TODO
            Prelude.nyi();
        };

        public func commit_batch(request : CommitBatchRequest, caller : Principal) : () {
            throwIfNotAdmin(caller);
            // TODO
            Prelude.nyi();
        };

        public func create_asset(request : CreateAssetRequest, caller : Principal) : () {
            throwIfNotAdmin(caller);
            // TODO
            Prelude.nyi();
        };

        public func set_asset_content(request : SetAssetContentRequest, caller : Principal) : () {
            throwIfNotAdmin(caller);
            // TODO
            Prelude.nyi();
        };

        public func unset_asset_content(request : UnsetAssetContentRequest, caller : Principal) : () {
            throwIfNotAdmin(caller);
            // TODO
            Prelude.nyi();
        };

        public func delete_asset(request : DeleteAssetRequest, caller : Principal) : () {
            throwIfNotAdmin(caller);
            assetStore.delete(request.key);
        };

        public func clear(request : ClearRequest, caller : Principal) : () {
            throwIfNotAdmin(caller);
            // TODO
            Prelude.nyi();
        };

        public func http_request_streaming_callback(request : StreamingCallbackRequest) : StreamingCallbackHttpResponse {
            // TODO
            Prelude.nyi();
        };

        public func toStableData() : StableData {
            {
                adminIds = Buffer.toArray(adminIds);
                chunks = [];
            };
        };

        private func throwIfNotAdmin(caller : Principal) : () {
            if (not Buffer.contains(adminIds, caller, Principal.equal)) {
                Debug.trap("Unauthorized");
            };
        };
    };
};
