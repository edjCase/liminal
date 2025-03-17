import Assets "mo:ic-assets";
import Result "mo:base/Result";
import Debug "mo:base/Debug";

module {

    public class AssetCanister(assets : Assets.Assets) = self {

        public func api_version() : Nat16 {
            assets.api_version();
        };

        public func get(args : Assets.GetArgs) : Assets.EncodedAsset {
            switch (assets.get(args)) {
                case (#ok(asset)) asset;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func get_chunk(args : Assets.GetChunkArgs) : (Assets.ChunkContent) {
            switch (assets.get_chunk(args)) {
                case (#ok(chunk)) chunk;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func grant_permission(caller : Principal, args : Assets.GrantPermission) : async* () {
            switch (await* assets.grant_permission(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func revoke_permission(caller : Principal, args : Assets.RevokePermission) : async* () {
            switch (await* assets.revoke_permission(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func list(args : {}) : [Assets.AssetDetails] {
            assets.list(args);
        };

        public func store(caller : Principal, args : Assets.StoreArgs) : () {
            switch (assets.store(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func create_asset(caller : Principal, args : Assets.CreateAssetArguments) : () {
            switch (assets.create_asset(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func set_asset_content(caller : Principal, args : Assets.SetAssetContentArguments) : async* () {
            switch (await* assets.set_asset_content(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func unset_asset_content(caller : Principal, args : Assets.UnsetAssetContentArguments) : () {
            switch (assets.unset_asset_content(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func delete_asset(caller : Principal, args : Assets.DeleteAssetArguments) : () {
            switch (assets.delete_asset(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func set_asset_properties(caller : Principal, args : Assets.SetAssetPropertiesArguments) : () {
            switch (assets.set_asset_properties(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func clear(caller : Principal, args : Assets.ClearArguments) : () {
            switch (assets.clear(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func create_batch(caller : Principal, args : {}) : (Assets.CreateBatchResponse) {
            switch (assets.create_batch(caller, args)) {
                case (#ok(response)) response;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func create_chunk(caller : Principal, args : Assets.CreateChunkArguments) : (Assets.CreateChunkResponse) {
            switch (assets.create_chunk(caller, args)) {
                case (#ok(response)) response;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func create_chunks(caller : Principal, args : Assets.CreateChunksArguments) : async* Assets.CreateChunksResponse {
            switch (await* assets.create_chunks(caller, args)) {
                case (#ok(response)) response;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func commit_batch(caller : Principal, args : Assets.CommitBatchArguments) : async* () {
            switch (await* assets.commit_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func propose_commit_batch(caller : Principal, args : Assets.CommitBatchArguments) : () {
            switch (assets.propose_commit_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func commit_proposed_batch(caller : Principal, args : Assets.CommitProposedBatchArguments) : async* () {
            switch (await* assets.commit_proposed_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func compute_evidence(caller : Principal, args : Assets.ComputeEvidenceArguments) : async* (?Blob) {
            switch (await* assets.compute_evidence(caller, args)) {
                case (#ok(evidence)) evidence;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func delete_batch(caller : Principal, args : Assets.DeleteBatchArguments) : () {
            switch (assets.delete_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func authorize(caller : Principal, principal : Principal) : async* () {
            switch (await* assets.authorize(caller, principal)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func deauthorize(caller : Principal, principal : Principal) : async* () {
            switch (await* assets.deauthorize(caller, principal)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func list_authorized() : ([Principal]) {
            assets.list_authorized();
        };

        public func list_permitted(args : Assets.ListPermitted) : ([Principal]) {
            assets.list_permitted(args);
        };

        public func take_ownership(caller : Principal) : async* () {
            switch (await* assets.take_ownership(caller)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func get_configuration(caller : Principal) : (Assets.ConfigurationResponse) {
            switch (assets.get_configuration(caller)) {
                case (#ok(config)) config;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func configure(caller : Principal, args : Assets.ConfigureArguments) : () {
            switch (assets.configure(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func certified_tree({}) : (Assets.CertifiedTree) {
            switch (assets.certified_tree()) {
                case (#ok(tree)) tree;
                case (#err(err)) Debug.trap(err);
            };
        };

        public func validate_grant_permission(args : Assets.GrantPermission) : (Result.Result<Text, Text>) {
            assets.validate_grant_permission(args);
        };

        public func validate_revoke_permission(args : Assets.RevokePermission) : (Result.Result<Text, Text>) {
            assets.validate_revoke_permission(args);
        };

        public func validate_take_ownership() : (Result.Result<Text, Text>) {
            assets.validate_take_ownership();
        };

        public func validate_commit_proposed_batch(args : Assets.CommitProposedBatchArguments) : (Result.Result<Text, Text>) {
            assets.validate_commit_proposed_batch(args);
        };

        public func validate_configure(args : Assets.ConfigureArguments) : (Result.Result<Text, Text>) {
            assets.validate_configure(args);
        };
    };
};
