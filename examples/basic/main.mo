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
import Cors "../../src/Cors";
import LoggingHandler "LoggingHandler";
import IC "mo:ic";

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

    let pipeline = HttpPipeline.empty()
    // Logging middleware
    |> LoggingHandler.use(_)
    // Cors middleware
    |> Cors.use(_, Cors.defaultOptions)
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
