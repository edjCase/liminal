import Text "mo:new-base/Text";
import List "mo:new-base/List";
import Nat "mo:new-base/Nat";
import Iter "mo:new-base/Iter";
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
        allowMethods = [#get, #post, #put, #patch, #delete, #head, #options];
        allowHeaders = ["Content-Type", "Authorization"];
        maxAge = ?86400; // 24 hours
        allowCredentials = false;
        exposeHeaders = [];
    };

    public func handlePreflight(context : HttpContext.HttpContext, options : Options) : {
        #complete : Types.HttpResponse;
        #next : { corsHeaders : [(Text, Text)] };
    } {

        let corsHeaders = List.empty<(Text, Text)>();

        switch (context.getHeader("Origin")) {
            case (?origin) {
                if (not options.allowCredentials and options.allowOrigins.size() == 0) {
                    // If credentials aren't required and all origins are allowed, then we can use '*' for the origin
                    List.add(corsHeaders, ("Access-Control-Allow-Origin", "*"));
                } else if (isOriginAllowed(origin, options.allowOrigins)) {
                    // Otherwise specificy the origin if its allowed
                    List.add(corsHeaders, ("Access-Control-Allow-Origin", origin));
                    List.add(corsHeaders, ("Vary", "Origin"));
                } else {
                    // If the origin is not allowed, don't return CORS headers so the browser will block the request
                };
            };
            case (null) ();
        };

        // Credentials
        if (options.allowCredentials) {
            List.add(corsHeaders, ("Access-Control-Allow-Credentials", "true"));
        };

        // Handle preflight requests
        if (context.method == #options) {
            return #complete(handlePreflightRequest(context, corsHeaders, options));
        };

        // Expose headers only in non-preflight requests
        if (options.exposeHeaders.size() > 0) {
            let exposedHeaders = Text.join(", ", options.exposeHeaders.vals());
            List.add(corsHeaders, ("Access-Control-Expose-Headers", exposedHeaders));
        };

        #next({ corsHeaders = List.toArray(corsHeaders) });

    };

    private func handlePreflightRequest(
        context : HttpContext.HttpContext,
        responseHeaders : List.List<(Text, Text)>,
        options : Options,
    ) : Types.HttpResponse {

        // Methods
        switch (context.getHeader("Access-Control-Request-Method")) {
            case (?_) {
                // Only include when header is present
                if (options.allowMethods.size() == 0) {
                    // If no methods are specified, then allow all
                    List.add(responseHeaders, ("Access-Control-Allow-Methods", "*"));
                } else {
                    // Otherwise specify the allowed methods
                    let allowMethodsText = options.allowMethods.vals()
                    |> Iter.map(_, func(m : HttpMethod.HttpMethod) : Text = HttpMethod.toText(m))
                    |> Text.join(", ", _);
                    List.add(responseHeaders, ("Access-Control-Allow-Methods", allowMethodsText));
                };
            };
            case (null) {};
        };

        // Headers
        switch (context.getHeader("Access-Control-Request-Headers")) {
            case (?_) {
                // Only include when header is present
                let allowHeadersText = Text.join(", ", options.allowHeaders.vals());
                List.add(responseHeaders, ("Access-Control-Allow-Headers", allowHeadersText));
            };
            case (null) ();
        };

        // Max age
        switch (options.maxAge) {
            case (?maxAge) {
                List.add(responseHeaders, ("Access-Control-Max-Age", Nat.toText(maxAge)));
            };
            case (null) {};
        };

        return {
            statusCode = 204;
            headers = List.toArray(responseHeaders);
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
