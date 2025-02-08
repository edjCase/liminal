import Types "../types";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Nat16 "mo:base/Nat16";
import Option "mo:base/Option";
import Result "mo:base/Result";

module Module {

    public type HttpMethod = {
        #get;
        #post;
    };

    public type HttpRequest = {
        method : HttpMethod;
        url : Text;
        headers : [Types.Header];
        body : Blob;
    };

    public type HttpStatusCode = Nat;

    public type HttpResponse = {
        statusCode : HttpStatusCode;
        headers : [Types.Header];
        body : ?Blob;
    };

    public type HttpContext = {
        path : Text;
        routeParams : [(Text, Text)];
        queryParams : [(Text, Text)];
    };

    public type GetHandler = (HttpContext) -> HttpResponse;
    public type PostHandler = (Blob, HttpContext) -> HttpResponse;

    public type RouteHandler = {
        #get : GetHandler;
        #post : PostHandler;
    };

    public type RouteParameterType = {
        #text;
        #int;
    };

    public type Route = {
        path : Text;
        params : [(Text, RouteParameterType)];
        get : ?GetHandler;
        post : ?PostHandler;
    };

    public type Middleware = {

    };

    public type RouterData = {
        routes : [Route];
        middleware : [Middleware];
    };

    public func empty() : RouterData {
        {
            routes = [];
            middleware = [];
        };
    };

    public func build(data : RouterData) : Router {
        Router(data);
    };

    public func addRoute(data : RouterData, path : Text, handler : RouteHandler) : RouterData {
        let newRoutes =...;
        { data with routes = newRoutes } : RouterData;
    };

    public class Router(routerData : RouterData) = self {
        let routes = routerData.routes;

        public func http_request(req : Types.QueryRequest) : Types.QueryResponse {
            // TODO cache
            {
                status_code = 200;
                headers = [];
                body = Blob.fromArray([]);
                streaming_strategy = null;
                upgrade = ?true;
            };
        };

        public func http_request_update(req : Types.UpdateRequest) : async* Types.UpdateResponse {
            let path = req.url; // TODO: Parse path
            for (middleware in routerData.middleware) {
                // TODO run middleware
            };
            let ?route = routes.get(req.url) else return errorResponse(404);
            let routeParams = []; // TODO: Parse route params
            let queryParams = []; // TODO: Parse query params
            let httpContext = {
                path = path;
                routeParams = routeParams;
                queryParams = queryParams;
            };
            // TODO case insensitive method
            let response : HttpResponse = switch (req.method) {
                case ("GET") {
                    let ?handler = route.get else return errorResponse(404);
                    handler(httpContext);
                };
                case ("POST") {
                    let ?handler = route.post else return errorResponse(404);
                    handler(req.body, httpContext);
                };
                case (_) return errorResponse(405); // TODO?
            };
            {
                status_code = Nat16.fromNat(response.statusCode);
                headers = response.headers;
                body = Option.get(response.body, Blob.fromArray([]));
                streaming_strategy = null;
                upgrade = null;
            };
        };

        private func errorResponse(statusCode : Nat16) : Types.QueryResponse {
            {
                status_code = statusCode;
                headers = [];
                body = Blob.fromArray([]);
                streaming_strategy = null;
                upgrade = null;
            };
        };

    };
};
