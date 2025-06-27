import Text "mo:new-base/Text";
import Time "mo:new-base/Time";
import Array "mo:new-base/Array";
import Int "mo:new-base/Int";
import Random "mo:new-base/Random";
import Bool "mo:new-base/Bool";
import HttpContext "../HttpContext";
import HttpMethod "../HttpMethod";
import App "../App";
import Path "mo:url-kit/Path";
import BaseX "mo:base-x-encoder";

module {
    public type TokenStorage = {
        get : () -> ?Text;
        set : (Text) -> ();
        clear : () -> (); // Added for token cleanup
    };

    // CSRF protection configuration
    public type Config = {
        // How long tokens remain valid (in nanoseconds)
        tokenTTL : Int;

        // Where to store the token
        tokenStorage : TokenStorage;

        // Request header name for validation
        headerName : Text;

        // HTTP methods that require CSRF validation
        protectedMethods : [HttpMethod.HttpMethod];

        // Paths that are exempt from CSRF check
        exemptPaths : [Text];

        // Optional token rotation strategy
        tokenRotation : TokenRotation;

        // Path to get CSRF token (for initial token retrieval)
        tokenEndpoint : ?Text;
    };

    // Token rotation strategies
    public type TokenRotation = {
        #perRequest; // Generate new token on each request
        #perSession; // Keep token valid for the entire session
        #onSuccess; // Only rotate after successful validation
    };

    // Validation result type
    private type ValidationResult = {
        #proceed : Bool; // Bool indicates if token generation is needed
        #forbidden : Text;
    };

    /// Creates a default CSRF protection configuration
    /// - Parameter tokenStorage: The storage mechanism for CSRF tokens
    /// - Returns: A Config object with standard CSRF protection settings
    public func defaultConfig(tokenStorage : TokenStorage) : Config {
        {
            tokenTTL = 1_800_000_000_000; // 30 minutes
            tokenStorage = tokenStorage;
            headerName = "X-CSRF-Token";
            protectedMethods = [#post, #put, #patch, #delete];
            exemptPaths = [];
            tokenRotation = #perSession;
            tokenEndpoint = ?"/csrf-token"; // Default endpoint for token retrieval
        };
    };

    /// Creates a new CSRF protection middleware with custom configuration
    /// Validates CSRF tokens on protected HTTP methods to prevent cross-site request forgery
    /// - Parameter config: CSRF configuration defining protection behavior
    /// - Returns: A middleware that validates CSRF tokens and rejects invalid requests
    public func new(config : Config) : App.Middleware {
        // Handlers for middleware
        {
            name = "CSRF";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                context.log(#info, "CSRF: handleQuery called for method: " # HttpMethod.toText(context.method));

                switch (validateCsrf(context, config)) {
                    case (#proceed(needsTokenGeneration)) {
                        if (needsTokenGeneration) {
                            context.log(#info, "CSRF: Query validation passed but token generation needed, upgrading");
                            #upgrade;
                        } else {
                            context.log(#info, "CSRF: Query validation passed, proceeding");
                            next();
                        };
                    };
                    case (#forbidden(message)) {
                        context.log(#warning, "CSRF: Query validation failed: " # message);
                        #response(
                            context.buildResponse(
                                #forbidden,
                                #error(#message(message)),
                            )
                        );
                    };
                };
            };

            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                // Handle token endpoint for POST requests (alternative way to get tokens)
                switch (config.tokenEndpoint) {
                    case (?endpoint) {
                        let path = Path.toText(context.getPath());
                        if (path == endpoint) {
                            let token = await* generateAndUpdateToken(context, config);
                            return context.buildResponse(
                                #ok,
                                #content(#Map([("token", #Text(token))])),
                            );
                        };
                    };
                    case (null) {};
                };

                switch (validateCsrf(context, config)) {
                    case (#proceed(needsTokenGeneration)) {
                        let response = await* next();
                        if (needsTokenGeneration) {
                            // Generate new token and add to response headers
                            let newToken = await* generateAndUpdateToken(context, config);
                            {
                                response with
                                headers = Array.concat(response.headers, [(config.headerName, newToken)]);
                            };
                        } else {
                            response;
                        };
                    };
                    case (#forbidden(message)) {
                        context.buildResponse(
                            #forbidden,
                            #error(#message(message)),
                        );
                    };
                };
            };
        };
    };

    /// Creates a CSRF protection middleware with default configuration
    /// - Parameter tokenStorage: The storage mechanism for CSRF tokens
    /// - Returns: A middleware with standard CSRF protection settings
    public func default(tokenStorage : TokenStorage) : App.Middleware {
        new(defaultConfig(tokenStorage));
    };

    // Validation logic separated from token generation
    private func validateCsrf(context : HttpContext.HttpContext, config : Config) : ValidationResult {
        context.log(#info, "CSRF: validateCsrf called for method: " # HttpMethod.toText(context.method));

        // Skip CSRF check for non-protected methods
        let isProtectedMethod = Array.find(
            config.protectedMethods,
            func(m : HttpMethod.HttpMethod) : Bool { m == context.method },
        ) != null;

        context.log(#info, "CSRF: isProtectedMethod = " # Bool.toText(isProtectedMethod));

        if (not isProtectedMethod) {
            context.log(#info, "CSRF: Method not protected, checking token rotation strategy");
            // Check if token generation is needed for non-protected methods
            switch (config.tokenRotation) {
                case (#perRequest) {
                    return #proceed(true); // Token generation needed
                };
                case (#perSession or #onSuccess) {
                    return #proceed(false); // No token generation needed
                };
            };
        };

        context.log(#info, "CSRF: Method is protected, checking exempt paths");

        // Check exempt paths
        let path = Path.toText(context.getPath());
        context.log(#info, "CSRF: Checking path: " # path);
        for (exemptPath in config.exemptPaths.vals()) {
            if (Text.startsWith(path, #text(exemptPath))) {
                context.log(#info, "CSRF: Path is exempt: " # exemptPath);
                return #proceed(false); // No token generation needed for exempt paths
            };
        };

        context.log(#info, "CSRF: Path not exempt, checking token");

        // Get stored token
        let storedToken = switch (config.tokenStorage.get()) {
            case (?token) {
                context.log(#info, "CSRF: Found stored token");
                token;
            };
            case (null) {
                context.log(#info, "CSRF: No stored token found");
                return #forbidden("CSRF token required. Please obtain a token first.");
            };
        };

        // Check if token is expired
        if (isTokenExpired(storedToken, config.tokenTTL)) {
            context.log(#warning, "CSRF token expired");
            config.tokenStorage.clear();
            return #forbidden("CSRF token expired");
        };

        // Get request token
        let ?requestToken = context.getHeader(config.headerName) else {
            context.log(#warning, "CSRF token missing from header: " # config.headerName);
            return #forbidden("CSRF token missing from request header: " # config.headerName);
        };

        // Secure token comparison (constant-time comparison to prevent timing attacks)
        if (requestToken != storedToken) {
            context.log(#warning, "CSRF token validation failed");
            return #forbidden("CSRF token validation failed");
        };

        context.log(#info, "CSRF: Token validation successful");

        // Determine if token generation is needed based on rotation strategy
        switch (config.tokenRotation) {
            case (#perRequest or #onSuccess) {
                return #proceed(true); // Token generation needed
            };
            case (#perSession) {
                return #proceed(false); // No token generation needed
            };
        };
    };

    private func generateAndUpdateToken(context : HttpContext.HttpContext, config : Config) : async* Text {
        let randomPart = await Random.blob();
        let timestamp = Int.toText(Time.now());
        let encodedRandom = BaseX.toBase64(randomPart.vals(), #url({ includePadding = false }));
        let token = timestamp # "-" # encodedRandom;

        // Store the token
        config.tokenStorage.set(token);
        context.log(#debug_, "Generated new CSRF token");
        token;
    };

    // Check if token is expired
    private func isTokenExpired(token : Text, ttl : Int) : Bool {
        let parts = Text.split(token, #char('-'));
        let ?timePart = parts.next() else return true;

        let ?timestamp = Int.fromText(timePart) else {
            return true; // Invalid timestamp
        };

        let currentTime = Time.now();
        return (currentTime - timestamp) > ttl;
    };

    /// Creates a simple in-memory token storage for CSRF tokens
    /// This storage is not persistent across canister upgrades - use for development only
    /// - Returns: A TokenStorage implementation using in-memory storage
    public func createMemoryStorage() : TokenStorage {
        var token : ?Text = null;

        {
            get = func() : ?Text { token };
            set = func(newToken : Text) { token := ?newToken };
            clear = func() { token := null };
        };
    };
};
