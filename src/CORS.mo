import Text "mo:new-base/Text";
import List "mo:new-base/List";
import Nat "mo:new-base/Nat";
import Iter "mo:new-base/Iter";
import Array "mo:new-base/Array";
import HttpContext "./HttpContext";
import Types "./Types";
import HttpMethod "./HttpMethod";

module {

    public type Options = {
        allowOrigins : [Text]; // Empty means all origins allowed
        allowMethods : [HttpMethod.HttpMethod]; // Empty means all methods allowed
        allowHeaders : [Text]; // Empty means all headers allowed
        maxAge : ?Nat; // Optional
        allowCredentials : Bool;
        exposeHeaders : [Text]; // Empty means none
    };

    /// Default CORS options that provide a permissive but secure baseline configuration.
    /// Allows common HTTP methods and headers while requiring explicit origin configuration.
    /// Sets a 24-hour cache for preflight requests and disables credentials by default.
    ///
    /// ```motoko
    /// import CORS "mo:liminal/CORS";
    ///
    /// let options = CORS.defaultOptions;
    /// let result = CORS.handlePreflight(httpContext, options);
    /// ```
    public let defaultOptions : Options = {
        allowOrigins = [];
        allowMethods = [#get, #post, #put, #patch, #delete, #head, #options];
        allowHeaders = ["Content-Type", "Authorization"];
        maxAge = ?86400; // 24 hours
        allowCredentials = false;
        exposeHeaders = [];
    };

    /// Handles CORS preflight requests (OPTIONS method).
    /// Validates the request against CORS policy and returns appropriate headers or continues processing.
    /// Preflight requests are sent by browsers for complex CORS requests to check permissions.
    ///
    /// ```motoko
    /// import CORS "mo:liminal/CORS";
    ///
    /// let options = CORS.defaultOptions();
    /// let result = CORS.handlePreflight(httpContext, options);
    /// switch (result) {
    ///     case (#complete(response)) {
    ///         // Preflight handled, return response
    ///     };
    ///     case (#next({ corsHeaders })) {
    ///         // Continue processing with CORS headers
    ///     };
    /// }
    /// ```
    public func handlePreflight(context : HttpContext.HttpContext, options : Options) : {
        #complete : Types.HttpResponse;
        #next : { corsHeaders : [(Text, Text)] };
    } {
        let corsHeaders = List.empty<(Text, Text)>();

        // 1. Check Origin header
        switch (context.getHeader("Origin")) {
            case (null) {
                // No Origin header, not a CORS request
                return #next({ corsHeaders = [] });
            };
            case (?origin) {
                // Validate origin format
                if (not validOriginFormat(origin)) {
                    // Per spec 6.1/6.2, don't set CORS headers if origin format is invalid
                    return #next({ corsHeaders = [] });
                };

                // Check if origin is allowed
                if (not isOriginAllowed(origin, options.allowOrigins)) {
                    // Per spec 6.1/6.2, don't set CORS headers if origin is not allowed
                    return #next({ corsHeaders = [] });
                };

                // Set Access-Control-Allow-Origin header
                if (not options.allowCredentials and options.allowOrigins.size() == 0) {
                    List.add(corsHeaders, ("Access-Control-Allow-Origin", "*"));
                } else {
                    List.add(corsHeaders, ("Access-Control-Allow-Origin", origin));
                    List.add(corsHeaders, ("Vary", "Origin"));
                };

                // Set credentials header if needed
                if (options.allowCredentials) {
                    List.add(corsHeaders, ("Access-Control-Allow-Credentials", "true"));
                };
            };
        };

        // Check if this is actually a preflight request
        // OPTIONS method with Access-Control-Request-Method header indicates preflight
        let isPreflightRequest = context.method == #options and context.getHeader("Access-Control-Request-Method") != null;

        // Handle preflight request
        if (isPreflightRequest) {
            // Check Access-Control-Request-Method header
            switch (context.getHeader("Access-Control-Request-Method")) {
                case (null) {
                    // Missing required header, per spec 6.2 don't set additional headers
                    return #complete({
                        statusCode = 200;
                        headers = [];
                        body = null;
                        streamingStrategy = null;
                    });
                };
                case (?requestMethodHeader) {
                    // Parse the method
                    switch (parseRequestMethod(requestMethodHeader)) {
                        case (null) {
                            // Parsing failed, per spec 6.2 don't set additional headers
                            return #complete({
                                statusCode = 200;
                                headers = [];
                                body = null;
                                streamingStrategy = null;
                            });
                        };
                        case (?requestMethod) {
                            // Check if method is allowed
                            if (not isMethodAllowed(requestMethod, options.allowMethods)) {
                                // Method not allowed, per spec 6.2 don't set additional headers
                                return #complete({
                                    statusCode = 200;
                                    headers = [];
                                    body = null;
                                    streamingStrategy = null;
                                });
                            };

                            // Add Access-Control-Allow-Methods header
                            let allowedMethodsText = if (options.allowMethods.size() > 0) {
                                Text.join(
                                    ", ",
                                    Iter.map<HttpMethod.HttpMethod, Text>(
                                        options.allowMethods.vals(),
                                        func(m) { HttpMethod.toText(m) },
                                    ),
                                );
                            } else { "*" };

                            List.add(corsHeaders, ("Access-Control-Allow-Methods", allowedMethodsText));

                            // Handle Access-Control-Request-Headers
                            switch (context.getHeader("Access-Control-Request-Headers")) {
                                case (null) {
                                    // No headers requested, that's fine
                                };
                                case (?requestHeadersHeader) {
                                    // Parse headers
                                    switch (parseHeaderList(requestHeadersHeader)) {
                                        case (null) {
                                            // Parsing failed, per spec 6.2 don't set additional headers
                                            return #complete({
                                                statusCode = 200;
                                                headers = [];
                                                body = null;
                                                streamingStrategy = null;
                                            });
                                        };
                                        case (?requestedHeaders) {
                                            // Check if all headers are allowed
                                            if (not areHeadersAllowed(requestedHeaders, options.allowHeaders)) {
                                                // Some headers not allowed, per spec 6.2 don't set additional headers
                                                return #complete({
                                                    statusCode = 200;
                                                    headers = [];
                                                    body = null;
                                                    streamingStrategy = null;
                                                });
                                            };

                                            // Add Access-Control-Allow-Headers header
                                            let allowedHeadersText = if (options.allowHeaders.size() > 0) {
                                                Text.join(", ", options.allowHeaders.vals());
                                            } else {
                                                "*";
                                            };
                                            List.add(corsHeaders, ("Access-Control-Allow-Headers", allowedHeadersText));
                                        };
                                    };
                                };
                            };

                            // Add max-age header if configured
                            switch (options.maxAge) {
                                case (null) {};
                                case (?maxAge) {
                                    // Limit max-age to reasonable value (24 hours)
                                    let limitedMaxAge = if (maxAge > 86400) 86400 else maxAge;
                                    List.add(corsHeaders, ("Access-Control-Max-Age", Nat.toText(limitedMaxAge)));
                                };
                            };
                        };
                    };
                };
            };

            // Complete the preflight request with appropriate headers
            return #complete({
                statusCode = 200; // OK is standard for OPTIONS preflight response
                headers = List.toArray(corsHeaders);
                body = null;
                streamingStrategy = null;
            });
        };

        // For non-preflight requests, add exposed headers if configured
        if (options.exposeHeaders.size() > 0) {
            let exposedHeadersText = Text.join(", ", options.exposeHeaders.vals());
            List.add(corsHeaders, ("Access-Control-Expose-Headers", exposedHeadersText));
        };

        #next({ corsHeaders = List.toArray(corsHeaders) });
    };

    // Parse and validate request method
    private func parseRequestMethod(method : Text) : ?HttpMethod.HttpMethod {
        let trimmed = Text.trim(method, #predicate(func(c : Char) : Bool { c == ' ' }));
        HttpMethod.fromText(trimmed);
    };

    // Parse and validate headers list
    private func parseHeaderList(headerList : Text) : ?[Text] {
        let parts = Iter.toArray(Text.split(headerList, #char ','));

        var valid = true;
        let parsedHeaders = Array.foldLeft<Text, List.List<Text>>(
            parts,
            List.empty<Text>(),
            func(acc : List.List<Text>, part : Text) : List.List<Text> {
                let trimmed = Text.trim(part, #predicate(func(c : Char) : Bool { c == ' ' }));
                if (trimmed == "") {
                    valid := false;
                } else {
                    List.add(acc, trimmed);
                };
                acc;
            },
        );

        if (valid) {
            ?List.toArray(parsedHeaders);
        } else {
            null;
        };
    };

    // Check if all requested headers are allowed
    private func areHeadersAllowed(requestedHeaders : [Text], allowedHeaders : [Text]) : Bool {
        if (allowedHeaders.size() == 0) return true; // All headers allowed

        for (header in requestedHeaders.vals()) {
            var found = false;
            let headerLower = Text.toLower(header);
            label f for (allowed in allowedHeaders.vals()) {
                if (Text.toLower(allowed) == headerLower) {
                    found := true;
                    break f;
                };
            };
            if (not found) return false;
        };

        true;
    };

    // Validate origin format
    private func validOriginFormat(origin : Text) : Bool {
        Text.startsWith(origin, #text "http://") or Text.startsWith(origin, #text "https://");
    };

    private func isMethodAllowed(method : HttpMethod.HttpMethod, allowedMethods : [HttpMethod.HttpMethod]) : Bool {
        if (allowedMethods.size() == 0) return true; // All methods allowed

        for (allowed in allowedMethods.vals()) {
            if (method == allowed) return true;
        };

        false;
    };

    private func isOriginAllowed(origin : Text, allowedOrigins : [Text]) : Bool {
        if (allowedOrigins.size() == 0) return true; // All origins allowed

        for (allowed in allowedOrigins.vals()) {
            if (Text.toLower(origin) == Text.toLower(allowed)) return true;
        };

        false;
    };
};
