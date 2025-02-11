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

    public func defaultJsonRouter() : RouterData {

        {
            routes = [];
            errorSerializer = func(error : Error) : Blob {
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
            responseHeaders = [("Content-Type", "application/json")];
        };
    };

    public func withResponseHeaders(data : RouterData, headers : [(Text, Text)]) : RouterData {
        {
            data with
            responseHeaders = headers;
        };
    };

    public func withErrorSerializer(data : RouterData, serializer : (Error) -> Blob) : RouterData {
        {
            data with
            errorSerializer = serializer;
        };
    };

    public func get(
        data : RouterData,
        path : Text,
        handler : Route.RouteHandler,
    ) : RouterData {
        route(data, path, [#get], handler);
    };

    public func post(
        data : RouterData,
        path : Text,
        handler : Route.RouteHandler,
    ) : RouterData {
        route(data, path, [#post], handler);
    };

    public func put(
        data : RouterData,
        path : Text,
        handler : Route.RouteHandler,
    ) : RouterData {
        route(data, path, [#put], handler);
    };

    public func delete(
        data : RouterData,
        path : Text,
        handler : Route.RouteHandler,
    ) : RouterData {
        route(data, path, [#delete], handler);
    };

    public func route(
        data : RouterData,
        path : Text,
        methods : [HttpMethod.HttpMethod],
        handler : Route.RouteHandler,
    ) : RouterData {
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

        {
            data with
            routes = Array.append(data.routes, [route]);
        };
    };

    public func build(data : RouterData) : Router {
        Router(data);
    };

    public func use(pipeline : Pipeline.PipelineData, router : Router) : Pipeline.PipelineData {
        let middleware = {
            handle = func(httpContext : HttpContext.HttpContext, next : Pipeline.Next) : Types.HttpResponse {
                let ?response = router.route(httpContext) else return next();
                response;
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

            func serializeError(statusCode : Nat, msg : ?Text) : (Nat, ?Blob) {
                let error = routerData.errorSerializer({
                    message = msg;
                    statusCode = statusCode;
                });
                (statusCode, ?error);
            };
            let (statusCode, body) : (Nat, ?Blob) = switch (routeContext.route.handler(routeContext)) {
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

        private func matchPath(segments : [Route.PathSegment], requestPath : Text) : ?{
            params : [(Text, Text)];
        } {
            let requestPathSegments = Text.split(requestPath, #char('/')) |> Iter.toArray(_);
            if (segments.size() != requestPathSegments.size()) {
                return null;
            };

            let params = Buffer.Buffer<(Text, Text)>(2);
            for ((i, segment) in IterTools.enumerate(segments.vals())) {
                let segment = segments[i];
                let requestSegment = requestPathSegments[i];
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
