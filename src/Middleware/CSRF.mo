import Text "mo:new-base/Text";
import Time "mo:new-base/Time";
import Array "mo:new-base/Array";
import Int "mo:new-base/Int";
import Random "mo:new-base/Random";
import HttpContext "../HttpContext";
import HttpMethod "../HttpMethod";
import App "../App";
import Path "mo:url-kit/Path";
import BaseX "mo:base-x-encoder";

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
            name = "CSRF";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                // Query calls cant store CSRF tokens, so we skip them
                next();
            };

            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                switch (await* handleCsrf(context, config)) {
                    case (#proceed(tokenOrNull)) {
                        let response = await* next();
                        switch (tokenOrNull) {
                            case (null) {
                                // No token to add, just return the response
                                response;
                            };
                            case (?token) {
                                {
                                    response with
                                    headers = Array.concat(response.headers, [(config.headerName, token)]);
                                };
                            };
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

    public func default(tokenStorage : TokenStorage) : App.Middleware {
        new(defaultConfig(tokenStorage));
    };

    // Main CSRF logic
    private func handleCsrf(context : HttpContext.HttpContext, config : Config) : async* {
        #proceed : ?Text;
        #forbidden : Text;
    } {
        // Skip CSRF check for non-protected methods
        let isProtectedMethod = Array.find(
            config.protectedMethods,
            func(m : HttpMethod.HttpMethod) : Bool { m == context.method },
        ) != null;

        if (not isProtectedMethod) {
            return #proceed(null);
        };

        // Check exempt paths
        let path = Path.toText(context.getPath());
        for (exemptPath in config.exemptPaths.vals()) {
            if (Text.startsWith(path, #text(exemptPath))) {
                return #proceed(null);
            };
        };

        // Validate CSRF token
        let ?requestToken = context.getHeader(config.headerName) else {
            context.log(#warning, "CSRF token missing from header: " # config.headerName);
            return #forbidden("CSRF token missing from request header: " # config.headerName);
        };
        let ?storedToken = config.tokenStorage.get() else {
            context.log(#warning, "CSRF token not found in storage");
            return #forbidden("CSRF token not found in storage");
        };

        if (requestToken != storedToken) {
            context.log(#warning, "CSRF token validation failed");
            return #forbidden("CSRF token validation failed");
        };

        // Check token expiration
        if (isTokenExpired(storedToken, config.tokenTTL)) {
            context.log(#warning, "CSRF token expired");
            return #forbidden("CSRF token expired");
        };

        // Handle token rotation if needed
        if (config.tokenRotation == #onSuccess) {
            let newToken = await* generateAndSetToken(context, config);
            return #proceed(?newToken);
        };

        #proceed(null);
    };

    private func generateAndSetToken(context : HttpContext.HttpContext, config : Config) : async* Text {
        // Generate a new CSRF token
        let randomPart = await Random.blob(); // Would be actual random bytes
        let token = Int.toText(Time.now()) # "-" # BaseX.toBase64(randomPart.vals(), #url({ includePadding = false }));

        // Store the token
        config.tokenStorage.set(token);

        token;
    };

    // Check if token is expired
    private func isTokenExpired(token : Text, ttl : Int) : Bool {
        let parts = Text.split(token, #char('-'));
        let ?timePart = parts.next() else return true; // Invalid token format
        let ?randomPart = parts.next() else return true; // Invalid token format

        let ?timestamp = Int.fromText(timePart) else {
            return true; // Invalid timestamp
        };

        let currentTime = Time.now();
        return (currentTime - timestamp) > ttl;
    };

};
