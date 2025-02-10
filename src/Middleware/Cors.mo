import Pipeline "../Pipeline";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import TextX "mo:xtended-text/TextX";
import HttpContext "../HttpContext";
import Types "../Types";

module {

    public type Options = {
        allowOrigins : [Text]; // Empty means all origins allowed
        allowMethods : [Types.HttpMethod]; // Empty means all methods allowed
        allowHeaders : [Text]; // Empty means all headers allowed
        maxAge : Nat;
        allowCredentials : Bool;
        exposeHeaders : [Text]; // Empty means none
    };
    private let defaultOptions : Options = {
        allowOrigins = [];
        allowMethods = [#get, #post, #put, #delete, #options];
        allowHeaders = ["Content-Type", "Authorization"];
        maxAge = 86400; // 24 hours
        allowCredentials = false;
        exposeHeaders = [];
    };

    public func useCors(data : Pipeline.PipelineData, options_ : Options) : Pipeline.PipelineData {
        let options = mergeOptions(options_);
        let newMiddleware = createMiddleware(options);
        {
            middleware = Array.append(data.middleware, [newMiddleware]);
        };
    };

    public func createMiddleware(options : Options) : Pipeline.Middleware {
        {
            handle = func(context : HttpContext.HttpContext, next : Pipeline.Next) : Types.HttpResponse {

                let responseHeaders = Buffer.Buffer<(Text, Text)>(8);

                if (options.allowCredentials) {
                    responseHeaders.add(("Access-Control-Allow-Credentials", "true"));
                };

                // Handle preflight requests
                if (Text.equal(context.request.method, "OPTIONS")) {

                    responseHeaders.add((
                        "Access-Control-Allow-Origin",
                        stringListOrStar(options.allowOrigins),
                    ));
                    // Methods
                    let allowMethods = Array.map(options.allowMethods, func(m : Types.HttpMethod) : Text = Types.HttpMethod.toText(m));
                    responseHeaders.add(("Access-Control-Allow-Methods", stringListOrStar(allowMethods)));

                    // Headers
                    responseHeaders.add(("Access-Control-Allow-Headers", stringListOrStar(options.allowHeaders)));

                    responseHeaders.add(("Access-Control-Max-Age", Nat.toText(options.maxAge)));

                    return {
                        statusCode = 204;
                        headers = Buffer.toArray(responseHeaders);
                        body = null;
                    };
                };
                let ?origin = context.getHeader("Origin") else return {
                    statusCode = 400;
                    headers = [];
                    body = ?Text.encodeUtf8("Origin header missing");
                };
                if (isOriginAllowed(origin, options.allowOrigins)) {
                    responseHeaders.add(("Access-Control-Allow-Origin", origin));
                };

                // Handle actual request
                let response = next();

                // Copy existing headers
                for ((key, value) in response.headers.vals()) {
                    responseHeaders.add((key, value));
                };

                if (options.exposeHeaders.size() > 0) {
                    let exposedHeaders = Text.join(", ", options.exposeHeaders.vals());
                    responseHeaders.add(("Access-Control-Expose-Headers", exposedHeaders));
                };

                {
                    response with
                    headers = Buffer.toArray(responseHeaders);
                };
            };
        };
    };

    // Default options

    // Helper to merge options with defaults
    private func mergeOptions(options : Options) : Options {
        {
            allowOrigins = Option.get(options.allowOrigins, defaultOptions.allowOrigins);
            allowMethods = Option.get(options.allowMethods, defaultOptions.allowMethods);
            allowHeaders = Option.get(options.allowHeaders, defaultOptions.allowHeaders);
            maxAge = Option.get(options.maxAge, defaultOptions.maxAge);
            allowCredentials = Option.get(options.allowCredentials, defaultOptions.allowCredentials);
            exposeHeaders = Option.get(options.exposeHeaders, defaultOptions.exposeHeaders);
        };
    };

    // Validate origin against allowed origins or regex
    private func isOriginAllowed(origin : Text, allowedOrigins : [Text]) : Bool {
        if (allowedOrigins.size() == 0) return true; // All origins allowed
        for (allowed in allowedOrigins.vals()) {
            if (TextX.equalIgnoreCase(origin, allowed)) return true;
        };
        false;
    };

    private func stringListOrStar(list : [Text]) : Text {
        if (list.size() == 0) return "*";
        Text.join(", ", list.vals());
    };
};
