import Http "../../src";
import HttpPipeline "../../src/Pipeline";
import HttpRouter "../../src/Router";
import Route "../../src/Route";
import UserHandler "UserHandler";
import UserRouter "UserRouter";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import CORS "../../src/CORS";
import LoggingHandler "LoggingHandler";
import IC "mo:ic";
import HttpAssets "../../src/Assets";
import AssetStore "../../src/Assets/AssetStore";
import AssetCanister "../../src/Assets/AssetCanister";

shared ({ caller = initializer }) actor class Actor() = self {

    stable var userStableData : UserHandler.StableData = {
        users = [];
    };

    stable var assetStableData : AssetStore.StableData = {
        assets = [];
    };

    stable var assetCanisterStableData : AssetCanister.StableData = {
        adminIds = [initializer];
        chunks = [];
        batches = [];
    };

    var assetStore = AssetStore.Store(assetStableData);

    var userHandler = UserHandler.Handler(userStableData);

    var assetCanisterHandler = AssetCanister.Handler(
        assetCanisterStableData,
        assetStore,
        AssetCanister.defaultOptions(),
    );

    system func preupgrade() {
        userStableData := userHandler.toStableData();
        assetStableData := assetStore.toStableData();
        assetCanisterStableData := assetCanisterHandler.toStableData();
    };

    system func postupgrade() {
        userHandler := UserHandler.Handler(userStableData);
        assetStore := AssetStore.Store(assetStableData);
        assetCanisterHandler := AssetCanister.Handler(assetCanisterStableData, assetStore, AssetCanister.defaultOptions());
    };

    let userRouter = UserRouter.Router(userHandler);

    private func helloWorld(_ : Route.RouteContext) : Route.RouteResult {
        #ok(#json(#object_([("message", #string("Hello, World!"))])));
    };

    let pipeline = HttpPipeline.empty()
    // Logging middleware
    |> LoggingHandler.use(_)
    // CORS middleware
    |> CORS.use(_, CORS.defaultOptions)
    // Router
    |> HttpRouter.use(
        _,
        HttpRouter.RouterBuilder()
        |> _.getQuery("/users/{id}", userRouter.getById)
        |> _.getQuery("/users", userRouter.get)
        |> _.postUpdate("/users", userRouter.create)
        |> _.getQuery("/", helloWorld)
        |> _.deleteQuery("/", helloWorld)
        |> _.putQuery("/", helloWorld)
        |> _.patchQuery("/", helloWorld)
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
        )
        |> _.addResponseHeader(("content-type", "application/json"))
        |> _.build(),
    )
    // Static assets
    |> HttpAssets.use(
        _,
        "/static",
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
        },
    )
    |> HttpPipeline.build(_);

    public query func http_request(request : Http.RawQueryHttpRequest) : async Http.RawQueryHttpResponse {
        pipeline.http_request(request);
    };

    public func http_request_update(req : Http.RawUpdateHttpRequest) : async Http.RawUpdateHttpResponse {
        await* pipeline.http_request_update(req);
    };

    // Asset canister

    public shared ({ caller }) func authorize(other : Principal) : async () {
        assetCanisterHandler.authorize(other, caller);
    };

    public query func retrieve(path : Text) : async Blob {
        assetCanisterHandler.retrieve(path);
    };

    public shared ({ caller }) func store(request : AssetCanister.StoreRequest) : async () {
        assetCanisterHandler.store(request, caller);
    };

    public query func list(request : {}) : async [AssetCanister.AssetDetails] {
        assetCanisterHandler.list(request);
    };

    public query func get(request : AssetCanister.GetRequest) : async AssetCanister.GetResponse {
        assetCanisterHandler.get(request);
    };

    public query func get_chunk(request : AssetCanister.GetChunkRequest) : async AssetCanister.GetChunkResponse {
        assetCanisterHandler.get_chunk(request);
    };

    public shared ({ caller }) func create_batch(request : AssetCanister.CreateBatchRequest) : async AssetCanister.CreateBatchResponse {
        assetCanisterHandler.create_batch(request, caller);
    };

    public shared ({ caller }) func create_chunk(request : AssetCanister.CreateChunkRequest) : async AssetCanister.CreateChunkResponse {
        assetCanisterHandler.create_chunk(request, caller);
    };

    public shared ({ caller }) func commit_batch(request : AssetCanister.CommitBatchRequest) : async () {
        assetCanisterHandler.commit_batch(request, caller);
    };

    public shared ({ caller }) func create_asset(request : AssetCanister.CreateAssetRequest) : async () {
        assetCanisterHandler.create_asset(request, caller);
    };

    public shared ({ caller }) func set_asset_content(request : AssetCanister.SetAssetContentRequest) : async () {
        assetCanisterHandler.set_asset_content(request, caller);
    };

    public shared ({ caller }) func unset_asset_content(request : AssetCanister.UnsetAssetContentRequest) : async () {
        assetCanisterHandler.unset_asset_content(request, caller);
    };

    public shared ({ caller }) func delete_asset(request : AssetCanister.DeleteAssetRequest) : async () {
        assetCanisterHandler.delete_asset(request, caller);
    };

    public shared ({ caller }) func clear(request : AssetCanister.ClearRequest) : async () {
        assetCanisterHandler.clear(request, caller);
    };

    public query func http_request_streaming_callback(request : AssetCanister.StreamingCallbackRequest) : async AssetCanister.StreamingCallbackHttpResponse {
        assetCanisterHandler.http_request_streaming_callback(request);
    };

};
