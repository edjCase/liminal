import HttpAssets "mo:http-assets";
import Result "mo:new-base/Result";
import Runtime "mo:new-base/Runtime";

module {

    public class AssetCanister(assets : HttpAssets.Assets) = self {

        public func api_version() : Nat16 {
            assets.api_version();
        };

        public func get(args : HttpAssets.GetArgs) : HttpAssets.EncodedAsset {
            switch (assets.get(args)) {
                case (#ok(asset)) asset;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func get_chunk(args : HttpAssets.GetChunkArgs) : (HttpAssets.ChunkContent) {
            switch (assets.get_chunk(args)) {
                case (#ok(chunk)) chunk;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func grant_permission(caller : Principal, args : HttpAssets.GrantPermission) : async* () {
            switch (await* assets.grant_permission(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func revoke_permission(caller : Principal, args : HttpAssets.RevokePermission) : async* () {
            switch (await* assets.revoke_permission(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func list(args : {}) : [HttpAssets.AssetDetails] {
            assets.list(args);
        };

        public func store(caller : Principal, args : HttpAssets.StoreArgs) : () {
            switch (assets.store(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func create_asset(caller : Principal, args : HttpAssets.CreateAssetArguments) : () {
            switch (assets.create_asset(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func set_asset_content(caller : Principal, args : HttpAssets.SetAssetContentArguments) : async* () {
            switch (await* assets.set_asset_content(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func unset_asset_content(caller : Principal, args : HttpAssets.UnsetAssetContentArguments) : () {
            switch (assets.unset_asset_content(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func delete_asset(caller : Principal, args : HttpAssets.DeleteAssetArguments) : () {
            switch (assets.delete_asset(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func set_asset_properties(caller : Principal, args : HttpAssets.SetAssetPropertiesArguments) : () {
            switch (assets.set_asset_properties(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func clear(caller : Principal, args : HttpAssets.ClearArguments) : () {
            switch (assets.clear(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func create_batch(caller : Principal, args : {}) : (HttpAssets.CreateBatchResponse) {
            switch (assets.create_batch(caller, args)) {
                case (#ok(response)) response;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func create_chunk(caller : Principal, args : HttpAssets.CreateChunkArguments) : (HttpAssets.CreateChunkResponse) {
            switch (assets.create_chunk(caller, args)) {
                case (#ok(response)) response;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func create_chunks(caller : Principal, args : HttpAssets.CreateChunksArguments) : async* HttpAssets.CreateChunksResponse {
            switch (await* assets.create_chunks(caller, args)) {
                case (#ok(response)) response;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func commit_batch(caller : Principal, args : HttpAssets.CommitBatchArguments) : async* () {
            switch (await* assets.commit_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func propose_commit_batch(caller : Principal, args : HttpAssets.CommitBatchArguments) : () {
            switch (assets.propose_commit_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func commit_proposed_batch(caller : Principal, args : HttpAssets.CommitProposedBatchArguments) : async* () {
            switch (await* assets.commit_proposed_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func compute_evidence(caller : Principal, args : HttpAssets.ComputeEvidenceArguments) : async* (?Blob) {
            switch (await* assets.compute_evidence(caller, args)) {
                case (#ok(evidence)) evidence;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func delete_batch(caller : Principal, args : HttpAssets.DeleteBatchArguments) : () {
            switch (assets.delete_batch(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func authorize(caller : Principal, principal : Principal) : async* () {
            switch (await* assets.authorize(caller, principal)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func deauthorize(caller : Principal, principal : Principal) : async* () {
            switch (await* assets.deauthorize(caller, principal)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func list_authorized() : ([Principal]) {
            assets.list_authorized();
        };

        public func list_permitted(args : HttpAssets.ListPermitted) : ([Principal]) {
            assets.list_permitted(args);
        };

        public func take_ownership(caller : Principal) : async* () {
            switch (await* assets.take_ownership(caller)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func get_configuration(caller : Principal) : (HttpAssets.ConfigurationResponse) {
            switch (assets.get_configuration(caller)) {
                case (#ok(config)) config;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func configure(caller : Principal, args : HttpAssets.ConfigureArguments) : () {
            switch (assets.configure(caller, args)) {
                case (#ok(_)) return;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func certified_tree({}) : (HttpAssets.CertifiedTree) {
            switch (assets.certified_tree()) {
                case (#ok(tree)) tree;
                case (#err(err)) Runtime.trap(err);
            };
        };

        public func validate_grant_permission(args : HttpAssets.GrantPermission) : (Result.Result<Text, Text>) {
            assets.validate_grant_permission(args);
        };

        public func validate_revoke_permission(args : HttpAssets.RevokePermission) : (Result.Result<Text, Text>) {
            assets.validate_revoke_permission(args);
        };

        public func validate_take_ownership() : (Result.Result<Text, Text>) {
            assets.validate_take_ownership();
        };

        public func validate_commit_proposed_batch(args : HttpAssets.CommitProposedBatchArguments) : (Result.Result<Text, Text>) {
            assets.validate_commit_proposed_batch(args);
        };

        public func validate_configure(args : HttpAssets.ConfigureArguments) : (Result.Result<Text, Text>) {
            assets.validate_configure(args);
        };
    };
};
