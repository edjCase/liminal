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

actor Actor {

    stable var userStableData : UserHandler.StableData = {
        users = [];
    };

    stable var assetStableData : AssetStore.StableData = {
        assets = [];
    };

    var assetStore = AssetStore.Store(assetStableData);

    var userHandler = UserHandler.Handler(userStableData);

    system func preupgrade() {
        userStableData := userHandler.toStableData();
        assetStableData := assetStore.toStableData();
    };

    system func postupgrade() {
        userHandler := UserHandler.Handler(userStableData);
        assetStore := AssetStore.Store(assetStableData);
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
                    canister_id = Principal.fromActor(Actor);
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

    // public shared ({ caller }) func authorize(other : Principal) : async () {
    //     assets.authorize({
    //         caller;
    //         other;
    //     });
    // };

    // public query func retrieve(path : Assets.Path) : async Assets.Contents {
    //     assets.retrieve(path);
    // };

    // public shared ({ caller }) func store(
    //     arg : {
    //         key : Assets.Key;
    //         content_type : Text;
    //         content_encoding : Text;
    //         content : Blob;
    //         sha256 : ?Blob;
    //     }
    // ) : async () {
    //     assets.store({
    //         caller;
    //         arg;
    //     });
    // };

    // public query func list(arg : {}) : async [T.AssetDetails] {
    //     assets.list(arg);
    // };
    // public query func get(
    //     arg : {
    //         key : T.Key;
    //         accept_encodings : [Text];
    //     }
    // ) : async ({
    //     content : Blob;
    //     content_type : Text;
    //     content_encoding : Text;
    //     total_length : Nat;
    //     sha256 : ?Blob;
    // }) {
    //     assets.get(arg);
    // };

    // public query func get_chunk(
    //     arg : {
    //         key : T.Key;
    //         content_encoding : Text;
    //         index : Nat;
    //         sha256 : ?Blob;
    //     }
    // ) : async ({
    //     content : Blob;
    // }) {
    //     assets.get_chunk(arg);
    // };

    // public shared ({ caller }) func create_batch(arg : {}) : async ({
    //     batch_id : T.BatchId;
    // }) {
    //     assets.create_batch({
    //         caller;
    //         arg;
    //     });
    // };

    // public shared ({ caller }) func create_chunk(
    //     arg : {
    //         batch_id : T.BatchId;
    //         content : Blob;
    //     }
    // ) : async ({
    //     chunk_id : T.ChunkId;
    // }) {
    //     assets.create_chunk({
    //         caller;
    //         arg;
    //     });
    // };

    // public shared ({ caller }) func commit_batch(args : T.CommitBatchArguments) : async () {
    //     assets.commit_batch({
    //         caller;
    //         args;
    //     });
    // };
    // public shared ({ caller }) func create_asset(arg : T.CreateAssetArguments) : async () {
    //     assets.create_asset({
    //         caller;
    //         arg;
    //     });
    // };

    // public shared ({ caller }) func set_asset_content(arg : T.SetAssetContentArguments) : async () {
    //     assets.set_asset_content({
    //         caller;
    //         arg;
    //     });
    // };

    // public shared ({ caller }) func unset_asset_content(args : T.UnsetAssetContentArguments) : async () {
    //     assets.unset_asset_content({
    //         caller;
    //         args;
    //     });
    // };

    // public shared ({ caller }) func delete_asset(args : T.DeleteAssetArguments) : async () {
    //     assets.delete_asset({
    //         caller;
    //         args;
    //     });
    // };

    // public shared ({ caller }) func clear(args : T.ClearArguments) : async () {
    //     assets.clear({
    //         caller;
    //         args;
    //     });
    // };

    // public query func http_request_streaming_callback(token : T.StreamingCallbackToken) : async StreamingCallbackHttpResponse {
    //     assets.http_request_streaming_callback(token);
    // };

};
