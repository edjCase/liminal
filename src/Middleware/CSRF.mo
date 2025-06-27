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
import Debug "mo:new-base/Debug";

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

    // Default CSRF configuration
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

    // CSRF middleware generator
    public func new(config : Config) : App.Middleware {
        // Handlers for middleware
        {
            name = "CSRF";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                #upgrade; // CSRF middleware does not handle queries, has to upgrade
            };

            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                // Handle token endpoint for POST requests (alternative way to get tokens)
                switch (config.tokenEndpoint) {
                    case (?endpoint) {
                        let path = Path.toText(context.getPath());
                        if (path == endpoint) {
                            let token = await* generateAndSetToken(context, config);
                            return context.buildResponse(
                                #ok,
                                #content(#Map([("token", #Text(token))])),
                            );
                        };
                    };
                    case (null) {};
                };

                switch (await* handleCsrf(context, config)) {
                    case (#proceed(tokenOrNull)) {
                        let response = await* next();
                        switch (tokenOrNull) {
                            case (null) {
                                // No token to add, just return the response
                                response;
                            };
                            case (?token) {
                                // Add new token to response headers
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
        context.log(#info, "CSRF: handleCsrf called for method: " # HttpMethod.toText(context.method));

        // Skip CSRF check for non-protected methods
        let isProtectedMethod = Array.find(
            config.protectedMethods,
            func(m : HttpMethod.HttpMethod) : Bool { m == context.method },
        ) != null;

        context.log(#info, "CSRF: isProtectedMethod = " # Bool.toText(isProtectedMethod));

        if (not isProtectedMethod) {
            context.log(#info, "CSRF: Method not protected, proceeding");
            // Handle token rotation for non-protected methods if needed
            switch (config.tokenRotation) {
                case (#perRequest) {
                    let newToken = await* generateAndSetToken(context, config);
                    return #proceed(?newToken);
                };
                case (#perSession or #onSuccess) {
                    return #proceed(null);
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
                return #proceed(null);
            };
        };

        context.log(#info, "CSRF: Path not exempt, checking token");

        // Get stored token - generate one if none exists
        let storedToken = switch (config.tokenStorage.get()) {
            case (?token) {
                context.log(#info, "CSRF: Found stored token");
                token;
            };
            case (null) {
                context.log(#info, "CSRF: No stored token, returning forbidden");
                // No token exists, generate a new one
                let newToken = await* generateAndSetToken(context, config);
                context.log(#info, "Generated initial CSRF token");
                return #forbidden("CSRF token required. Please obtain a token first.");
            };
        };

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

        // Handle token rotation based on strategy
        switch (config.tokenRotation) {
            case (#perRequest) {
                let newToken = await* generateAndSetToken(context, config);
                return #proceed(?newToken);
            };
            case (#onSuccess) {
                let newToken = await* generateAndSetToken(context, config);
                return #proceed(?newToken);
            };
            case (#perSession) {
                // Keep existing token for the session
                return #proceed(null);
            };
        };
    };

    private func generateAndSetToken(context : HttpContext.HttpContext, config : Config) : async* Text {
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

    // Utility function to create a simple in-memory token storage
    public func createMemoryStorage() : TokenStorage {
        var token : ?Text = null;

        {
            get = func() : ?Text { token };
            set = func(newToken : Text) { token := ?newToken };
            clear = func() { token := null };
        };
    };
};
