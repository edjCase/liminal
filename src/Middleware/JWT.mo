import JWT "mo:jwt";
import App "../App";
import HttpContext "../HttpContext";
import Debug "mo:new-base/Debug";
import Text "mo:new-base/Text";

module {
    public type ValidationOptions = JWT.ValidationOptions;
    public type JWTLocation = {
        #header : Text; // Authorization: Bearer <token>
        #cookie : Text; // Cookie name
        #queryString : Text; // Query param name
    };

    public type Options = {
        validation : ValidationOptions;
        locations : [JWTLocation]; // Priority order for token extraction
    };

    public let defaultLocations : [JWTLocation] = [
        #header("Authorization"),
        #cookie("jwt"),
        #queryString("token"),
    ];

    /// Creates a new JWT authentication middleware
    /// Extracts and validates JWT tokens from requests, making them available in the HttpContext
    /// - Parameter options: JWT options including validation settings and token locations
    /// - Returns: A middleware that processes JWT tokens from requests
    public func new(options : Options) : App.Middleware {
        {
            name = "JWT";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                tryParseAndSetJWT(context, options.validation, options.locations);
                next();
            };
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                tryParseAndSetJWT(context, options.validation, options.locations);
                await* next();
            };
        };
    };

    private func tryParseAndSetJWT(
        context : HttpContext.HttpContext,
        validation : JWT.ValidationOptions,
        locations : [JWTLocation],
    ) {
        // 1. Extract JWT from request
        let ?jwtText = extractJWT(context, locations) else return;

        // 2. Parse JWT
        let jwt = switch (JWT.parse(jwtText)) {
            case (#ok(parsedJwt)) parsedJwt;
            case (#err(err)) {
                context.log(#error, "JWT parse failed: " # err);
                return;
            };
        };

        // 3. Validate JWT
        let isValid = switch (JWT.validate(jwt, validation)) {
            case (#ok) {
                context.log(#debug_, "JWT validated successfully");
                true;
            };
            case (#err(err)) {
                context.log(#warning, "JWT validation failed: " # err);
                false;
            };
        };
        // Set JWT payload in context for downstream handlers
        context.setIdentityJWT(jwt, isValid);
    };

    private func extractJWT(
        context : HttpContext.HttpContext,
        locations : [JWTLocation],
    ) : ?Text {
        label f for (location in locations.vals()) {
            switch (location) {
                case (#header(name)) {
                    // Try extracting from Authorization header
                    let ?authHeaderValue = context.getHeader(name) else continue f;
                    let ?bearerToken = Text.stripStart(authHeaderValue, #text("Bearer ")) else continue f;
                    return ?bearerToken;
                };
                case (#cookie(name)) {
                    // Extract from cookie
                    let ?cookieValue = context.getCookie(name) else continue f;
                    return ?cookieValue;
                };
                case (#queryString(name)) {
                    // Extract from query parameter
                    let ?queryValue = context.getQueryParam(name) else continue f;
                    return ?queryValue;
                };
            };
        };
        null;
    };
};
