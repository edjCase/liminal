import Types "../Types";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Pipeline "../Pipeline";
import TextX "mo:xtended-text/TextX";
import HttpContext "../HttpContext";
import HttpMethod "../HttpMethod";

module Module {

    public class RouteContext(route_ : Route, params_ : [(Text, RouteParameterValue)]) = self {
        public let route : Route = route_;
        public let params : [(Text, RouteParameterValue)] = params_;

        public func getParam(key : Text) : ?RouteParameterValue {
            let ?kv = Array.find(
                params,
                func(kv : (Text, RouteParameterValue)) : Bool = TextX.equalIgnoreCase(kv.0, key),
            ) else return null;
            ?kv.1;
        };

        public func run(httpContext : HttpContext.HttpContext) : Types.HttpResponse {
            route.handler(httpContext, self);
        };
    };

    public type RouteHandler = (HttpContext.HttpContext, RouteContext) -> Types.HttpResponse;

    public type RouteParameterValue = {
        #text : Text;
        #int : Int;
    };

    public type RouteParameterType = {
        #text;
        #int;
    };

    public type Route = {
        path : Text;
        params : [(Text, RouteParameterType)];
        methods : [HttpMethod.HttpMethod];
        handler : RouteHandler;
    };

    public type RouterData = {
        routes : [Route];
    };

    public func empty() : RouterData {
        {
            routes = [];
        };
    };

    public func get(data : RouterData, path : Text, handler : RouteHandler) : RouterData {
        route(data, path, [#get], handler);
    };

    public func post(data : RouterData, path : Text, handler : RouteHandler) : RouterData {
        route(data, path, [#post], handler);
    };

    public func put(data : RouterData, path : Text, handler : RouteHandler) : RouterData {
        route(data, path, [#put], handler);
    };

    public func delete(data : RouterData, path : Text, handler : RouteHandler) : RouterData {
        route(data, path, [#delete], handler);
    };

    public func route(
        data : RouterData,
        path : Text,
        methods : [HttpMethod.HttpMethod],
        handler : RouteHandler,
    ) : RouterData {
        let route = {
            path = path;
            params = [];
            methods = methods;
            handler = handler;
        };

        {
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

            ?routeContext.run(httpContext);
        };

        private func findRoute(httpContext : HttpContext.HttpContext) : ?RouteContext {
            // TODO this is placeholder

            let path = httpContext.getPath();
            let ?route = routes
            |> Array.find(
                _,
                func(route : Route) : Bool = TextX.equalIgnoreCase(route.path, path) and Array.find(route.methods, func(m : HttpMethod.HttpMethod) : Bool = m == httpContext.method) != null,
            ) else return null;

            ?RouteContext(route, []);
        };

    };
};
