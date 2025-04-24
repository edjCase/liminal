import RateLimiter "../RateLimiter";
import HttpContext "../HttpContext";
import App "../App";
import Buffer "mo:base/Buffer";
import Option "mo:new-base/Option";
import Nat "mo:new-base/Nat";
import Int "mo:new-base/Int";
module {

    public type Config = RateLimiter.Config and {

        // Headers to include in responses
        includeResponseHeaders : Bool;

        // Message to return when rate limit is exceeded
        limitExceededMessage : ?Text;

        // The key extractor function to determine rate limit key (e.g., IP, identity ID)
        keyExtractor : KeyExtractor;

        // Optional skip function to bypass rate limiting for certain requests
        skipIf : ?SkipFunction;
    };

    // The key extractor function determines what unique key to use for rate limiting
    public type KeyExtractor = {
        #ip;
        #identityIdOrIp;
        #custom : HttpContext.HttpContext -> Text;
    };

    // Skip function determines if a request should skip rate limiting
    public type SkipFunction = HttpContext.HttpContext -> Bool;

    public func new(config : Config) : App.Middleware {
        let rateLimiter = RateLimiter.RateLimiter(config);

        {
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                // Can't store rate limiting info in the query and queries aren't the bottle neck
                next();
            };

            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                // Check if we should skip rate limiting
                switch (config.skipIf) {
                    case (?skipFn) {
                        if (skipFn(context)) {
                            return await* next(); // Skip rate limiting
                        };
                    };
                    case (null) {};
                };

                let key = switch (config.keyExtractor) {
                    case (#ip) ipKeyExtractor(context);
                    case (#identityIdOrIp) userOrIpKeyExtractor(context);
                    case (#custom(extractor)) extractor(context);
                };
                switch (rateLimiter.check(key)) {
                    case (#allowed(allowed)) {
                        let response = await* next();

                        if (config.includeResponseHeaders) {
                            let newHeaders = getHeaders(allowed);
                            for (header in response.headers.vals()) {
                                newHeaders.add(header);
                            };
                            return {
                                response with
                                headers = Buffer.toArray(newHeaders);
                            };
                        };
                        return response;

                    };
                    case (#limited(limited)) {
                        let message = Option.get(config.limitExceededMessage, "Rate limit exceeded");
                        let { body; headers = errorHeaders } = context.errorSerializer({
                            statusCode = 429;
                            data = #message(message);
                        });
                        let headers = if (config.includeResponseHeaders) {
                            let headers = getHeaders(limited);
                            headers.add(("Retry-After", Int.toText(limited.retryAfter)));

                            for (errorHeader in errorHeaders.vals()) {
                                headers.add(errorHeader);
                            };
                            Buffer.toArray(headers);

                        } else errorHeaders;

                        // Return rate limit exceeded response
                        return {
                            statusCode = 429;
                            headers = headers;
                            body = body;
                            streamingStrategy = null;
                        };
                    };
                };
            };
        };
    };

    func getHeaders(data : RateLimiter.AllowedData) : Buffer.Buffer<(Text, Text)> {
        let headers = Buffer.Buffer<(Text, Text)>(6);
        headers.add(("X-RateLimit-Limit", Nat.toText(data.limit)));
        headers.add(("X-RateLimit-Remaining", Nat.toText(data.remaining)));
        headers.add(("X-RateLimit-Reset", Int.toText(data.resetAt / 1_000_000_000))); // Convert to seconds
        headers;
    };

    // Default key extractor that uses IP address
    func ipKeyExtractor(context : HttpContext.HttpContext) : Text {
        switch (context.getHeader("X-Forwarded-For")) {
            case (?ip) return ip;
            case (null) {
                switch (context.getHeader("X-Real-IP")) {
                    case (?ip) return ip;
                    case (null) "unknown-ip";
                };
            };
        };
    };

    // Default key extractor that uses authenticated user ID or fallbacks to IP
    func userOrIpKeyExtractor(context : HttpContext.HttpContext) : Text {
        switch (context.getIdentity()) {
            case (?identity) {
                switch (identity.getId()) {
                    case (?id) return id;
                    case (null) return ipKeyExtractor(context);
                };
            };
            case (null) return ipKeyExtractor(context);
        };
    };

};
