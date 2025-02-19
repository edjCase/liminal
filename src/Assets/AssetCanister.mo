import AssetStore "./AssetStore";
import Asset "./Asset";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Prelude "mo:base/Prelude";
import Blob "mo:base/Blob";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Option "mo:base/Option";

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
        batches : [Batch];
    };

    public type Chunk = {
        id : Nat;
        batchId : Nat;
        content : Blob;
    };

    public type Batch = {
        id : Nat;
        proposedCommit : ?ProposedCommit;
        expiresAt : Time.Time;
        evidence : ?Evidence;
        contentSize : Nat;
    };

    public type ProposedCommit = {
        operations : [BatchRequestKind];
    };

    public type Evidence = {
        #computed;
    };

    public type Options = {
        batchExpiry : Time.Time; // 5 minutes in nanoseconds
        maxBatches : ?Nat; // null or 0 for unlimited
    };

    public func defaultOptions() : Options {
        {
            batchExpiry = 300_000_000_000;
            maxBatches = null;
        };
    };

    public class Handler(
        data : StableData,
        assetStore : AssetStore.Store,
        options : Options,
    ) = self {
        let adminIds = Buffer.fromArray<Principal>(data.adminIds);
        let chunks = data.chunks.vals()
        |> Iter.map<Chunk, (Nat, Chunk)>(_, func(chunk : Chunk) : (Nat, Chunk) = (chunk.id, chunk))
        |> HashMap.fromIter<Nat, Chunk>(_, data.chunks.size(), Nat.equal, Nat32.fromNat);
        let batches = data.batches.vals()
        |> Iter.map<Batch, (Nat, Batch)>(_, func(batch : Batch) : (Nat, Batch) = (batch.id, batch))
        |> HashMap.fromIter<Nat, Batch>(_, data.batches.size(), Nat.equal, Nat32.fromNat);

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
            let ?asset = assetStore.get(request.key) else Debug.trap("Asset with key '" # request.key # "' not found");
            let ?encoding = Asset.encodingFromText(request.content_encoding) else Debug.trap("Unsupported encoding: " # request.content_encoding);
            let ?assetData = Asset.getEncoding(asset, encoding) else Debug.trap("Encoding not found for asset");

            // Validate hash if provided
            switch (request.sha256) {
                case (null) {};
                case (?expectedHash) {
                    if (not Blob.equal(expectedHash, assetData.sha256)) {
                        Debug.trap("sha256 mismatch");
                    };
                };
            };

            // Check if chunk index is valid
            if (request.index >= assetData.contentChunks.size()) {
                Debug.trap("chunk index out of bounds");
            };

            { content = assetData.contentChunks[request.index] };
        };

        public func create_batch(_ : CreateBatchRequest, caller : Principal) : CreateBatchResponse {
            throwIfNotAdmin(caller);

            let now = Time.now();

            // Clear expired batches and their chunks
            for ((batchId, batch) in batches.entries()) {
                let expired = batch.expiresAt < now;
                let computed = batch.evidence == ?#computed;
                if (expired and not computed) {
                    batches.delete(batchId);
                    for ((chunkId, chunk) in chunks.entries()) {
                        if (chunk.batchId == batchId) {
                            chunks.delete(chunkId);
                        };
                    };
                };
            };

            // Check if any batch has pending commits
            for ((_, batch) in batches.entries()) {
                if (batch.proposedCommit != null) {
                    let msg = switch (batch.evidence) {
                        case (?_) "Batch is already proposed. Delete or execute it to propose another.";
                        case (null) "Batch has not completed evidence computation. Wait for it to expire or delete it to propose another.";
                    };
                    Debug.trap(msg);
                };
            };

            // Check batch limits if configured
            let maxBatches = Option.get(options.maxBatches, 0);
            if (maxBatches > 0) {
                if (batches.size() >= maxBatches) {
                    Debug.trap("batch limit exceeded");
                };
            };

            // Create new batch
            let batchId = getNextBatchId();

            let newBatch : Batch = {
                id = batchId;
                expiresAt = now + options.batchExpiry;
                evidence = null;
                contentSize = 0;
                proposedCommit = null;
            };

            let null = batches.replace(batchId, newBatch) else Debug.trap("Internal Error: Batch with id '" # Nat.toText(batchId) # "' already exists");

            return { batch_id = batchId };
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
                chunks = chunks.vals() |> Iter.toArray(_);
                batches = batches.vals() |> Iter.toArray(_);
            };
        };

        private func throwIfNotAdmin(caller : Principal) : () {
            if (not Buffer.contains(adminIds, caller, Principal.equal)) {
                Debug.trap("Unauthorized");
            };
        };

        // Iterate up starting at 1 and return the first unused id
        private func getNextBatchId() : Nat {
            var nextId = 1;
            while (batches.get(nextId) != null) {
                nextId += 1;
            };
            nextId;
        };
    };
};
