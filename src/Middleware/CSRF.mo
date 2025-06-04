import Text "mo:new-base/Text";
import Time "mo:new-base/Time";
import Array "mo:new-base/Array";
import Int "mo:new-base/Int";
import Random "mo:new-base/Random";
import HttpContext "../HttpContext";
import HttpMethod "../HttpMethod";
import App "../App";
import Path "../Path";

module {
    public type TokenStorage = {
        get : () -> ?Text;
        set : (Text) -> ();
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
    };

    // Token rotation strategies
    public type TokenRotation = {
        #perRequest; // Generate new token on each request
        #perSession; // Keep token valid for the entire session
        #onSuccess; // Only rotate after successful validation
    };

    // Default CSRF configuration
    public func defaultConfig(tokenStorage : TokenStorage) : Config {
        {
            tokenTTL = 1_800_000_000_000; // 30 minutes
            tokenStorage = tokenStorage;
            headerName = "X-CSRF-Token";
            protectedMethods = [#post, #put, #patch, #delete];
            exemptPaths = [];
            tokenRotation = #perRequest;
        };
    };

    // CSRF middleware generator
    public func new(config : Config) : App.Middleware {
        // Handlers for middleware
        {
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                switch (handleCsrf(context, config)) {
                    case (#proceed) {
                        // If GET request, generate a new token
                        if (context.method == #get) {
                            generateAndSetToken(context, config);
                        };

                        next();
                    };
                    case (#forbidden(message)) {
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
                switch (handleCsrf(context, config)) {
                    case (#proceed) {
                        // If GET request, generate a new token
                        if (context.method == #get) {
                            generateAndSetToken(context, config);
                        };

                        await* next();
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

    public func default(tokenStorage : TokenStorage) : App.Middleware {
        new(defaultConfig(tokenStorage));
    };

    // Main CSRF logic
    private func handleCsrf(context : HttpContext.HttpContext, config : Config) : {
        #proceed;
        #forbidden : Text;
    } {
        // Skip CSRF check for non-protected methods
        let isProtectedMethod = Array.find(
            config.protectedMethods,
            func(m : HttpMethod.HttpMethod) : Bool { m == context.method },
        ) != null;

        if (not isProtectedMethod) {
            return #proceed;
        };

        // Check exempt paths
        let path = Path.toText(context.getPath());
        for (exemptPath in config.exemptPaths.vals()) {
            if (Text.startsWith(path, #text(exemptPath))) {
                return #proceed;
            };
        };

        // Validate CSRF token
        let ?requestToken = context.getHeader(config.headerName) else return #forbidden("CSRF token missing from request header: " # config.headerName);
        let ?storedToken = config.tokenStorage.get() else return #forbidden("CSRF token not found in storage");

        if (requestToken != storedToken) {
            return #forbidden("CSRF token validation failed");
        };

        // Check token expiration
        if (isTokenExpired(storedToken, config.tokenTTL)) {
            return #forbidden("CSRF token expired");
        };

        // Handle token rotation if needed
        if (config.tokenRotation == #onSuccess) {
            generateAndSetToken(context, config);
        };

        return #proceed;
    };

    // Generate a new CSRF token
    private func generateAndSetToken(context : HttpContext.HttpContext, config : Config) {
        let randomPart = Random.crypto(); // Would be actual random bytes
        let token = Int.toText(Time.now()) # "-" # randomPart;
        config.tokenStorage.set(token);
    };

    // Check if token is expired
    private func isTokenExpired(token : Text, ttl : Int) : Bool {
        // In a real implementation, the token would include a timestamp
        // Placeholder implementation assumes tokens don't expire:
        false;
    };

};
