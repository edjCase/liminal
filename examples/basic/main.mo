import Http "../../src";
import HttpPipeline "../../src/Pipeline";
import HttpRouter "../../src/Router";
import Route "../../src/Route";
import HttpStaticAssets "../../src/StaticAssets";
import UserHandler "UserHandler";
import UserRouter "UserRouter";
import StaticAssetHandler "StaticAssetHandler";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";

actor Actor {

    stable var userStableData : UserHandler.StableData = {
        users = [];
    };

    stable var staticAssetStableData : StaticAssetHandler.StableData = {
        assets = [];
    };

    let staticAssetHandler = StaticAssetHandler.Handler(staticAssetStableData);

    let userHandler = UserHandler.Handler(userStableData);

    let userRouter = UserRouter.Router(userHandler);

    private func helloWorld(_ : Route.RouteContext) : Route.RouteResult {
        #ok(#json(#object_([("message", #string("Hello, World!"))])));
    };

    type CanisterInfoArgs = {
        canister_id : Principal;
        num_requested_changes : ?Nat64;
    };
    type CanisterInfoResult = {
        controllers : [Principal];
        module_hash : ?Blob;
        recent_changes : [Change];
        total_num_changes : Nat64;
    };
    type Change = {
        timestamp_nanos : Nat64;
        canister_version : Nat64;
        origin : ChangeOrigin;
        details : ChangeDetails;
    };
    type ChangeDetails = {
        #creation : { controllers : [Principal] };
        #code_deployment : {
            mode : { #reinstall; #upgrade; #install };
            module_hash : Blob;
        };
        #load_snapshot : {
            canister_version : Nat64;
            taken_at_timestamp : Nat64;
            snapshot_id : Blob;
        };
        #controllers_change : { controllers : [Principal] };
        #code_uninstall;
    };
    type ChangeOrigin = {
        #from_user : { user_id : Principal };
        #from_canister : { canister_version : ?Nat64; canister_id : Principal };
    };
    type IC = actor {
        canister_info : shared CanisterInfoArgs -> async CanisterInfoResult;
    };

    private func getCanisterHashAsync(_ : Route.RouteContext) : async* Route.RouteResult {
        let ic = actor ("aaaaa-aa") : IC;
        let result = await ic.canister_info({
            canister_id = Principal.fromActor(Actor);
            num_requested_changes = ?0;
        });
        let hashJson = switch (result.module_hash) {
            case (null) #null_;
            case (?hash) #string(debug_show (Blob.toArray(hash)));
        };
        #ok(#json(#object_([("hash", hashJson)])));
    };

    let pipeline = HttpPipeline.empty()
    // Router
    |> HttpRouter.use(
        _,
        HttpRouter.RouterBuilder()
        |> _.getQuery("/users/{id}", userRouter.getById)
        |> _.getQuery("/users", userRouter.get)
        |> _.postUpdate("/users", userRouter.create)
        |> _.getQuery("/", helloWorld)
        |> _.getUpdateAsync("/hash", getCanisterHashAsync)
        |> _.addResponseHeader(("content-type", "application/json"))
        |> _.build(),
    )
    // Static assets
    |> HttpStaticAssets.use(
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
            assetHandler = staticAssetHandler.get;
        },
    )
    |> HttpPipeline.build(_);

    public query func http_request(request : Http.RawQueryHttpRequest) : async Http.RawQueryHttpResponse {
        pipeline.http_request(request);
    };

    public func http_request_update(req : Http.RawUpdateHttpRequest) : async Http.RawUpdateHttpResponse {
        await* pipeline.http_request_update(req);
    };

};
