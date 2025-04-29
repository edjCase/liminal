import Types "./Types";
import Text "mo:new-base/Text";
import Array "mo:new-base/Array";
import Iter "mo:new-base/Iter";
import List "mo:new-base/List";
import Runtime "mo:new-base/Runtime";
import TextX "mo:xtended-text/TextX";
import HttpContext "./HttpContext";
import Route "./Route";
import Prelude "mo:base/Prelude";
import Path "./Path";
import Identity "Identity";

module Module {

    public type SerializedError = {
        body : Blob;
        headers : [(Text, Text)];
    };

    public type ResponseHeader = (Text, Text);

    public type Config = {
        routes : [RouteConfig];
        identityRequirement : ?Identity.IdentityRequirement;
        prefix : ?Text;
    };

    public type RouteConfig = {
        #route : Route.Route;
        #group : {
            prefix : [Route.PathSegment];
            routes : [RouteConfig];
            identityRequirement : ?Identity.IdentityRequirement;
        };
    };

    public type AsyncRouteResult = {
        #response : Types.HttpResponse;
        #noMatch;
    };

    public type SyncRouteResult = AsyncRouteResult or {
        #upgrade;
    };

    public func get(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #get, handler);
    };

    public func getQuery(path : Text, handler : Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #get, #syncQuery(handler));
    };

    public func getUpdate(path : Text, handler : <system> Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #get, #syncUpdate(handler));
    };

    public func getAsyncUpdate(path : Text, handler : Route.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #get, #asyncUpdate(handler));
    };

    public func post(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #post, handler);
    };

    public func postQuery(path : Text, handler : Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #post, #syncQuery(handler));
    };

    public func postUpdate(path : Text, handler : <system> Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #post, #syncUpdate(handler));
    };

    public func postAsyncUpdate(path : Text, handler : Route.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #post, #asyncUpdate(handler));
    };

    public func put(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #put, handler);
    };

    public func putQuery(path : Text, handler : Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #put, #syncQuery(handler));
    };

    public func putUpdate(path : Text, handler : <system> Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #put, #syncUpdate(handler));
    };

    public func putAsyncUpdate(path : Text, handler : Route.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #put, #asyncUpdate(handler));
    };

    public func patch(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #patch, handler);
    };

    public func patchQuery(path : Text, handler : Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #patch, #syncQuery(handler));
    };

    public func patchUpdate(path : Text, handler : <system> Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #patch, #syncUpdate(handler));
    };

    public func patchAsyncUpdate(path : Text, handler : Route.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #patch, #asyncUpdate(handler));
    };

    public func delete(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #delete, handler);
    };

    public func deleteQuery(path : Text, handler : Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #delete, #syncQuery(handler));
    };

    public func deleteUpdate(path : Text, handler : <system> Route.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #delete, #syncUpdate(handler));
    };

    public func deleteAsyncUpdate(path : Text, handler : Route.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #delete, #asyncUpdate(handler));
    };

    public func route(path : Text, method : Route.RouteMethod, handler : Route.RouteHandler) : RouteConfig {
        routeWithOptAuthorization(
            path,
            method,
            handler,
            null, // No identity requirement
        );
    };

    public func routeWithAuthorization(
        path : Text,
        method : Route.RouteMethod,
        handler : Route.RouteHandler,
        identityRequirement : Identity.IdentityRequirement,
    ) : RouteConfig {
        routeWithOptAuthorization(
            path,
            method,
            handler,
            ?identityRequirement,
        );
    };

    private func routeWithOptAuthorization(
        path : Text,
        method : Route.RouteMethod,
        handler : Route.RouteHandler,
        identityRequirement : ?Identity.IdentityRequirement,
    ) : RouteConfig {
        let pathSegments = switch (Route.parsePathSegments(path)) {
            case (#ok(segments)) segments;
            case (#err(e)) Runtime.trap("Failed to parse path '" # path # "' into segments: " # e);
        };
        #route({
            pathSegments = pathSegments;
            method = method;
            handler = handler;
            identityRequirement = identityRequirement;
        });
    };

    public func group(prefix : Text, routes : [RouteConfig]) : RouteConfig {
        groupWithOptAuthorization(
            prefix,
            routes,
            null, // No identity requirement
        );
    };

    public func groupWithAuthorization(
        prefix : Text,
        routes : [RouteConfig],
        identityRequirement : Identity.IdentityRequirement,
    ) : RouteConfig {
        groupWithOptAuthorization(
            prefix,
            routes,
            ?identityRequirement,
        );
    };

    private func groupWithOptAuthorization(
        prefix : Text,
        routes : [RouteConfig],
        identityRequirement : ?Identity.IdentityRequirement,
    ) : RouteConfig {
        let pathSegments = switch (Route.parsePathSegments(prefix)) {
            case (#ok(segments)) segments;
            case (#err(e)) Runtime.trap("Failed to parse path prefix '" # prefix # "' into segments: " # e);
        };
        #group({
            prefix = pathSegments;
            routes = routes;
            identityRequirement = identityRequirement;
        });
    };

    private func buildRoutesFromConfig(config : RouteConfig, prefix : ?[Route.PathSegment]) : Iter.Iter<Route.Route> {
        switch (config) {
            case (#route(route)) {
                let r = switch (prefix) {
                    case (?prefix) ({
                        route with
                        pathSegments = Array.concat(prefix, route.pathSegments);
                    });
                    case (null) route;
                };
                Iter.singleton(r);
            };
            case (#group(group)) {
                let groupPrefix = switch (prefix) {
                    case (?prefix) Array.concat(prefix, group.prefix);
                    case (null) group.prefix;
                };
                Array.flatMap(
                    group.routes,
                    func(config : RouteConfig) : Iter.Iter<Route.Route> = buildRoutesFromConfig(config, ?groupPrefix),
                ).vals();
            };
        };
    };

    public class Router(config : Config) = self {
        let prefix = switch (config.prefix) {
            case (?prefix) ?(
                switch (Route.parsePathSegments(prefix)) {
                    case (#ok(segments)) segments;
                    case (#err(e)) Runtime.trap("Failed to parse prefix '" # prefix # "' into segments: " # e);
                }
            );
            case (null) null;
        };
        let routes = Array.flatMap(
            config.routes,
            func(routeConfig : RouteConfig) : Iter.Iter<Route.Route> = buildRoutesFromConfig(routeConfig, prefix),
        );

        public func route(httpContext : HttpContext.HttpContext) : SyncRouteResult {
            let ?routeContext = findRoute(httpContext) else return #noMatch;

            let response = switch (routeContext.handler) {
                case (#syncQuery(handler)) handler(routeContext);
                case (#syncUpdate(_)) return #upgrade; // Skip sync handlers that restrict to only updates, only handle in routeAsync
                case (#asyncUpdate(_)) return #upgrade; // Skip async handlers, only handle in routeAsync
            };
            #response(response);
        };

        public func routeAsync<system>(httpContext : HttpContext.HttpContext) : async* AsyncRouteResult {
            let ?routeContext = findRoute(httpContext) else return #noMatch;
            let response = switch (routeContext.handler) {
                case (#syncQuery(_)) return #noMatch; // Upgraded already, so skip query handlers
                case (#syncUpdate(handler)) handler<system>(routeContext);
                case (#asyncUpdate(handler)) await* handler(routeContext);
            };
            #response(response);
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

    };

    public func matchPath(expected : [Route.PathSegment], actual : [Path.Segment]) : ?{
        params : [(Text, Text)];
    } {
        func matchRecursive(expIndex : Nat, actIndex : Nat, currentParams : List.List<(Text, Text)>) : ?{
            params : [(Text, Text)];
        } {
            // Base case: if we've processed all expected segments
            if (expIndex >= expected.size()) {
                // Only a match if we've also processed all actual segments
                return if (actIndex >= actual.size()) ?{
                    params = List.toArray(currentParams);
                } else null;
            };

            // Get current expected segment
            let expectedSegment = expected[expIndex];

            // Handle multi-wildcard case
            if (expectedSegment == #wildcard(#multi)) {
                // Try matching with the wildcard consuming 0 segments
                let matchWithoutConsumingAny = matchRecursive(expIndex + 1, actIndex, currentParams);
                if (matchWithoutConsumingAny != null) return matchWithoutConsumingAny;

                // If we still have actual segments left, try matching with wildcard consuming 1 more segment
                if (actIndex < actual.size()) {
                    return matchRecursive(expIndex, actIndex + 1, currentParams);
                };

                return null;
            };

            // If no more actual segments but we still have expected segments (that aren't multi-wildcards)
            if (actIndex >= actual.size()) {
                return null;
            };

            // Get current actual segment
            let actualSegment = actual[actIndex];

            // Handle other segment types
            switch (expectedSegment) {
                case (#text(text)) {
                    if (not TextX.equalIgnoreCase(text, actualSegment)) {
                        return null;
                    };
                    return matchRecursive(expIndex + 1, actIndex + 1, currentParams);
                };
                case (#param(param)) {
                    List.add(currentParams, (param, actualSegment));
                    return matchRecursive(expIndex + 1, actIndex + 1, currentParams);
                };
                case (#wildcard(#single)) {
                    // Single wildcard always matches one segment
                    return matchRecursive(expIndex + 1, actIndex + 1, currentParams);
                };
                case (#wildcard(#multi)) Prelude.unreachable(); /* Already handled multi-wildcard */
            };

            return null;
        };

        // Start the recursive matching
        return matchRecursive(0, 0, List.empty<(Text, Text)>());
    };

};
