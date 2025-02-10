import Http "../../src";
import Json "mo:json";
import Text "mo:base/Text";
import Result "mo:base/Result";
import HttpPipeline "../../src/Pipeline";
import HttpRouter "../../src/Router";

actor {

    private func getUserById(_ : Http.HttpContext, routeContext : HttpRouter.RouteContext) : Http.HttpResponse {
        let ?#string(id) = routeContext.getParam("id") else return {
            statusCode = 400;
            headers = [];
            body = ?Text.encodeUtf8("Missing ID");
        };

        jsonResponse(200, #object_([("id", #string(id)), ("name", #string("name"))]));
    };

    public type User = {
        id : Text;
        name : Text;
    };

    public type CreateUserRequest = {
        name : Text;
    };

    private func createUser(context : Http.HttpContext, _ : HttpRouter.RouteContext) : Http.HttpResponse {
        let ?jsonText = Text.decodeUtf8(context.request.body) else return {
            statusCode = 400;
            headers = [];
            body = ?Text.encodeUtf8("Invalid JSON");
        };
        let _ : CreateUserRequest = switch (Json.parse(jsonText)) {
            case (#ok(json)) switch (deserializeCreateUserRequest(json)) {
                case (#ok(req)) req;
                case (#err(e)) return {
                    statusCode = 400;
                    headers = [];
                    body = ?Text.encodeUtf8("Invalid JSON: " # e);
                };
            };
            case (#err(e)) return {
                statusCode = 400;
                headers = [];
                body = ?Text.encodeUtf8("Invalid JSON: " # debug_show (e));
            };
        };
        // TODO create user

        jsonResponse(201, #object_([("id", #string("1"))]));
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

    let router = HttpRouter.empty()
    |> HttpRouter.route(_, "/users/{id}", getUserById)
    |> HttpRouter.route(_, "/users", createUser)
    |> HttpRouter.build(_);

    let pipeline = HttpPipeline.empty()
    |> HttpRouter.use(_, router)
    |> HttpPipeline.build(_);

    public func http_request(request : Http.RawQueryHttpRequest) : async Http.RawQueryHttpResponse {
        pipeline.http_request(request);
    };

    public func http_request_update(req : Http.RawUpdateHttpRequest) : async Http.RawUpdateHttpResponse {
        pipeline.http_request_update(req);
    };

};
