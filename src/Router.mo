import Types "./Types";
import Text "mo:core@1/Text";
import Array "mo:core@1/Array";
import Iter "mo:core@1/Iter";
import List "mo:core@1/List";
import Runtime "mo:core@1/Runtime";
import TextX "mo:xtended-text@2/TextX";
import HttpContext "./HttpContext";
import Route "./Route";
import Path "mo:url-kit@4/Path";
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
  /// let route = Router.get("/users/{id}", #query_(getUserHandler));
  /// ```
  public func get(path : Text, handler : Route.RouteHandler) : RouteConfig {
    route(path, #get, handler);
  };

  /// Creates a POST route configuration with automatic handler type detection.
  ///
  /// ```motoko
  /// let route = Router.post("/users", #update(#async_(createUserHandler)));
  /// ```
  public func post(path : Text, handler : Route.RouteHandler) : RouteConfig {
    route(path, #post, handler);
  };

  /// Creates a PUT route configuration with automatic handler type detection.
  /// The handler type is determined by the RouteHandler variant passed.
  ///
  /// ```motoko
  /// let route = Router.put("/users/{id}", #update(#sync(updateUserHandler)));
  /// ```
  public func put(path : Text, handler : Route.RouteHandler) : RouteConfig {
    route(path, #put, handler);
  };

  /// Creates a PATCH route configuration with automatic handler type detection.
  /// The handler type is determined by the RouteHandler variant passed.
  ///
  /// ```motoko
  /// let route = Router.patch("/users/{id}", #update(#sync(partialUpdateHandler)));
  /// ```
  public func patch(path : Text, handler : Route.RouteHandler) : RouteConfig {
    route(path, #patch, handler);
  };

  /// Creates a DELETE route configuration with automatic handler type detection.
  /// The handler type is determined by the RouteHandler variant passed.
  ///
  /// ```motoko
  /// let route = Router.delete("/users/{id}", #update(#sync(deleteUserHandler)));
  /// ```
  public func delete(path : Text, handler : Route.RouteHandler) : RouteConfig {
    route(path, #delete, handler);
  };

  /// Creates a route configuration with the specified path, method, and handler.
  /// This is the base function used by all HTTP method-specific functions.
  ///
  /// ```motoko
  /// let route = Router.route("/users/{id}", #get, #query_(handler));
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
  ///     #query_(handler),
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
  ///     Router.get("/", #query_(listUsersHandler)),
  ///     Router.post("/", #update(#sync(createUserHandler))),
  ///     Router.get("/{id}", #query_(getUserHandler)),
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
  ///     Router.get("/users", #query_(adminListUsersHandler)),
  ///     Router.delete("/users/{id}", #update(#sync(adminDeleteUserHandler))),
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
  ///         Router.get("/users", #query_(getUsersHandler)),
  ///         Router.get("/users/{id}", #query_(getUserHandler)),
  ///         Router.post("/users", #update(#async_(createUserHandler))),
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
        case (#query_(handler)) handler(routeContext);
        case (#upgradableQuery({ queryHandler })) {
          switch (queryHandler(routeContext)) {
            case (#response(response)) response;
            case (#upgrade) return #upgrade;
          };
        };
        case (#update(_)) return #upgrade; // Skip sync handlers that restrict to only updates, only handle in routeAsync
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

      func handleUpdate(handler : RouteContext.UpdateHandlerKind) : async* Types.HttpResponse {
        switch (handler) {
          case (#sync(handler)) handler(routeContext);
          case (#syncSystem(handler)) handler<system>(routeContext);
          case (#async_(handler)) await* handler(routeContext);
        };
      };

      let response = switch (routeContext.handler) {
        case (#query_(handler)) handler(routeContext); // Could have been upgraded by previous middleware
        case (#upgradableQuery({ updateHandler })) await* handleUpdate(updateHandler);
        case (#update(handler)) await* handleUpdate(handler);
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
        let ?{ params } = matchPath(route.pathSegments, path.segments) else continue f;
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
  /// Supports text segments, parameters ({param}), and wildcards (* and **).
  ///
  /// ```motoko
  /// let pattern = [#text("users"), #param("id")];
  /// let path = ["users", "123"];
  /// let ?{ params } = Router.matchPath(pattern, path) else return null;
  /// // params contains [("id", "123")]
  /// ```
  public func matchPath(expected : [Route.PathSegment], actual : [Text]) : ?{
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
        case (#wildcard(#multi)) Runtime.unreachable(); /* Already handled multi-wildcard */
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
