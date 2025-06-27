import RateLimiter "../RateLimiter";
import HttpContext "../HttpContext";
import App "../App";
import Array "mo:new-base/Array";
module {

    public type Config = RateLimiter.Config;
    /// Creates a new rate limiting middleware with the specified configuration
    /// Enforces rate limits on incoming requests to prevent abuse and ensure fair usage
    /// - Parameter config: Rate limiter configuration defining limits and behaviors
    /// - Returns: A middleware that tracks and enforces request rate limits
    public func new(config : Config) : App.Middleware {
        let rateLimiter = RateLimiter.RateLimiter(config);

        {
            name = "Rate Limiter";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                // Can't store rate limiting info in the query and queries aren't the bottle neck
                next();
            };

            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                switch (rateLimiter.check(context)) {
                    case (#skipped) await* next();
                    case (#limited(response)) {
                        context.log(#warning, "Request rate limited");
                        response;
                    };
                    case (#allowed({ responseHeaders })) {
                        let response = await* next();
                        if (responseHeaders.size() > 0) {
                            // Add the rate limit headers to the response, if any
                            return {
                                response with
                                headers = Array.concat(
                                    response.headers,
                                    responseHeaders,
                                );
                            };
                        };

                        response;
                    };
                };
            };
        };
    };

};
