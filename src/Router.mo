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
    public type RouterData = {
        routes : [Route.Route];
        errorSerializer : (Error) -> Blob;
        responseHeaders : [(Text, Text)];
    };

    public class RouterBuilder() = self {
        let routes = Buffer.Buffer<Route.Route>(2);
        let responseHeaders = Buffer.Buffer<(Text, Text)>(2);
        var errorSerializer : ?((Error) -> Blob) = null;

        public func withErrorSerializer(handler : (Error) -> Blob) : RouterBuilder {
            errorSerializer := ?handler;
            self;
        };

        public func addResponseHeader(header : (Text, Text)) : RouterBuilder {
            responseHeaders.add(header);
            self;
        };

        public func getQuery(
            path : Text,
            handler : (Route.RouteContext) -> Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#get], #syncQuery(handler));
        };

        public func getUpdate(
            path : Text,
            handler : <system>(Route.RouteContext) -> Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#get], #syncUpdate(handler));
        };

        public func getUpdateAsync(
            path : Text,
            handler : Route.RouteContext -> async* Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#get], #asyncUpdate(handler));
        };

        public func postQuery(
            path : Text,
            handler : Route.RouteContext -> Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#post], #syncQuery(handler));
        };

        public func postUpdate(
            path : Text,
            handler : <system>(Route.RouteContext) -> Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#post], #syncUpdate(handler));
        };

        public func postUpdateAsync(
            path : Text,
            handler : Route.RouteContext -> async* Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#post], #asyncUpdate(handler));
        };

        public func putQuery(
            path : Text,
            handler : Route.RouteContext -> Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#put], #syncQuery(handler));
        };

        public func putUpdate(
            path : Text,
            handler : <system>(Route.RouteContext) -> Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#put], #syncUpdate(handler));
        };

        public func putUpdateAsync(
            path : Text,
            handler : Route.RouteContext -> async* Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#put], #asyncUpdate(handler));
        };

        public func deleteQuery(
            path : Text,
            handler : Route.RouteContext -> Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#delete], #syncQuery(handler));
        };

        public func deleteUpdate(
            path : Text,
            handler : <system>(Route.RouteContext) -> Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#delete], #syncUpdate(handler));
        };

        public func deleteUpdateAsync(
            path : Text,
            handler : Route.RouteContext -> async* Route.RouteResult,
        ) : RouterBuilder {
            route(path, [#delete], #asyncUpdate(handler));
        };

        public func route(
            path : Text,
            methods : [HttpMethod.HttpMethod],
            handler : Route.RouteHandler,
        ) : RouterBuilder {
            let pathSegments = switch (Route.parsePathSegments(path)) {
                case (#ok(segments)) segments;
                case (#err(e)) Debug.trap("Failed to parse path " # path # " into segments: " # e);
            };
            let route : Route.Route = {
                pathSegments = pathSegments;
                params = [];
                methods = methods;
                handler = handler;
            };
            routes.add(route);
            self;
        };

        public func build() : Router {
            Router({
                routes = Buffer.toArray(routes);
                errorSerializer = Option.get(errorSerializer, defaultErrorSerializer);
                responseHeaders = Buffer.toArray(responseHeaders);
            });
        };

    };

    private func defaultErrorSerializer(error : Error) : Blob {
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

        #object_([
            ("error", #string(errorType)),
            ("message", #string(Option.get(error.message, ""))),
            ("status", #number(#int(error.statusCode))),
        ])
        |> Json.stringify(_, null)
        |> Text.encodeUtf8(_);
    };

    public func use(pipeline : Pipeline.PipelineData, router : Router) : Pipeline.PipelineData {
        let middleware : Pipeline.Middleware = {
            handleQuery = ?(
                func(httpContext : HttpContext.HttpContext, next : Pipeline.Next) : ?Types.HttpResponse {
                    let ?response = router.route(httpContext) else return next();
                    ?response;
                }
            );
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : Pipeline.NextAsync) : async* ?Types.HttpResponse {
                let ?response = await* router.routeAsync(httpContext) else return await* next();
                ?response;
            };
        };

        {
            middleware = Array.append(pipeline.middleware, [middleware]);
        };
    };

    public class Router(routerData : RouterData) = self {
        let routes = routerData.routes;

        public func route(httpContext : HttpContext.HttpContext) : ?Types.HttpResponse {
            let ?routeContext = findRoute(httpContext) else return null;

            let result = switch (routeContext.route.handler) {
                case (#syncQuery(handler)) handler(routeContext);
                case (#syncUpdate(_)) return null; // Skip sync handlers that restrict to only updates, only handle in routeAsync
                case (#asyncUpdate(_)) return null; // Skip async handlers, only handle in routeAsync
            };
            handleResult(result);
        };

        public func routeAsync<system>(httpContext : HttpContext.HttpContext) : async* ?Types.HttpResponse {
            let ?routeContext = findRoute(httpContext) else return null;

            let result = switch (routeContext.route.handler) {
                case (#syncQuery(handler)) handler(routeContext);
                case (#syncUpdate(handler)) handler<system>(routeContext);
                case (#asyncUpdate(handler)) await* handler(routeContext);
            };
            handleResult(result);
        };

        private func handleResult(
            result : Route.RouteResult
        ) : ?Types.HttpResponse {

            func serializeError(statusCode : Nat, msg : ?Text) : (Nat, ?Blob) {
                let error = routerData.errorSerializer({
                    message = msg;
                    statusCode = statusCode;
                });
                (statusCode, ?error);
            };
            let (statusCode, body) : (Nat, ?Blob) = switch (result) {
                case (#raw(raw)) {
                    return ?{
                        raw with
                        headers = Array.append(raw.headers, routerData.responseHeaders); // Add response headers
                    };
                };
                case (#ok(ok)) (200, ?serializeReponseBody(ok));
                case (#created(created)) (201, ?serializeReponseBody(created));
                case (#noContent) (204, null);
                case (#notFound(notFound)) serializeError(404, notFound);
                case (#badRequest(msg)) serializeError(400, ?msg);
                case (#unauthorized(msg)) serializeError(401, ?msg);
                case (#forbidden(msg)) serializeError(403, ?msg);
                case (#methodNotAllowed(allowedMethods)) {
                    let allowedMethodsText = allowedMethods.vals()
                    |> Iter.map(_, func(m : HttpMethod.HttpMethod) : Text = HttpMethod.toText(m))
                    |> Text.join(", ", _);
                    let msg = "Method not allowed. Allowed methods: " # allowedMethodsText;
                    serializeError(405, ?msg);
                };
                case (#unprocessableEntity(msg)) serializeError(422, ?msg);
                case (#internalServerError(msg)) serializeError(500, ?msg);
                case (#serviceUnavailable(msg)) serializeError(503, ?msg);
            };
            ?{
                statusCode = statusCode;
                headers = routerData.responseHeaders;
                body = body;
            };
        };

        private func serializeReponseBody(body : Route.ResponseBody) : Blob {
            switch (body) {
                case (#raw(blob)) blob;
                case (#json(json)) Json.stringify(json, null) |> Text.encodeUtf8(_);
            };
        };

        private func findRoute(httpContext : HttpContext.HttpContext) : ?Route.RouteContext {
            let path = httpContext.getPath();
            label f for (route in routes.vals()) {
                let methodMatch = Array.find(route.methods, func(m : HttpMethod.HttpMethod) : Bool = m == httpContext.method) != null;
                if (not methodMatch) {
                    continue f;
                };
                let ?{ params } = matchPath(route.pathSegments, path) else continue f;
                return ?Route.RouteContext(
                    httpContext,
                    route,
                    params,
                );
            };
            null;
        };

        private func matchPath(segments : [Route.PathSegment], requestPath : [Path.Segment]) : ?{
            params : [(Text, Text)];
        } {
            if (segments.size() != requestPath.size()) {
                return null;
            };

            let params = Buffer.Buffer<(Text, Text)>(2);
            for ((i, segment) in IterTools.enumerate(segments.vals())) {
                let segment = segments[i];
                let requestSegment = requestPath[i];
                switch (segment) {
                    case (#text(s)) {
                        if (not TextX.equalIgnoreCase(s, requestSegment)) {
                            return null;
                        };
                    };
                    case (#param(p)) {
                        params.add((p, requestSegment));
                    };
                };
            };
            ?{ params = Buffer.toArray(params) };
        };

    };
};
