import Http "../../src";
import HttpPipeline "../../src/Pipeline";
import HttpRouter "../../src/Router";
import Route "../../src/Route";
import UserHandler "UserHandler";
import UserRouter "UserRouter";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import CORS "../../src/CORS";
import LoggingHandler "LoggingHandler";
import IC "mo:ic";
import HttpAssets "../../src/Assets";
import Assets "mo:ic-assets";
import AssetCanister "../../src/Assets/AssetCanister";

shared ({ caller = initializer }) actor class Actor() = self {

    stable var userStableData : UserHandler.StableData = {
        users = [];
    };

    let canisterId = Principal.fromActor(self);

    stable var assetStableData = Assets.init_stable_store(canisterId, initializer);

    var assetStore = Assets.Assets(assetStableData);
    var assetCanister = AssetCanister.AssetCanister(assetStore);

    var userHandler = UserHandler.Handler(userStableData);

    let userRouter = UserRouter.Router(userHandler);

    // Upgrade methods

    system func preupgrade() {
        userStableData := userHandler.toStableData();
    };

    system func postupgrade() {
        userHandler := UserHandler.Handler(userStableData);
    };

    // Http Server pipeline

    let pipeline = HttpPipeline.empty()
    // Logging middleware
    |> LoggingHandler.use(_)
    // CORS middleware
    |> CORS.use(_, CORS.defaultOptions)
    // Router
    |> HttpRouter.use(
        _,
        {
            errorSerializer = null;
            responseHeaders = [];
            routes = HttpRouter.RouteBuilder()
            |> _.prefix(
                "/api",
                func(builder : HttpRouter.RouteBuilder) : HttpRouter.RouteBuilder {
                    builder
                    |> _.prefix(
                        "/users",
                        func(builder : HttpRouter.RouteBuilder) : HttpRouter.RouteBuilder {
                            builder
                            |> _.getQuery("/{id}", userRouter.getById)
                            |> _.getQuery("/", userRouter.get)
                            |> _.postUpdate("/", userRouter.create);
                        },
                    )
                    |> _.getUpdateAsync(
                        "/hash",
                        func(_ : Route.RouteContext) : async* Route.RouteResult {
                            let ic = actor ("aaaaa-aa") : IC.Service;
                            let result = await ic.canister_info({
                                canister_id = Principal.fromActor(self);
                                num_requested_changes = ?0;
                            });
                            let hashJson = switch (result.module_hash) {
                                case (null) #null_;
                                case (?hash) #string(debug_show (Blob.toArray(hash)));
                            };
                            #ok(#json(#object_([("hash", hashJson)])));
                        },
                    );
                },
            )
            |> _.build();
        }

    )
    // Static assets
    |> HttpAssets.use(
        _,
        "/",
        {
            cache = {
                default = #public_({
                    immutable = false;
                    maxAge = 3600;
                });
                rules = [
                    {
                        pattern = "/index.html";
                        cache = #public_({
                            immutable = true;
                            maxAge = 3600;
                        });
                    },
                ];
            };
            store = assetStore;
            indexAssetPath = ?"/index.html";
        },
    )
    |> HttpPipeline.build(_);

    // Http server

    public query func http_request(request : Http.RawQueryHttpRequest) : async Http.RawQueryHttpResponse {
        pipeline.http_request(request);
    };

    public func http_request_update(req : Http.RawUpdateHttpRequest) : async Http.RawUpdateHttpResponse {
        await* pipeline.http_request_update(req);
    };

    // Asset canister

    public query func http_request_streaming_callback(token : Assets.StreamingToken) : async (Assets.StreamingCallbackResponse) {
        assetStore.http_request_streaming_callback(token);
    };

    assetStore.set_streaming_callback(http_request_streaming_callback);

    public shared query func api_version() : async Nat16 {
        assetCanister.api_version();
    };

    public shared query func get(args : Assets.GetArgs) : async Assets.EncodedAsset {
        assetCanister.get(args);
    };

    public shared query func get_chunk(args : Assets.GetChunkArgs) : async (Assets.ChunkContent) {
        assetCanister.get_chunk(args);
    };

    public shared ({ caller }) func grant_permission(args : Assets.GrantPermission) : async () {
        await* assetCanister.grant_permission(caller, args);
    };

    public shared ({ caller }) func revoke_permission(args : Assets.RevokePermission) : async () {
        await* assetCanister.revoke_permission(caller, args);
    };

    public shared query func list(args : {}) : async [Assets.AssetDetails] {
        assetCanister.list(args);
    };

    public shared ({ caller }) func store(args : Assets.StoreArgs) : async () {
        assetCanister.store(caller, args);
    };

    public shared ({ caller }) func create_asset(args : Assets.CreateAssetArguments) : async () {
        assetCanister.create_asset(caller, args);
    };

    public shared ({ caller }) func set_asset_content(args : Assets.SetAssetContentArguments) : async () {
        await* assetCanister.set_asset_content(caller, args);
    };

    public shared ({ caller }) func unset_asset_content(args : Assets.UnsetAssetContentArguments) : async () {
        assetCanister.unset_asset_content(caller, args);
    };

    public shared ({ caller }) func delete_asset(args : Assets.DeleteAssetArguments) : async () {
        assetCanister.delete_asset(caller, args);
    };

    public shared ({ caller }) func set_asset_properties(args : Assets.SetAssetPropertiesArguments) : async () {
        assetCanister.set_asset_properties(caller, args);
    };

    public shared ({ caller }) func clear(args : Assets.ClearArguments) : async () {
        assetCanister.clear(caller, args);
    };

    public shared ({ caller }) func create_batch(args : {}) : async (Assets.CreateBatchResponse) {
        assetCanister.create_batch(caller, args);
    };

    public shared ({ caller }) func create_chunk(args : Assets.CreateChunkArguments) : async (Assets.CreateChunkResponse) {
        assetCanister.create_chunk(caller, args);
    };

    public shared ({ caller }) func create_chunks(args : Assets.CreateChunksArguments) : async Assets.CreateChunksResponse {
        await* assetCanister.create_chunks(caller, args);
    };

    public shared ({ caller }) func commit_batch(args : Assets.CommitBatchArguments) : async () {
        await* assetCanister.commit_batch(caller, args);
    };

    public shared ({ caller }) func propose_commit_batch(args : Assets.CommitBatchArguments) : async () {
        assetCanister.propose_commit_batch(caller, args);
    };

    public shared ({ caller }) func commit_proposed_batch(args : Assets.CommitProposedBatchArguments) : async () {
        await* assetCanister.commit_proposed_batch(caller, args);
    };

    public shared ({ caller }) func compute_evidence(args : Assets.ComputeEvidenceArguments) : async (?Blob) {
        await* assetCanister.compute_evidence(caller, args);
    };

    public shared ({ caller }) func delete_batch(args : Assets.DeleteBatchArguments) : async () {
        assetCanister.delete_batch(caller, args);
    };

    public shared ({ caller }) func authorize(principal : Principal) : async () {
        await* assetCanister.authorize(caller, principal);
    };

    public shared ({ caller }) func deauthorize(principal : Principal) : async () {
        await* assetCanister.deauthorize(caller, principal);
    };

    public shared func list_authorized() : async ([Principal]) {
        assetCanister.list_authorized();
    };

    public shared func list_permitted(args : Assets.ListPermitted) : async ([Principal]) {
        assetCanister.list_permitted(args);
    };

    public shared ({ caller }) func take_ownership() : async () {
        await* assetCanister.take_ownership(caller);
    };

    public shared ({ caller }) func get_configuration() : async (Assets.ConfigurationResponse) {
        assetCanister.get_configuration(caller);
    };

    public shared ({ caller }) func configure(args : Assets.ConfigureArguments) : async () {
        assetCanister.configure(caller, args);
    };

    public shared func certified_tree(args : {}) : async (Assets.CertifiedTree) {
        assetCanister.certified_tree(args);
    };
    public shared func validate_grant_permission(args : Assets.GrantPermission) : async (Result.Result<Text, Text>) {
        assetCanister.validate_grant_permission(args);
    };

    public shared func validate_revoke_permission(args : Assets.RevokePermission) : async (Result.Result<Text, Text>) {
        assetCanister.validate_revoke_permission(args);
    };

    public shared func validate_take_ownership() : async (Result.Result<Text, Text>) {
        assetCanister.validate_take_ownership();
    };

    public shared func validate_commit_proposed_batch(args : Assets.CommitProposedBatchArguments) : async (Result.Result<Text, Text>) {
        assetCanister.validate_commit_proposed_batch(args);
    };

    public shared func validate_configure(args : Assets.ConfigureArguments) : async (Result.Result<Text, Text>) {
        assetCanister.validate_configure(args);
    };

};
