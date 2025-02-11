import Pipeline "./Pipeline";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import TextX "mo:xtended-text/TextX";
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

    public let defaultOptions : Options = {
        allowOrigins = [];
        allowMethods = [#get, #post, #put, #delete, #options];
        allowHeaders = ["Content-Type", "Authorization"];
        maxAge = ?86400; // 24 hours
        allowCredentials = false;
        exposeHeaders = [];
    };

    public func useCors(data : Pipeline.PipelineData, options : Options) : Pipeline.PipelineData {
        let newMiddleware = createMiddleware(options);
        {
            middleware = Array.append(data.middleware, [newMiddleware]);
        };
    };

    public func createMiddleware(options : Options) : Pipeline.Middleware {
        {
            handle = func(context : HttpContext.HttpContext, next : Pipeline.Next) : Types.HttpResponse {

                let corsHeaders = Buffer.Buffer<(Text, Text)>(8);

                switch (context.getHeader("Origin")) {
                    case (?origin) {
                        if (not options.allowCredentials and options.allowOrigins.size() == 0) {
                            // If credentials aren't required and all origins are allowed, then we can use '*' for the origin
                            corsHeaders.add(("Access-Control-Allow-Origin", "*"));
                        } else if (isOriginAllowed(origin, options.allowOrigins)) {
                            // Otherwise specificy the origin if its allowed
                            corsHeaders.add(("Access-Control-Allow-Origin", origin));
                            corsHeaders.add(("Vary", "Origin"));
                        };
                    };
                    case (null) ();
                };

                // Credentials
                if (options.allowCredentials) {
                    corsHeaders.add(("Access-Control-Allow-Credentials", "true"));
                };

                // Handle preflight requests
                if (context.method == #options) {
                    return handlePreflightRequest(context, corsHeaders, options);
                };

                // Handle actual request
                let response = next();

                if (options.exposeHeaders.size() > 0) {
                    let exposedHeaders = Text.join(", ", options.exposeHeaders.vals());
                    corsHeaders.add(("Access-Control-Expose-Headers", exposedHeaders));
                };

                // Combine headers
                let responseHeaders = Buffer.Buffer<(Text, Text)>(response.headers.size() + corsHeaders.size());
                responseHeaders.append(Buffer.fromArray(response.headers));
                responseHeaders.append(corsHeaders); // Append CORS headers last

                {
                    response with
                    headers = Buffer.toArray(responseHeaders);
                };
            };
        };
    };

    private func handlePreflightRequest(
        context : HttpContext.HttpContext,
        responseHeaders : Buffer.Buffer<(Text, Text)>,
        options : Options,
    ) : Types.HttpResponse {

        // Methods
        switch (context.getHeader("Access-Control-Request-Method")) {
            case (?_) {
                // Only include when header is present
                if (options.allowMethods.size() == 0) {
                    // If no methods are specified, then allow all
                    responseHeaders.add(("Access-Control-Allow-Methods", "*"));
                } else {
                    // Otherwise specify the allowed methods
                    let allowMethodsText = options.allowMethods.vals()
                    |> Iter.map(_, func(m : HttpMethod.HttpMethod) : Text = HttpMethod.toText(m))
                    |> Text.join(", ", _);
                    responseHeaders.add(("Access-Control-Allow-Methods", allowMethodsText));
                };
            };
            case (null) {};
        };

        // Headers
        switch (context.getHeader("Access-Control-Request-Headers")) {
            case (?_) {
                // Only include when header is present
                let allowHeadersText = Text.join(", ", options.allowHeaders.vals());
                responseHeaders.add(("Access-Control-Allow-Headers", allowHeadersText));
            };
            case (null) ();
        };

        // Max age
        switch (options.maxAge) {
            case (?maxAge) {
                responseHeaders.add(("Access-Control-Max-Age", Nat.toText(maxAge)));
            };
            case (null) {};
        };

        return {
            statusCode = 204;
            headers = Buffer.toArray(responseHeaders);
            body = null;
        };
    };

    private func isOriginAllowed(origin : Text, allowedOrigins : [Text]) : Bool {
        if (allowedOrigins.size() == 0) return true; // All origins allowed
        for (allowed in allowedOrigins.vals()) {
            if (TextX.equalIgnoreCase(origin, allowed)) return true;
        };
        false;
    };
};
