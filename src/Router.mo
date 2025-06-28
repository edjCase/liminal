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
import Path "mo:url-kit/Path";
import Identity "Identity";
import RouteContext "RouteContext";
import HttpMethod "./HttpMethod";

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

    /// Creates a GET route configuration with automatic handler type detection.
    /// The handler type (query/update/async) is determined by the RouteHandler variant.
    ///
    /// ```motoko
    /// let route = Router.get("/users/:id", #syncQuery(getUserHandler));
    /// ```
    public func get(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #get, handler);
    };

    /// Creates a GET route for query operations (read-only).
    /// Query handlers execute synchronously and cannot modify state.
    ///
    /// ```motoko
    /// let route = Router.getQuery("/users", func(ctx) {
    ///     ctx.buildResponse(#ok, #content(#Text("User list")))
    /// });
    /// ```
    public func getQuery(path : Text, handler : RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #get, #syncQuery(handler));
    };

    /// Creates a GET route for update operations (can modify state).
    /// Update handlers execute synchronously with system access.
    ///
    /// ```motoko
    /// let route = Router.getUpdate("/admin/cache-clear", func(ctx) {
    ///     // Clear cache and return response
    ///     ctx.buildResponse(#ok, #content(#Text("Cache cleared")))
    /// });
    /// ```
    public func getUpdate(path : Text, handler : <system> RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #get, #syncUpdate(handler));
    };

    /// Creates a GET route for asynchronous update operations.
    /// Async handlers can perform inter-canister calls and other async operations.
    ///
    /// ```motoko
    /// let route = Router.getAsyncUpdate("/external-data", func(ctx) : async* Types.HttpResponse {
    ///     let data = await* externalService.getData();
    ///     ctx.buildResponse(#ok, #content(#Text(data)))
    /// });
    /// ```
    public func getAsyncUpdate(path : Text, handler : RouteContext.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #get, #asyncUpdate(handler));
    };

    /// Creates a POST route configuration with automatic handler type detection.
    ///
    /// ```motoko
    /// let route = Router.post("/users", #asyncUpdate(createUserHandler));
    /// ```
    public func post(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #post, handler);
    };

    /// Creates a POST route for query operations.
    /// Useful for complex queries that need request body data.
    ///
    /// ```motoko
    /// let route = Router.postQuery("/search", func(ctx) {
    ///     let searchQuery = ctx.getBodyText();
    ///     // Perform search and return results
    ///     ctx.buildResponse(#ok, #content(#Text(results)))
    /// });
    /// ```
    public func postQuery(path : Text, handler : RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #post, #syncQuery(handler));
    };

    /// Creates a POST route for synchronous update operations.
    /// Ideal for creating resources or modifying state.
    ///
    /// ```motoko
    /// let route = Router.postUpdate("/users", func(ctx) {
    ///     let userData = ctx.getBodyText();
    ///     // Create user and return response
    ///     ctx.buildResponse(#created, #content(#Text("User created")))
    /// });
    /// ```
    public func postUpdate(path : Text, handler : <system> RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #post, #syncUpdate(handler));
    };

    /// Creates a POST route for asynchronous update operations.
    /// Use when creating resources requires external calls or complex async logic.
    ///
    /// ```motoko
    /// let route = Router.postAsyncUpdate("/users", func(ctx) : async* Types.HttpResponse {
    ///     let userData = ctx.getBodyText();
    ///     await* userService.createUser(userData);
    ///     ctx.buildResponse(#created, #content(#Text("User created")))
    /// });
    /// ```
    public func postAsyncUpdate(path : Text, handler : RouteContext.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #post, #asyncUpdate(handler));
    };

    /// Creates a PUT route configuration with automatic handler type detection.
    /// The handler type is determined by the RouteHandler variant passed.
    ///
    /// ```motoko
    /// let route = Router.put("/users/:id", #syncUpdate(updateUserHandler));
    /// ```
    public func put(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #put, handler);
    };

    /// Creates a PUT route for query operations.
    /// Use for idempotent operations that don't modify state.
    ///
    /// ```motoko
    /// let route = Router.putQuery("/users/:id/validate", func(ctx) {
    ///     // Validate user data without modification
    ///     ctx.buildResponse(#ok, #content(#Text("Valid")))
    /// });
    /// ```
    public func putQuery(path : Text, handler : RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #put, #syncQuery(handler));
    };

    /// Creates a PUT route for synchronous update operations.
    /// Ideal for updating or replacing resources entirely.
    ///
    /// ```motoko
    /// let route = Router.putUpdate("/users/:id", func(ctx) {
    ///     let userId = ctx.getRouteParam("id");
    ///     // Update user and return response
    ///     ctx.buildResponse(#ok, #content(#Text("User updated")))
    /// });
    /// ```
    public func putUpdate(path : Text, handler : <system> RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #put, #syncUpdate(handler));
    };

    /// Creates a PUT route for asynchronous update operations.
    /// Use when updating resources requires external calls or complex async logic.
    ///
    /// ```motoko
    /// let route = Router.putAsyncUpdate("/users/:id", func(ctx) : async* Types.HttpResponse {
    ///     let userId = ctx.getRouteParam("id");
    ///     await* userService.updateUser(userId, userData);
    ///     ctx.buildResponse(#ok, #content(#Text("User updated")))
    /// });
    /// ```
    public func putAsyncUpdate(path : Text, handler : RouteContext.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #put, #asyncUpdate(handler));
    };

    /// Creates a PATCH route configuration with automatic handler type detection.
    /// The handler type is determined by the RouteHandler variant passed.
    ///
    /// ```motoko
    /// let route = Router.patch("/users/:id", #syncUpdate(partialUpdateHandler));
    /// ```
    public func patch(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #patch, handler);
    };

    /// Creates a PATCH route for query operations.
    /// Use for validation or preview of partial updates without modification.
    ///
    /// ```motoko
    /// let route = Router.patchQuery("/users/:id/preview", func(ctx) {
    ///     // Preview what the patch would do
    ///     ctx.buildResponse(#ok, #content(#Text("Preview")))
    /// });
    /// ```
    public func patchQuery(path : Text, handler : RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #patch, #syncQuery(handler));
    };

    /// Creates a PATCH route for synchronous update operations.
    /// Ideal for partial updates to existing resources.
    ///
    /// ```motoko
    /// let route = Router.patchUpdate("/users/:id", func(ctx) {
    ///     let userId = ctx.getRouteParam("id");
    ///     // Apply partial update and return response
    ///     ctx.buildResponse(#ok, #content(#Text("User partially updated")))
    /// });
    /// ```
    public func patchUpdate(path : Text, handler : <system> RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #patch, #syncUpdate(handler));
    };

    /// Creates a PATCH route for asynchronous update operations.
    /// Use when partial updates require external calls or complex async logic.
    ///
    /// ```motoko
    /// let route = Router.patchAsyncUpdate("/users/:id", func(ctx) : async* Types.HttpResponse {
    ///     let userId = ctx.getRouteParam("id");
    ///     await* userService.partialUpdateUser(userId, patchData);
    ///     ctx.buildResponse(#ok, #content(#Text("User partially updated")))
    /// });
    /// ```
    public func patchAsyncUpdate(path : Text, handler : RouteContext.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #patch, #asyncUpdate(handler));
    };

    /// Creates a DELETE route configuration with automatic handler type detection.
    /// The handler type is determined by the RouteHandler variant passed.
    ///
    /// ```motoko
    /// let route = Router.delete("/users/:id", #syncUpdate(deleteUserHandler));
    /// ```
    public func delete(path : Text, handler : Route.RouteHandler) : RouteConfig {
        route(path, #delete, handler);
    };

    /// Creates a DELETE route for query operations.
    /// Use for previewing what would be deleted without actually deleting.
    ///
    /// ```motoko
    /// let route = Router.deleteQuery("/users/:id/preview", func(ctx) {
    ///     // Show what would be deleted
    ///     ctx.buildResponse(#ok, #content(#Text("Would delete user")))
    /// });
    /// ```
    public func deleteQuery(path : Text, handler : RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #delete, #syncQuery(handler));
    };

    /// Creates a DELETE route for synchronous update operations.
    /// Standard approach for deleting resources.
    ///
    /// ```motoko
    /// let route = Router.deleteUpdate("/users/:id", func(ctx) {
    ///     let userId = ctx.getRouteParam("id");
    ///     // Delete user and return response
    ///     ctx.buildResponse(#noContent, #empty)
    /// });
    /// ```
    public func deleteUpdate(path : Text, handler : <system> RouteContext.RouteContext -> Types.HttpResponse) : RouteConfig {
        route(path, #delete, #syncUpdate(handler));
    };

    /// Creates a DELETE route for asynchronous update operations.
    /// Use when deleting resources requires external calls or complex async logic.
    ///
    /// ```motoko
    /// let route = Router.deleteAsyncUpdate("/users/:id", func(ctx) : async* Types.HttpResponse {
    ///     let userId = ctx.getRouteParam("id");
    ///     await* userService.deleteUser(userId);
    ///     ctx.buildResponse(#noContent, #empty)
    /// });
    /// ```
    public func deleteAsyncUpdate(path : Text, handler : RouteContext.RouteContext -> async* Types.HttpResponse) : RouteConfig {
        route(path, #delete, #asyncUpdate(handler));
    };

    /// Creates a route configuration with the specified path, method, and handler.
    /// This is the base function used by all HTTP method-specific functions.
    ///
    /// ```motoko
    /// let route = Router.route("/users/:id", #get, #syncQuery(handler));
    /// ```
    public func route(path : Text, method : Route.RouteMethod, handler : Route.RouteHandler) : RouteConfig {
        routeWithOptAuthorization(
            path,
            method,
            handler,
            null, // No identity requirement
        );
    };

    /// Creates a route configuration with identity/authorization requirements.
    /// The route will only match if the request meets the identity requirements.
    ///
    /// ```motoko
    /// let authRoute = Router.routeWithAuthorization(
    ///     "/admin/users",
    ///     #get,
    ///     #syncQuery(handler),
    ///     { kind = #principalIdAllowList; principalIds = ["admin-principal"] }
    /// );
    /// ```
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

    /// Groups multiple routes under a common path prefix.
    /// Useful for organizing related routes and applying common configuration.
    ///
    /// ```motoko
    /// let userRoutes = Router.group("/users", [
    ///     Router.getQuery("/", listUsersHandler),
    ///     Router.postUpdate("/", createUserHandler),
    ///     Router.getQuery("/:id", getUserHandler),
    /// ]);
    /// ```
    public func group(prefix : Text, routes : [RouteConfig]) : RouteConfig {
        groupWithOptAuthorization(
            prefix,
            routes,
            null, // No identity requirement
        );
    };

    /// Groups multiple routes under a common path prefix with identity requirements.
    /// All routes in the group will inherit the identity requirements.
    ///
    /// ```motoko
    /// let adminRoutes = Router.groupWithAuthorization("/admin", [
    ///     Router.getQuery("/users", adminListUsersHandler),
    ///     Router.deleteUpdate("/users/:id", adminDeleteUserHandler),
    /// ], { kind = #principalIdAllowList; principalIds = ["admin-principal"] });
    /// ```
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

    /// HTTP router class that handles route matching and dispatching for web applications.
    /// Processes HTTP requests by matching them against configured routes and executing handlers.
    /// Supports path parameters, route groups, prefix matching, and various handler types.
    ///
    /// ```motoko
    /// let config = {
    ///     routes = [
    ///         Router.get("/users", #syncQuery(getUsersHandler)),
    ///         Router.get("/users/{id}", #syncQuery(getUserHandler)),
    ///         Router.post("/users", #asyncUpdate(createUserHandler)),
    ///         Router.group({
    ///             prefix = [#text("api"), #text("v1")];
    ///             routes = [/* nested routes */];
    ///             identityRequirement = ?#authenticated;
    ///         }),
    ///     ];
    ///     identityRequirement = null; // No global auth requirement
    ///     prefix = ?"/api"; // Global prefix for all routes
    /// };
    ///
    /// let router = Router.Router(config);
    ///
    /// // In middleware
    /// switch (router.routeQuery(httpContext)) {
    ///     case (#response(response)) response;
    ///     case (#noMatch) { /* handle no match */ };
    ///     case (#upgrade) { /* upgrade to update call */ };
    /// };
    /// ```
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

        /// Routes an HTTP query request (read-only operation) to the appropriate handler.
        /// Returns response directly for query handlers, or upgrade directive for update handlers.
        /// Query operations cannot modify state and execute synchronously.
        ///
        /// ```motoko
        /// let result = router.routeQuery(httpContext);
        /// switch (result) {
        ///     case (#response(response)) response;
        ///     case (#upgrade) // Route requires update call
        ///     case (#noMatch) // No matching route found
        /// };
        /// ```
        public func routeQuery(httpContext : HttpContext.HttpContext) : SyncRouteResult {
            let ?routeContext = findRoute(httpContext) else return #noMatch;

            let response = switch (routeContext.handler) {
                case (#syncQuery(handler)) handler(routeContext);
                case (#syncUpdate(_)) return #upgrade; // Skip sync handlers that restrict to only updates, only handle in routeAsync
                case (#asyncUpdate(_)) return #upgrade; // Skip async handlers, only handle in routeAsync
            };
            #response(response);
        };

        /// Routes an HTTP update request (state-changing operation) to the appropriate handler.
        /// Handles all handler types including query, sync update, and async update handlers.
        /// Update operations can modify state and support async execution.
        ///
        /// ```motoko
        /// let result = await* router.routeUpdate(httpContext);
        /// switch (result) {
        ///     case (#response(response)) response;
        ///     case (#noMatch) // No matching route found
        /// };
        /// ```
        public func routeUpdate<system>(httpContext : HttpContext.HttpContext) : async* AsyncRouteResult {
            let ?routeContext = findRoute(httpContext) else return #noMatch;
            let response = switch (routeContext.handler) {
                case (#syncQuery(handler)) handler(routeContext); // Could have been upgraded by previous middleware
                case (#syncUpdate(handler)) handler<system>(routeContext);
                case (#asyncUpdate(handler)) await* handler(routeContext);
            };
            #response(response);
        };

        private func findRoute(
            httpContext : HttpContext.HttpContext
        ) : ?RouteContext.RouteContext {
            let path = httpContext.getPath();
            httpContext.log(#verbose, "Finding route for path: '" # Path.toText(path) # "' with method " # HttpMethod.toText(httpContext.method));
            label f for (route in routes.vals()) {
                httpContext.log(#verbose, "Attempting to match to route " # debug_show (route.pathSegments) # " with method " # HttpMethod.toText(route.method));
                if (route.method != httpContext.method) continue f;
                let ?{ params } = matchPath(route.pathSegments, path) else continue f;
                httpContext.log(#debug_, "Route successfully matched. Path: " # debug_show (route.pathSegments) # ", Method: " # HttpMethod.toText(route.method));
                return ?RouteContext.RouteContext(
                    httpContext,
                    route.handler,
                    params,
                )

            };
            null;
        };

    };

    /// Matches a URL path against a route pattern and extracts path parameters.
    /// Returns extracted parameters if the path matches the pattern, null otherwise.
    /// Supports text segments, parameters (:param), and wildcards (* and **).
    ///
    /// ```motoko
    /// let pattern = [#text("users"), #param("id")];
    /// let path = ["users", "123"];
    /// let ?{ params } = Router.matchPath(pattern, path) else return null;
    /// // params contains [("id", "123")]
    /// ```
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

        if (expected.size() == 0 and actual.size() == 0) {
            // Special case: both empty means a match with no params
            return ?{
                params = [];
            };
        };

        // Start the recursive matching
        return matchRecursive(0, 0, List.empty<(Text, Text)>());
    };

};
