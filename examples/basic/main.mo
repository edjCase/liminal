import Http "../../src";
import Json "mo:json";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import HttpPipeline "../../src/Pipeline";
import HttpRouter "../../src/Router";
import Route "../../src/Route";

actor {

    var users : [User] = [];

    private func serializeUser(user : User) : Json.Json {
        #object_([("id", #number(#int(user.id))), ("name", #string(user.name))]);
    };

    private func getUsers(_ : Http.HttpContext, _ : Route.RouteContext) : Http.HttpResponse {
        let usersJson : Json.Json = #array(users |> Array.map<User, Json.Json>(_, serializeUser));
        jsonResponse(200, usersJson);
    };

    private func getUserById(_ : Http.HttpContext, routeContext : Route.RouteContext) : Http.HttpResponse {
        let ?idText = routeContext.getParam("id") else return {
            statusCode = 400;
            headers = [];
            body = ?Text.encodeUtf8("Missing ID");
        };
        let ?id = Nat.fromText(idText) else return {
            statusCode = 400;
            headers = [];
            body = ?Text.encodeUtf8("Invalid id, must be an Nat");
        };

        let ?user = users |> Array.find(_, func(user : User) : Bool = user.id == id) else return {
            statusCode = 404;
            headers = [];
            body = ?Text.encodeUtf8("User not found");
        };

        jsonResponse(
            200,
            serializeUser(user),
        );
    };

    private func getUsernameById(_ : Http.HttpContext, routeContext : Route.RouteContext) : Http.HttpResponse {
        let ?idText = routeContext.getParam("id") else return {
            statusCode = 400;
            headers = [];
            body = ?Text.encodeUtf8("Missing ID");
        };
        let ?id = Nat.fromText(idText) else return {
            statusCode = 400;
            headers = [];
            body = ?Text.encodeUtf8("Invalid id, must be an Nat");
        };

        let ?user = users |> Array.find(_, func(user : User) : Bool = user.id == id) else return {
            statusCode = 404;
            headers = [];
            body = ?Text.encodeUtf8("User not found");
        };

        jsonResponse(200, #object_([("name", #string(user.name))]));
    };

    public type User = {
        id : Nat;
        name : Text;
    };

    public type CreateUserRequest = {
        name : Text;
    };

    private func createUser(context : Http.HttpContext, _ : Route.RouteContext) : Http.HttpResponse {
        let createUserRequest : CreateUserRequest = switch (context.parseJson<CreateUserRequest>(deserializeCreateUserRequest)) {
            case (#err(e)) return {
                statusCode = 400;
                headers = [];
                body = ?Text.encodeUtf8("Failed to parse JSON: " # e);
            };
            case (#ok(req)) req;
        };

        let newUser : User = {
            id = users.size() + 1;
            name = createUserRequest.name;
        };

        users := Array.append(users, [newUser]);

        jsonResponse(201, #object_([("id", #number(#int(newUser.id)))]));
    };

    private func jsonResponse(statusCode : Nat, json : Json.Json) : Http.HttpResponse {
        {
            statusCode = statusCode;
            headers = [("Content-Type", "application/json")];
            body = ?Text.encodeUtf8(Json.stringify(json, null));
        };
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

    private func helloWorld(_ : Http.HttpContext, _ : Route.RouteContext) : Http.HttpResponse {
        jsonResponse(200, #object_([("message", #string("Hello, World!"))]));
    };

    let router = HttpRouter.empty()
    |> HttpRouter.get(_, "/users/{id}", getUserById)
    |> HttpRouter.get(_, "/users/{id}/name", getUsernameById)
    |> HttpRouter.get(_, "/users", getUsers)
    |> HttpRouter.post(_, "/users", createUser)
    |> HttpRouter.get(_, "/", helloWorld)
    |> HttpRouter.build(_);

    let pipeline = HttpPipeline.empty()
    |> HttpRouter.use(_, router)
    |> HttpPipeline.build(_);

    public query func http_request(request : Http.RawQueryHttpRequest) : async Http.RawQueryHttpResponse {
        pipeline.http_request(request);
    };

    public func http_request_update(req : Http.RawUpdateHttpRequest) : async Http.RawUpdateHttpResponse {
        pipeline.http_request_update(req);
    };

};
