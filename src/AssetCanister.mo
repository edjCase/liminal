import HttpAssets "mo:http-assets";
import Result "mo:new-base/Result";
import Runtime "mo:new-base/Runtime";

module {

    /// Asset canister wrapper class that provides a simplified interface for managing static assets.
    /// Wraps the http-assets library with error handling and provides both sync and async methods.
    /// All methods trap on error for simplified error handling - use the underlying assets directly for Result-based APIs.
    ///
    /// ```motoko
    /// import HttpAssets "mo:http-assets";
    /// import AssetCanister "mo:liminal/AssetCanister";
    ///
    /// // Initialize the underlying assets store
    /// let assets = HttpAssets.Assets(/* config */);
    ///
    /// // Create the wrapper
    /// let assetCanister = AssetCanister.AssetCanister(assets);
    ///
    /// // Retrieve assets
    /// let asset = assetCanister.get({
    ///     key = "/index.html";
    ///     accept_encodings = ["gzip", "identity"];
    /// });
    ///
    /// // Store new assets
    /// assetCanister.store(callerPrincipal, {
    ///     key = "/new-file.txt";
    ///     content_type = "text/plain";
    ///     content_encoding = "identity";
    ///     content = fileBlob;
    ///     sha256 = null;
    /// });
    /// ```
    public class AssetCanister(assets : HttpAssets.Assets) = self {

        /// Returns the API version of the asset canister.
        /// Used for compatibility checking with asset management tools.
        ///
        /// ```motoko
        /// let assetCanister = AssetCanister.AssetCanister(assets);
        /// let version = assetCanister.api_version();
        /// ```
        public func api_version() : Nat16 {
            assets.api_version();
        };

        /// Retrieves an asset by key, trapping on error.
        /// Returns the complete encoded asset including content and metadata.
        ///
        /// ```motoko
        /// let asset = assetCanister.get({
        ///     key = "/index.html";
        ///     accept_encodings = ["gzip", "identity"];
        /// });
        /// ```
        public func get(args : HttpAssets.GetArgs) : HttpAssets.EncodedAsset {
            switch (assets.get(args)) {
                case (#ok(asset)) asset;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Retrieves a chunk of an asset for streaming large files.
        /// Used in conjunction with streaming strategies for large asset delivery.
        ///
        /// ```motoko
        /// let chunk = assetCanister.get_chunk({
        ///     key = "/large-video.mp4";
        ///     content_encoding = "identity";
        ///     index = 0;
        ///     sha256 = ?assetSha256;
        /// });
        /// ```
        public func get_chunk(args : HttpAssets.GetChunkArgs) : (HttpAssets.ChunkContent) {
            switch (assets.get_chunk(args)) {
                case (#ok(chunk)) chunk;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Grants permission to a principal for asset management operations.
        /// Allows delegation of asset management capabilities to other principals.
        ///
        /// ```motoko
        /// await* assetCanister.grant_permission(managerPrincipal, {
        ///     to_principal = managerPrincipal;
        ///     permission = #Commit;
        /// });
        /// ```
        public func grant_permission(caller : Principal, args : HttpAssets.GrantPermission) : async* () {
            switch (await* assets.grant_permission(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Revokes permission from a principal for asset management operations.
        /// Removes previously granted asset management capabilities.
        ///
        /// ```motoko
        /// await* assetCanister.revoke_permission(ownerPrincipal, {
        ///     of_principal = managerPrincipal;
        ///     permission = #Commit;
        /// });
        /// ```
        public func revoke_permission(caller : Principal, args : HttpAssets.RevokePermission) : async* () {
            switch (await* assets.revoke_permission(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Lists all assets stored in the canister.
        /// Returns metadata for all stored assets including keys and content types.
        ///
        /// ```motoko
        /// let allAssets = assetCanister.list({});
        /// for (asset in allAssets.vals()) {
        ///     let key = asset.key;
        ///     let contentType = asset.content_type;
        ///     // Process asset metadata
        /// };
        /// ```
        public func list(args : {}) : [HttpAssets.AssetDetails] {
            assets.list(args);
        };

        /// Stores an asset in the canister, trapping on error.
        /// Used for uploading new assets or updating existing ones.
        ///
        /// ```motoko
        /// assetCanister.store(uploaderPrincipal, {
        ///     key = "/new-image.png";
        ///     content_type = "image/png";
        ///     content_encoding = "identity";
        ///     content = imageBlob;
        ///     sha256 = ?imageSha256;
        /// });
        /// ```
        public func store(caller : Principal, args : HttpAssets.StoreArgs) : () {
            switch (assets.store(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Creates a new asset in the canister with the specified properties.
        /// The caller must be authorized to create assets.
        ///
        /// ```motoko
        /// assetCanister.create_asset(callerPrincipal, {
        ///     key = "/new-asset.txt";
        ///     content_type = "text/plain";
        ///     headers = ?[("Cache-Control", "public, max-age=3600")];
        /// });
        /// ```
        public func create_asset(caller : Principal, args : HttpAssets.CreateAssetArguments) : () {
            switch (assets.create_asset(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Sets or updates the content of an existing asset.
        /// The asset must already exist, and the caller must be authorized.
        ///
        /// ```motoko
        /// await assetCanister.set_asset_content(callerPrincipal, {
        ///     key = "/existing-asset.txt";
        ///     content_encoding = "gzip";
        ///     content = newContentBlob;
        /// });
        /// ```
        public func set_asset_content(caller : Principal, args : HttpAssets.SetAssetContentArguments) : async* () {
            switch (await* assets.set_asset_content(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Removes the content of an asset, effectively deleting the asset's data.
        /// The asset metadata remains, allowing for potential future content restoration.
        ///
        /// ```motoko
        /// assetCanister.unset_asset_content(callerPrincipal, {
        ///     key = "/existing-asset.txt";
        /// });
        /// ```
        public func unset_asset_content(caller : Principal, args : HttpAssets.UnsetAssetContentArguments) : () {
            switch (assets.unset_asset_content(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Deletes an asset from the canister, removing both content and metadata.
        /// The caller must be authorized to delete the asset.
        ///
        /// ```motoko
        /// assetCanister.delete_asset(callerPrincipal, {
        ///     key = "/obsolete-asset.txt";
        /// });
        /// ```
        public func delete_asset(caller : Principal, args : HttpAssets.DeleteAssetArguments) : () {
            switch (assets.delete_asset(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Sets or updates the properties of an asset, such as metadata.
        /// The caller must be authorized to change the asset's properties.
        ///
        /// ```motoko
        /// assetCanister.set_asset_properties(callerPrincipal, {
        ///     key = "/existing-asset.txt";
        ///     metadata = newMetadata;
        /// });
        /// ```
        public func set_asset_properties(caller : Principal, args : HttpAssets.SetAssetPropertiesArguments) : () {
            switch (assets.set_asset_properties(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Clears all assets and metadata from the canister.
        /// This operation is irreversible and will delete all asset data.
        ///
        /// ```motoko
        /// assetCanister.clear(callerPrincipal, {});
        /// ```
        public func clear(caller : Principal, args : HttpAssets.ClearArguments) : () {
            switch (assets.clear(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Creates a batch of assets from a list of asset arguments.
        /// Returns a response with details about the created assets.
        ///
        /// ```motoko
        /// let response = assetCanister.create_batch(callerPrincipal, {
        ///     assets = [
        ///         { key = "/batch-asset1.txt"; content_type = "text/plain"; },
        ///         { key = "/batch-asset2.png"; content_type = "image/png"; }
        ///     ];
        /// });
        /// ```
        public func create_batch(caller : Principal, args : {}) : (HttpAssets.CreateBatchResponse) {
            switch (assets.create_batch(caller, args)) {
                case (#ok(response)) response;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Creates a chunk for an asset, used for large asset uploads.
        /// Returns the index of the created chunk.
        ///
        /// ```motoko
        /// let response = assetCanister.create_chunk(callerPrincipal, {
        ///     key = "/large-asset.zip";
        ///     index = 0;
        ///     content_encoding = "identity";
        ///     content = chunkBlob;
        /// });
        /// ```
        public func create_chunk(caller : Principal, args : HttpAssets.CreateChunkArguments) : (HttpAssets.CreateChunkResponse) {
            switch (assets.create_chunk(caller, args)) {
                case (#ok(response)) response;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Creates multiple chunks for an asset in a single call.
        /// Useful for optimizing the upload of large assets.
        ///
        /// ```motoko
        /// await assetCanister.create_chunks(callerPrincipal, {
        ///     key = "/large-asset.zip";
        ///     chunks = [
        ///         { index = 0; content = chunkBlob1; },
        ///         { index = 1; content = chunkBlob2; }
        ///     ];
        /// });
        /// ```
        public func create_chunks(caller : Principal, args : HttpAssets.CreateChunksArguments) : async* HttpAssets.CreateChunksResponse {
            switch (await* assets.create_chunks(caller, args)) {
                case (#ok(response)) response;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Commits a batch of asset changes, making them permanent.
        /// The caller must be authorized to commit the batch.
        ///
        /// ```motoko
        /// await assetCanister.commit_batch(callerPrincipal, {
        ///     batch_id = "batch-123";
        /// });
        /// ```
        public func commit_batch(caller : Principal, args : HttpAssets.CommitBatchArguments) : async* () {
            switch (await* assets.commit_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Proposes a batch of asset changes for review.
        /// The proposed batch can be committed by an authorized principal.
        ///
        /// ```motoko
        /// assetCanister.propose_commit_batch(callerPrincipal, {
        ///     batch_id = "batch-123";
        ///     changes = [...];
        /// });
        /// ```
        public func propose_commit_batch(caller : Principal, args : HttpAssets.CommitBatchArguments) : () {
            switch (assets.propose_commit_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Commits a previously proposed batch of asset changes.
        /// Finalizes the changes in the batch, making them permanent.
        ///
        /// ```motoko
        /// await assetCanister.commit_proposed_batch(callerPrincipal, {
        ///     batch_id = "batch-123";
        /// });
        /// ```
        public func commit_proposed_batch(caller : Principal, args : HttpAssets.CommitProposedBatchArguments) : async* () {
            switch (await* assets.commit_proposed_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Computes evidence for an asset, such as a cryptographic proof of existence.
        /// Used for verifying asset integrity and authenticity.
        ///
        /// ```motoko
        /// let evidence = await assetCanister.compute_evidence(callerPrincipal, {
        ///     key = "/important-document.pdf";
        /// });
        /// ```
        public func compute_evidence(caller : Principal, args : HttpAssets.ComputeEvidenceArguments) : async* (?Blob) {
            switch (await* assets.compute_evidence(caller, args)) {
                case (#ok(evidence)) evidence;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Deletes a batch of assets identified by their batch ID.
        /// The caller must be authorized to delete the batch.
        ///
        /// ```motoko
        /// assetCanister.delete_batch(callerPrincipal, {
        ///     batch_id = "batch-123";
        /// });
        /// ```
        public func delete_batch(caller : Principal, args : HttpAssets.DeleteBatchArguments) : () {
            switch (assets.delete_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Lists all principals that have been granted permission for asset management.
        /// Returns a list of principals with their associated permissions.
        ///
        /// ```motoko
        /// let permissions = assetCanister.list_permitted({
        ///     key = "/some-asset.txt";
        /// });
        /// ```
        public func list_permitted(args : HttpAssets.ListPermitted) : ([Principal]) {
            assets.list_permitted(args);
        };

        /// Transfers ownership of the canister's assets to a new principal.
        /// The new owner will have full control over the assets.
        ///
        /// ```motoko
        /// await assetCanister.take_ownership(newOwnerPrincipal);
        /// ```
        public func take_ownership(caller : Principal) : async* () {
            switch (await* assets.take_ownership(caller)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Retrieves the configuration of the asset canister.
        /// Returns details about the canister's settings and parameters.
        ///
        /// ```motoko
        /// let config = assetCanister.get_configuration(callerPrincipal);
        /// ```
        public func get_configuration(caller : Principal) : (HttpAssets.ConfigurationResponse) {
            switch (assets.get_configuration(caller)) {
                case (#ok(config)) config;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Configures the asset canister's settings.
        /// Only callable by authorized principals.
        ///
        /// ```motoko
        /// assetCanister.configure(callerPrincipal, {
        ///     max_asset_size = 2_000_000;
        ///     allowed_content_types = ["image/png", "text/html"];
        /// });
        /// ```
        public func configure(caller : Principal, args : HttpAssets.ConfigureArguments) : () {
            switch (assets.configure(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Retrieves the certified tree of the asset canister.
        /// Used for verifying the integrity of the canister's state.
        ///
        /// ```motoko
        /// let tree = assetCanister.certified_tree({});
        /// ```
        public func certified_tree({}) : (HttpAssets.CertifiedTree) {
            switch (assets.certified_tree()) {
                case (#ok(tree)) tree;
                case (#err(err)) Runtime.trap(err);
            };
        };

        /// Validates the arguments for granting permission to a principal.
        /// Returns an error if the validation fails.
        ///
        /// ```motoko
        /// let result = assetCanister.validate_grant_permission({
        ///     to_principal = managerPrincipal;
        ///     permission = #Commit;
        /// });
        /// ```
        public func validate_grant_permission(args : HttpAssets.GrantPermission) : (Result.Result<Text, Text>) {
            assets.validate_grant_permission(args);
        };

        /// Validates the arguments for revoking permission from a principal.
        /// Returns an error if the validation fails.
        ///
        /// ```motoko
        /// let result = assetCanister.validate_revoke_permission({
        ///     of_principal = managerPrincipal;
        ///     permission = #Commit;
        /// });
        /// ```
        public func validate_revoke_permission(args : HttpAssets.RevokePermission) : (Result.Result<Text, Text>) {
            assets.validate_revoke_permission(args);
        };

        /// Validates the take ownership request.
        /// Returns an error if the validation fails.
        ///
        /// ```motoko
        /// let result = assetCanister.validate_take_ownership();
        /// ```
        public func validate_take_ownership() : (Result.Result<Text, Text>) {
            assets.validate_take_ownership();
        };

        /// Validates the arguments for committing a proposed batch of asset changes.
        /// Returns an error if the validation fails.
        ///
        /// ```motoko
        /// let result = assetCanister.validate_commit_proposed_batch({
        ///     batch_id = "batch-123";
        /// });
        /// ```
        public func validate_commit_proposed_batch(args : HttpAssets.CommitProposedBatchArguments) : (Result.Result<Text, Text>) {
            assets.validate_commit_proposed_batch(args);
        };

        /// Validates the configuration arguments for the asset canister.
        /// Returns an error if the validation fails.
        ///
        /// ```motoko
        /// let result = assetCanister.validate_configure({
        ///     max_asset_size = 2_000_000;
        ///     allowed_content_types = ["image/png", "text/html"];
        /// });
        /// ```
        public func validate_configure(args : HttpAssets.ConfigureArguments) : (Result.Result<Text, Text>) {
            assets.validate_configure(args);
        };
    };
};
