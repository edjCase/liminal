import Text "mo:new-base/Text";
import Nat "mo:new-base/Nat";
import Time "mo:new-base/Time";
import Map "mo:new-base/Map";
import Iter "mo:new-base/Iter";
import Int "mo:new-base/Int";
import Option "mo:new-base/Option";
import Buffer "mo:base/Buffer";
import HttpContext "HttpContext";
import App "App";

module {
    // Configuration for rate limiting
    public type Config = {
        // The maximum number of requests allowed in the window
        limit : Nat;

        // The time window in seconds
        windowSeconds : Nat;

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

    public type CheckResult = {
        #limited : App.HttpResponse;
        #allowed : {
            responseHeaders : [(Text, Text)];
        };
        #skipped;
    };

    /// Rate limiter class for tracking and enforcing request rate limits.
    /// Maintains an in-memory store of request counters with automatic cleanup of expired entries.
    /// Supports flexible key extraction strategies and configurable limits and time windows.
    ///
    /// ```motoko
    /// let config = {
    ///     limit = 100; // 100 requests
    ///     windowSeconds = 3600; // per hour
    ///     includeResponseHeaders = true;
    ///     limitExceededMessage = ?"Rate limit exceeded";
    ///     keyExtractor = #identityIdOrIp; // Rate limit by user ID or IP
    ///     skipIf = null; // No skip conditions
    /// };
    ///
    /// let rateLimiter = RateLimiter.RateLimiter(config);
    ///
    /// // In middleware or handler
    /// switch (rateLimiter.check(httpContext)) {
    ///     case (#allowed({ responseHeaders })) {
    ///         // Continue processing, add headers to response
    ///     };
    ///     case (#limited(response)) {
    ///         // Return rate limit error response
    ///         return response;
    ///     };
    ///     case (#skipped) {
    ///         // Rate limiting was skipped
    ///     };
    /// };
    /// ```
    public class RateLimiter(config : Config) {
        // Store for tracking rate limit data
        let rateLimitStore = Map.empty<Text, RateLimitData>();

        var lastCleanup : Int = Time.now();

        /// Checks if the current request should be rate limited and updates counters.
        /// Returns the result of rate limit evaluation: allowed, limited, or skipped.
        /// Automatically handles cleanup of expired rate limit data.
        ///
        /// ```motoko
        /// let rateLimiter = RateLimiter.RateLimiter(config);
        /// switch (rateLimiter.check(httpContext)) {
        ///     case (#allowed({ responseHeaders })) {
        ///         // Request is allowed, responseHeaders contain rate limit info
        ///     };
        ///     case (#limited(response)) {
        ///         // Request is rate limited, return the response
        ///         return response;
        ///     };
        ///     case (#skipped) {
        ///         // Rate limiting was skipped for this request
        ///     };
        /// };
        /// ```
        public func check(context : HttpContext.HttpContext) : CheckResult {
            // Check if we should skip rate limiting
            switch (config.skipIf) {
                case (?skipFn) {
                    if (skipFn(context)) {
                        context.log(#debug_, "Rate limiting skipped for request");
                        return #skipped; // Skip rate limiting
                    };
                };
                case (null) {};
            };

            let key = switch (config.keyExtractor) {
                case (#ip) ipKeyExtractor(context);
                case (#identityIdOrIp) userOrIpKeyExtractor(context);
                case (#custom(extractor)) extractor(context);
            };

            context.log(#verbose, "Rate limiting check for key: " # key);

            let now = Time.now();
            let windowNanos = config.windowSeconds * 1_000_000_000; // Convert seconds to nanoseconds

            if (now - lastCleanup > 60_000_000_000) {
                // Cleanup every minute
                context.log(#debug_, "Performing rate limiter cleanup of expired entries");
                cleanupExpiredEntries();
                lastCleanup := now;
            };

            // Get or create rate limit data for this key
            let newStoreData : RateLimitData = switch (Map.get(rateLimitStore, Text.compare, key)) {
                case (?existingData) {
                    // If window has expired, reset the counter
                    if (existingData.resetAt < now) {
                        context.log(#debug_, "Rate limit window expired for key: " # key # ", resetting counter");
                        {
                            count = 1;
                            resetAt = now + windowNanos;
                        };
                    } else {
                        context.log(#verbose, "Incrementing rate limit counter for key: " # key # " (count: " # Nat.toText(existingData.count + 1) # "/" # Nat.toText(config.limit) # ")");
                        // Increment the counter
                        {
                            count = existingData.count + 1;
                            resetAt = existingData.resetAt;
                        };
                    };
                };
                case (null) {
                    context.log(#debug_, "First request for rate limit key: " # key);
                    // First request for this key
                    {
                        count = 1;
                        resetAt = now + windowNanos;
                    };
                };
            };

            // Update the store
            Map.add(rateLimitStore, Text.compare, key, newStoreData);
            // Calculate remaining requests

            let secondsUntilReset = (newStoreData.resetAt - now) / 1_000_000_000;
            let retryAfter = Int.abs(Int.max(1, secondsUntilReset)); // Ensure at least 1 second
            // Check if rate limit is exceeded
            if (newStoreData.count > config.limit) {
                context.log(#warning, "Rate limit exceeded for key: " # key # " (" # Nat.toText(newStoreData.count) # "/" # Nat.toText(config.limit) # ")");

                let message = Option.get(config.limitExceededMessage, "Rate limit exceeded");
                let { body; headers = errorHeaders } = context.errorSerializer({
                    statusCode = 429;
                    data = #message(message);
                });
                let headers = if (config.includeResponseHeaders) {
                    let headers = getHeaders(config.limit, 0, newStoreData.resetAt);
                    headers.add(("Retry-After", Int.toText(retryAfter)));

                    for (errorHeader in errorHeaders.vals()) {
                        headers.add(errorHeader);
                    };
                    Buffer.toArray(headers);

                } else errorHeaders;

                // Return rate limit exceeded response
                return #limited({
                    statusCode = 429;
                    headers = headers;
                    body = body;
                    streamingStrategy = null;
                });

            };
            let remaining : Nat = config.limit - newStoreData.count;

            context.log(#debug_, "Rate limit check passed for key: " # key # " (remaining: " # Nat.toText(remaining) # "/" # Nat.toText(config.limit) # ")");

            let responseHeaders = if (config.includeResponseHeaders) {
                Buffer.toArray(getHeaders(config.limit, remaining, newStoreData.resetAt));
            } else [];
            // Rate limit not exceeded
            return #allowed({
                responseHeaders = responseHeaders;
            });

        };

        // Cleanup function to remove expired entries
        func cleanupExpiredEntries() {
            let now = Time.now();
            let expiredKeys = Map.keys(rateLimitStore)
            |> Iter.filter(
                _,
                func(key : Text) : Bool {
                    switch (Map.get(rateLimitStore, Text.compare, key)) {
                        case (?data) {
                            return data.resetAt < now;
                        };
                        case (null) {
                            return true;
                        };
                    };
                },
            )
            |> Iter.toArray(_);

            for (key in expiredKeys.vals()) {
                ignore Map.delete(rateLimitStore, Text.compare, key);
            };
        };
    };

    // Internal tracking of rate limit data
    private type RateLimitData = {
        count : Nat;
        resetAt : Time.Time; // Timestamp in nanoseconds
    };

    func getHeaders(limit : Nat, remaining : Nat, resetAt : Int) : Buffer.Buffer<(Text, Text)> {
        let headers = Buffer.Buffer<(Text, Text)>(6);
        headers.add(("X-RateLimit-Limit", Nat.toText(limit)));
        headers.add(("X-RateLimit-Remaining", Nat.toText(remaining)));
        headers.add(("X-RateLimit-Reset", Int.toText(resetAt / 1_000_000_000))); // Convert to seconds
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
