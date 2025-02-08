import Http "../../src";
import IterTools "mo:itertools/Iter";
import Json "mo:json";
import Text "mo:base/Text";
import Result "mo:base/Result";

actor {

    private func getRouteParam(params : [(Text, Text)], key : Text) : ?Text {
        let ?kv = IterTools.find<(Text, Text)>(params.vals(), func(kv : (Text, Text)) : Bool = kv.0 == key) else return null;
        ?kv.1;
    };

    private func getUserById(context : Http.HttpContext) : Http.HttpResponseRaw {
        let ?id = getRouteParam(context.routeParams, "id") else return {
            statusCode = 400;
            headers = [];
            body = ?Text.encodeUtf8("Missing ID");
        };
        {
            statusCode = 200;
            headers = [];
            body = ?Text.encodeUtf8(Json.stringify(#object_([("id", #string(id)), ("name", #string("name"))]), null));
        };
    };

    public type User = {
        id : Text;
        name : Text;
    };
    private func getUserByIdTyped(context : Http.HttpContext) : Http.HttpResponseTyped<User> {
        let ?id = getRouteParam(context.routeParams, "id") else return {
            statusCode = 400;
            headers = [];
            body =;
        };
        Http.ok<User>(
            ?{
                id = id;
                name = "name";
            }
        );
    };

    public type CreateUserRequest = {
        name : Text;
    };

    private func createUser(body : Blob, context : Http.HttpContext) : Http.HttpResponseRaw {
        let ?jsonText = Text.decodeUtf8(body) else return {
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

        jsonResponse(#object_([("id", #string("1"))]));
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

    let router = Http.Router().addRawGetRoute("/users/:id", getUserById).addPostRoute("/users", createUser).addTypedGetRoute<User>("/users/:id", getUserByIdTyped, serializeUser);

    public func http_request(request : Http.RawQueryHttpRequest) : async Http.RawQueryHttpResponse {
        router.http_request(request);
    };

    public func http_request_update(req : Http.RawUpdateHttpRequest) : async Http.RawUpdateHttpResponse {
        await* router.http_request_update(req);
    };

};
