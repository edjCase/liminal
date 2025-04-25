import RateLimiter "../RateLimiter";
import HttpContext "../HttpContext";
import App "../App";
import Array "mo:new-base/Array";
module {

    public type Config = RateLimiter.Config;
    public func new(config : Config) : App.Middleware {
        let rateLimiter = RateLimiter.RateLimiter(config);

        {
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                // Can't store rate limiting info in the query and queries aren't the bottle neck
                next();
            };

            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                switch (rateLimiter.check(context)) {
                    case (#skipped) await* next();
                    case (#limited(response)) response;
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
