import Types "./Types";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Pipeline "./Pipeline";
import TextX "mo:xtended-text/TextX";
import HttpContext "./HttpContext";
import HttpMethod "./HttpMethod";
import Route "./Route";
import IterTools "mo:itertools/Iter";
import Json "mo:json";
import Path "Path";

module Module {

    public type Error = {
        statusCode : Nat;
        message : ?Text;
    };

    public type SerializedError = {
        body : Blob;
        headers : [(Text, Text)];
    };

    public type Route = {
        pathSegments : [Route.PathSegment];
        method : Route.RouteMethod;
        handler : Route.RouteHandler;
    };

    public type ErrorSerializer = (Error -> SerializedError);

    public type ResponseHeader = (Text, Text);

    public class RouteBuilder() = self {
        let routes = Buffer.Buffer<Route>(2);

        public func prefix(
            prefix : Text,
            routeBuilder : () -> [Route],
        ) : RouteBuilder {
            let pathSegments = switch (Route.parsePathSegments(prefix)) {
                case (#ok(segments)) segments;
                case (#err(e)) Debug.trap("Failed to parse prefix " # prefix # " into segments: " # e);
            };
            let subRoutes = routeBuilder();
            for (subRoute in subRoutes.vals()) {
                routes.add({
                    pathSegments = Array.append(pathSegments, subRoute.pathSegments);
                    method = subRoute.method;
                    handler = subRoute.handler;
                });
            };
            self;
        };

        public func getQuery(
            path : Text,
            handler : (Route.RouteContext) -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #get, #syncQuery(handler));
        };

        public func getUpdate(
            path : Text,
            handler : <system>(Route.RouteContext) -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #get, #syncUpdate(handler));
        };

        public func getUpdateAsync(
            path : Text,
            handler : Route.RouteContext -> async* Route.RouteResult,
        ) : RouteBuilder {
            route(path, #get, #asyncUpdate(handler));
        };

        public func postQuery(
            path : Text,
            handler : Route.RouteContext -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #post, #syncQuery(handler));
        };

        public func postUpdate(
            path : Text,
            handler : <system>(Route.RouteContext) -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #post, #syncUpdate(handler));
        };

        public func postUpdateAsync(
            path : Text,
            handler : Route.RouteContext -> async* Route.RouteResult,
        ) : RouteBuilder {
            route(path, #post, #asyncUpdate(handler));
        };

        public func putQuery(
            path : Text,
            handler : Route.RouteContext -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #put, #syncQuery(handler));
        };

        public func putUpdate(
            path : Text,
            handler : <system>(Route.RouteContext) -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #put, #syncUpdate(handler));
        };

        public func putUpdateAsync(
            path : Text,
            handler : Route.RouteContext -> async* Route.RouteResult,
        ) : RouteBuilder {
            route(path, #put, #asyncUpdate(handler));
        };

        public func patchQuery(
            path : Text,
            handler : Route.RouteContext -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #patch, #syncQuery(handler));
        };

        public func patchUpdate(
            path : Text,
            handler : <system>(Route.RouteContext) -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #patch, #syncUpdate(handler));
        };

        public func patchUpdateAsync(
            path : Text,
            handler : Route.RouteContext -> async* Route.RouteResult,
        ) : RouteBuilder {
            route(path, #patch, #asyncUpdate(handler));
        };

        public func deleteQuery(
            path : Text,
            handler : Route.RouteContext -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #delete, #syncQuery(handler));
        };

        public func deleteUpdate(
            path : Text,
            handler : <system>(Route.RouteContext) -> Route.RouteResult,
        ) : RouteBuilder {
            route(path, #delete, #syncUpdate(handler));
        };

        public func deleteUpdateAsync(
            path : Text,
            handler : Route.RouteContext -> async* Route.RouteResult,
        ) : RouteBuilder {
            route(path, #delete, #asyncUpdate(handler));
        };

        public func route(
            path : Text,
            method : Route.RouteMethod,
            handler : Route.RouteHandler,
        ) : RouteBuilder {
            let pathSegments = switch (Route.parsePathSegments(path)) {
                case (#ok(segments)) segments;
                case (#err(e)) Debug.trap("Failed to parse path " # path # " into segments: " # e);
            };

            routes.add({
                pathSegments = pathSegments;
                method = method;
                handler = handler;
            });
            self;
        };

        public func build() : [Route] {
            Buffer.toArray(routes);
        };

    };

    private func defaultErrorSerializer(error : Error) : SerializedError {
        let errorType = switch (error.statusCode) {
            // 4xx Client Errors
            case (400) "Bad Request";
            case (401) "Unauthorized";
            case (402) "Payment Required";
            case (403) "Forbidden";
            case (404) "Not Found";
            case (405) "Method Not Allowed";
            case (406) "Not Acceptable";
            case (407) "Proxy Authentication Required";
            case (408) "Request Timeout";
            case (409) "Conflict";
            case (410) "Gone";
            case (411) "Length Required";
            case (412) "Precondition Failed";
            case (413) "Payload Too Large";
            case (414) "URI Too Long";
            case (415) "Unsupported Media Type";
            case (416) "Range Not Satisfiable";
            case (417) "Expectation Failed";
            case (418) "I'm a teapot";
            case (421) "Misdirected Request";
            case (422) "Unprocessable Entity";
            case (423) "Locked";
            case (424) "Failed Dependency";
            case (425) "Too Early";
            case (426) "Upgrade Required";
            case (428) "Precondition Required";
            case (429) "Too Many Requests";
            case (431) "Request Header Fields Too Large";
            case (451) "Unavailable For Legal Reasons";

            // 5xx Server Errors
            case (500) "Internal Server Error";
            case (501) "Not Implemented";
            case (502) "Bad Gateway";
            case (503) "Service Unavailable";
            case (504) "Gateway Timeout";
            case (505) "HTTP Version Not Supported";
            case (506) "Variant Also Negotiates";
            case (507) "Insufficient Storage";
            case (508) "Loop Detected";
            case (510) "Not Extended";
            case (511) "Network Authentication Required";

            case (_) "Unknown Error"; // Default case for unknown status codes
        };

        let body = #object_([
            ("error", #string(errorType)),
            ("message", #string(Option.get(error.message, ""))),
            ("status", #number(#int(error.statusCode))),
        ])
        |> Json.stringify(_, null)
        |> Text.encodeUtf8(_);
        {
            body = body;
            headers = [("content-type", "application/json")];
        };
    };

    public func use(
        pipeline : Pipeline.PipelineData,
        data : {
            routes : [Route];
            errorSerializer : ?ErrorSerializer;
            responseHeaders : [ResponseHeader];
        },
    ) : Pipeline.PipelineData {
        let router = Router(
            data.routes,
            Option.get(data.errorSerializer, defaultErrorSerializer),
            data.responseHeaders,
        );
        useRouter(pipeline, router);
    };

    public func useRouter(
        pipeline : Pipeline.PipelineData,
        router : Router,
    ) : Pipeline.PipelineData {

        let middleware : Pipeline.Middleware = {
            handleQuery = ?(
                func(httpContext : HttpContext.HttpContext, next : Pipeline.Next) : ?Types.HttpResponse {
                    switch (router.route(httpContext)) {
                        case (?response) ?response;
                        case (null) next();
                    };
                }
            );
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : Pipeline.NextAsync) : async* ?Types.HttpResponse {
                switch (await* router.routeAsync(httpContext)) {
                    case (?response) ?response;
                    case (null) await* next();
                };
            };
        };

        {
            middleware = Array.append(pipeline.middleware, [middleware]);
        };
    };

    public class Router(
        routes_ : [Route],
        errorSerializer_ : ErrorSerializer,
        responseHeaders_ : [ResponseHeader],
    ) = self {
        let routes = routes_;
        let errorSerializer = errorSerializer_;
        let responseHeaders = responseHeaders_;

        public func route(httpContext : HttpContext.HttpContext) : ?Types.HttpResponse {
            let ?routeContext = findRoute(httpContext) else return null;

            let result = switch (routeContext.handler) {
                case (#syncQuery(handler)) handler(routeContext);
                case (#syncUpdate(_)) return null; // Skip sync handlers that restrict to only updates, only handle in routeAsync
                case (#asyncUpdate(_)) return null; // Skip async handlers, only handle in routeAsync
            };
            handleResult(result);
        };

        public func routeAsync<system>(httpContext : HttpContext.HttpContext) : async* ?Types.HttpResponse {
            let ?routeContext = findRoute(httpContext) else return null;
            let result = switch (routeContext.handler) {
                case (#syncQuery(handler)) handler(routeContext);
                case (#syncUpdate(handler)) handler<system>(routeContext);
                case (#asyncUpdate(handler)) await* handler(routeContext);
            };
            handleResult(result);
        };

        private func findRoute(
            httpContext : HttpContext.HttpContext
        ) : ?Route.RouteContext {
            let path = httpContext.getPath();
            label f for (route in routes.vals()) {
                if (route.method != httpContext.method) continue f;
                let ?{ params } = matchPath(route.pathSegments, path) else continue f;
                return ?Route.RouteContext(
                    httpContext,
                    route.handler,
                    params,
                )

            };
            null;
        };

        private func handleResult(
            result : Route.RouteResult
        ) : ?Types.HttpResponse {

            func serializeError(statusCode : Nat, msg : ?Text) : Types.HttpResponse {
                let error = errorSerializer({
                    message = msg;
                    statusCode = statusCode;
                });
                {
                    statusCode = statusCode;
                    headers = error.headers;
                    body = ?error.body;
                };
            };
            let response : Types.HttpResponse = switch (result) {
                case (#raw(raw)) raw;
                case (#ok(ok)) serializeReponseBody(200, ok);
                case (#created(created)) serializeReponseBody(201, created);
                case (#noContent) ({
                    statusCode = 204;
                    headers = [];
                    body = null;
                });
                case (#notFound(notFound)) serializeError(404, notFound);
                case (#badRequest(msg)) serializeError(400, ?msg);
                case (#unauthorized(msg)) serializeError(401, ?msg);
                case (#forbidden(msg)) serializeError(403, ?msg);
                case (#methodNotAllowed(allowedMethods)) {
                    let allowedMethodsText = allowedMethods.vals()
                    |> Iter.map(_, func(m : Route.RouteMethod) : Text = HttpMethod.toText(m))
                    |> Text.join(", ", _);
                    let msg = "Method not allowed. Allowed methods: " # allowedMethodsText;
                    serializeError(405, ?msg);
                };
                case (#unprocessableEntity(msg)) serializeError(422, ?msg);
                case (#internalServerError(msg)) serializeError(500, ?msg);
                case (#serviceUnavailable(msg)) serializeError(503, ?msg);
            };
            if (responseHeaders.size() <= 0) {
                ?response;
            } else {
                ?{
                    response with
                    headers = Array.append(response.headers, responseHeaders);
                };
            };
        };

        private func serializeReponseBody(statusCode : Nat, body : Route.ResponseBody) : Types.HttpResponse {
            switch (body) {
                case (#custom(custom)) ({
                    statusCode = statusCode;
                    headers = custom.headers;
                    body = ?custom.body;
                });
                case (#json(json)) ({
                    statusCode = statusCode;
                    headers = [("content-type", "application/json")];
                    body = Json.stringify(json, null) |> ?Text.encodeUtf8(_);
                });
                case (#text(text)) ({
                    statusCode = statusCode;
                    headers = [("content-type", "text/plain")];
                    body = ?Text.encodeUtf8(text);
                });
                case (#empty) ({
                    statusCode = statusCode;
                    headers = [];
                    body = null;
                });
            };
        };

        private func matchPath(expected : [Route.PathSegment], actual : [Path.Segment]) : ?{
            params : [(Text, Text)];
        } {
            if (expected.size() != actual.size()) {
                return null;
            };

            let params = Buffer.Buffer<(Text, Text)>(2);
            for ((i, actualSegment) in IterTools.enumerate(actual.vals())) {
                let expectedSegment = expected[i];
                switch (expectedSegment) {
                    case (#text(text)) {
                        if (not TextX.equalIgnoreCase(text, actualSegment)) {
                            return null;
                        };
                    };
                    case (#param(param)) {
                        params.add((param, actualSegment));
                    };
                };
            };
            ?{
                params = Buffer.toArray(params);
            };
        };

    };
};
