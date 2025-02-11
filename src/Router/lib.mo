import Types "../Types";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Pipeline "../Pipeline";
import TextX "mo:xtended-text/TextX";
import HttpContext "../HttpContext";
import HttpMethod "../HttpMethod";
import Route "../Route";
import IterTools "mo:itertools/Iter";

module Module {

    public type RouterData = {
        routes : [Route.Route];
    };

    public func empty() : RouterData {
        {
            routes = [];
        };
    };

    public func get(data : RouterData, path : Text, handler : Route.RouteHandler) : RouterData {
        route(data, path, [#get], handler);
    };

    public func post(data : RouterData, path : Text, handler : Route.RouteHandler) : RouterData {
        route(data, path, [#post], handler);
    };

    public func put(data : RouterData, path : Text, handler : Route.RouteHandler) : RouterData {
        route(data, path, [#put], handler);
    };

    public func delete(data : RouterData, path : Text, handler : Route.RouteHandler) : RouterData {
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

        private func findRoute(httpContext : HttpContext.HttpContext) : ?Route.RouteContext {
            let path = httpContext.getPath();
            label f for (route in routes.vals()) {
                let methodMatch = Array.find(route.methods, func(m : HttpMethod.HttpMethod) : Bool = m == httpContext.method) != null;
                if (not methodMatch) {
                    continue f;
                };
                let ?{ params } = matchPath(route.pathSegments, path) else continue f;
                return ?Route.RouteContext(route, params);
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
