import Text "mo:new-base/Text";
import Nat "mo:new-base/Nat";
import Time "mo:new-base/Time";
import Map "mo:new-base/Map";
import Iter "mo:new-base/Iter";
import Int "mo:new-base/Int";

module {
    // Configuration for rate limiting
    public type Config = {
        // The maximum number of requests allowed in the window
        limit : Nat;

        // The time window in seconds
        windowSeconds : Nat;
    };

    public type AllowedData = {
        limit : Nat;
        remaining : Nat;
        resetAt : Time.Time; // Timestamp in nanoseconds
    };

    public type RateLimitedData = AllowedData and {
        retryAfter : Nat; // Retry after in seconds
    };

    public type CheckResult = {
        #limited : RateLimitedData;
        #allowed : AllowedData;
    };

    // Create a new rate limiter middleware
    public class RateLimiter(config : Config) {
        // Store for tracking rate limit data
        let rateLimitStore = Map.empty<Text, RateLimitData>();

        var lastCleanup : Int = Time.now();

        // Function to check rate limit and update counter
        public func check(key : Text) : CheckResult {

            let now = Time.now();
            let windowNanos = config.windowSeconds * 1_000_000_000; // Convert seconds to nanoseconds

            if (now - lastCleanup > 60_000_000_000) {
                // Cleanup every minute
                cleanupExpiredEntries();
                lastCleanup := now;
            };

            // Get or create rate limit data for this key
            let newStoreData : RateLimitData = switch (Map.get(rateLimitStore, Text.compare, key)) {
                case (?existingData) {
                    // If window has expired, reset the counter
                    if (existingData.resetAt < now) {
                        {
                            count = 1;
                            resetAt = now + windowNanos;
                        };
                    } else {
                        // Increment the counter
                        {
                            count = existingData.count + 1;
                            resetAt = existingData.resetAt;
                        };
                    };
                };
                case (null) {
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
            let remaining : Nat = if (newStoreData.count >= config.limit) 0 else config.limit - newStoreData.count;

            let secondsUntilReset = (newStoreData.resetAt - now) / 1_000_000_000;
            let retryAfter = Int.abs(Int.max(1, secondsUntilReset)); // Ensure at least 1 second
            // Check if rate limit is exceeded
            if (remaining == 0) {
                return #limited({
                    limit = config.limit;
                    remaining = remaining;
                    resetAt = newStoreData.resetAt;
                    retryAfter = retryAfter; // Ensure at least 1 second
                })

            };

            // Rate limit not exceeded
            return #allowed({
                limit = config.limit;
                remaining = remaining;
                resetAt = newStoreData.resetAt;
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

};
