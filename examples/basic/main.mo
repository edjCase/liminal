import Http "../../src";
import Json "mo:json";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import HttpPipeline "../../src/Pipeline";
import HttpRouter "../../src/Router";
import Route "../../src/Route";
import HttpStaticAssets "../../src/StaticAssets";
import Assets "./Assets";

actor {

    stable var users : [User] = [];

    private func serializeUser(user : User) : Json.Json {
        #object_([("id", #number(#int(user.id))), ("name", #string(user.name))]);
    };

    private func getUsers(_ : Route.RouteContext) : Route.RouteResult {
        let usersJson : Json.Json = #array(users |> Array.map<User, Json.Json>(_, serializeUser));
        #ok(#json(usersJson));
    };

    private func getUserById(routeContext : Route.RouteContext) : Route.RouteResult {
        let idText = routeContext.getRouteParam("id");
        let ?id = Nat.fromText(idText) else return #badRequest("Invalid id '" #idText # "', must be a positive integer");

        let ?user = users
        |> Array.find(
            _,
            func(user : User) : Bool = user.id == id,
        ) else return #notFound(null);

        #ok(#json(serializeUser(user)));
    };

    public type User = {
        id : Nat;
        name : Text;
    };

    public type CreateUserRequest = {
        name : Text;
    };

    private func createUser(context : Route.RouteContext) : Route.RouteResult {
        let createUserRequest : CreateUserRequest = switch (context.parseJsonBody<CreateUserRequest>(deserializeCreateUserRequest)) {
            case (#err(e)) return #badRequest("Failed to parse Json. Error: " # e);
            case (#ok(req)) req;
        };

        let newUser : User = {
            id = users.size() + 1;
            name = createUserRequest.name;
        };

        users := Array.append(users, [newUser]);

        #created(#json(serializeUser(newUser)));
    };

    private func deserializeCreateUserRequest(json : Json.Json) : Result.Result<CreateUserRequest, Text> {
        let name = switch (Json.getAsText(json, "name")) {
            case (#ok(name)) name;
            case (#err(e)) return #err("Error with field 'name': " # debug_show (e));
        };
        #ok({
            name = name;
        });
    };

    private func helloWorld(_ : Route.RouteContext) : Route.RouteResult {
        #ok(#json(#object_([("message", #string("Hello, World!"))])));
    };

    let router = HttpRouter.defaultJsonRouter()
    |> HttpRouter.get(_, "/users/{id}", getUserById)
    |> HttpRouter.get(_, "/users", getUsers)
    |> HttpRouter.post(_, "/users", createUser)
    |> HttpRouter.get(_, "/", helloWorld)
    |> HttpRouter.build(_);

    let options : HttpStaticAssets.Options = {
        maxAge = 3600;
    };

    let pipeline = HttpPipeline.empty()
    |> HttpRouter.use(_, router)
    |> HttpStaticAssets.use(_, "/static", Assets.assets, options)
    |> HttpPipeline.build(_);

    public query func http_request(request : Http.RawQueryHttpRequest) : async Http.RawQueryHttpResponse {
        pipeline.http_request(request);
    };

    public func http_request_update(req : Http.RawUpdateHttpRequest) : async Http.RawUpdateHttpResponse {
        pipeline.http_request_update(req);
    };

};
