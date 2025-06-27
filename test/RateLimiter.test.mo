import { test; suite } "mo:test";
import Blob "mo:new-base/Blob";
import Nat "mo:new-base/Nat";
import Text "mo:new-base/Text";
import Runtime "mo:new-base/Runtime";
import RateLimiterMiddleware "../src/Middleware/RateLimiter";
import HttpContext "../src/HttpContext";
import HttpMethod "../src/HttpMethod";
import Identity "../src/Identity";
import RateLimiter "../src/RateLimiter";
import ContentNegotiation "../src/ContentNegotiation";
import Logging "../src/Logging";

// Helper function to find header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
};

// Helper to create context with default error serializer
func createContext(
    method : HttpMethod.HttpMethod,
    url : Text,
    headers : [(Text, Text)],
    identity : ?Identity.Identity,
) : HttpContext.HttpContext {
    let context = HttpContext.HttpContext(
        {
            method = HttpMethod.toText(method);
            url = url;
            headers = headers;
            body = Blob.fromArray([]);
        },
        null,
        {
            errorSerializer = func(error : HttpContext.HttpError) : HttpContext.ErrorSerializerResponse {
                // Simple error serializer for testing
                let body = ?Text.encodeUtf8("Error: " # Nat.toText(error.statusCode));
                return {
                    headers = [("Content-Type", "text/plain")];
                    body = body;
                };
            };
            candidRepresentationNegotiator = func(
                candid : HttpContext.CandidValue,
                _ : ContentNegotiation.ContentPreference,
            ) : ?HttpContext.CandidNegotiatedContent {
                ?{
                    body = to_candid (candid);
                    contentType = "application/octet-stream";
                };
            };
            logger = Logging.buildDebugLogger(#warning);
        },
    );

    // Set identity if provided
    switch (identity) {
        case (?id) {
            context.setIdentity(id);
        };
        case (null) {};
    };

    return context;
};

// Helper to create a test identity
func createTestIdentity(id : Text, isAuth : Bool) : Identity.Identity {

    return {
        kind = #jwt({
            header = [];
            payload = [];
            signature = {
                algorithm = "none";
                message = "";
                value = "";
            };
        });
        getId = func() : ?Text = ?id;
        isAuthenticated = func() : Bool = isAuth;
    };
};

suite(
    "Rate Limit Middleware Tests",
    func() {

        test(
            "key extraction - IP address",
            func() {
                let config : RateLimiterMiddleware.Config = {
                    limit = 5;
                    windowSeconds = 60;
                    includeResponseHeaders = true;
                    limitExceededMessage = null;
                    keyExtractor = #ip;
                    skipIf = null;
                };

                let rateLimiter = RateLimiter.RateLimiter(config);

                // Create contexts with different IPs
                // Check responses have different rate limit counts (unique keys)
                let context1 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], null);
                let response1 = rateLimiter.check(context1);
                let #allowed({ responseHeaders = responseHeaders1 }) = response1 else Runtime.trap("Expected allowed response");
                assert (getHeader(responseHeaders1, "X-RateLimit-Remaining") == ?"4");

                let context2 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.2")], null);
                let response2 = rateLimiter.check(context2);
                let #allowed({ responseHeaders = responseHeaders2 }) = response2 else Runtime.trap("Expected allowed response");
                assert (getHeader(responseHeaders2, "X-RateLimit-Remaining") == ?"4");

                let context3 = createContext(#get, "/test", [("X-Real-IP", "10.0.0.1")], null);
                let response3 = rateLimiter.check(context3);
                let #allowed({ responseHeaders = responseHeaders3 }) = response3 else Runtime.trap("Expected allowed response");
                assert (getHeader(responseHeaders3, "X-RateLimit-Remaining") == ?"4");
            },
        );

        test(
            "key extraction - identity or IP",
            func() {
                let config : RateLimiterMiddleware.Config = {
                    limit = 5;
                    windowSeconds = 60;
                    includeResponseHeaders = true;
                    limitExceededMessage = null;
                    keyExtractor = #identityIdOrIp;
                    skipIf = null;
                };

                let rateLimiter = RateLimiter.RateLimiter(config);

                // Create contexts with different identities and IPs
                let identity1 = createTestIdentity("user1", true);
                let identity2 = createTestIdentity("user2", true);

                let context1 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], ?identity1);
                let context2 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], ?identity2);
                let context3 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], null);

                // Run middleware for each context
                let response1 = rateLimiter.check(context1);
                let response2 = rateLimiter.check(context2);
                let response3 = rateLimiter.check(context3);

                let #allowed({ responseHeaders = responseHeaders1 }) = response1 else Runtime.trap("Expected allowed response");
                let #allowed({ responseHeaders = responseHeaders2 }) = response2 else Runtime.trap("Expected allowed response");
                let #allowed({ responseHeaders = responseHeaders3 }) = response3 else Runtime.trap("Expected allowed response");

                // Check responses have unique rate limit counts
                // Each context should have a different key ("user1", "user2", or IP)
                assert (getHeader(responseHeaders1, "X-RateLimit-Remaining") == ?"4");
                assert (getHeader(responseHeaders2, "X-RateLimit-Remaining") == ?"4");
                assert (getHeader(responseHeaders3, "X-RateLimit-Remaining") == ?"4");

            },
        );

        test(
            "key extraction - custom function",
            func() {
                // Custom function that uses the URL path as key
                let customKeyExtractor = func(ctx : HttpContext.HttpContext) : Text {
                    let url = ctx.request.url;
                    return url;
                };

                let config : RateLimiterMiddleware.Config = {
                    limit = 5;
                    windowSeconds = 60;
                    includeResponseHeaders = true;
                    limitExceededMessage = null;
                    keyExtractor = #custom(customKeyExtractor);
                    skipIf = null;
                };

                let rateLimiter = RateLimiter.RateLimiter(config);

                // Create contexts with different URLs
                let context1 = createContext(#get, "/path1", [], null);
                let context2 = createContext(#get, "/path2", [], null);
                let context3 = createContext(#get, "/path1", [], null); // Same as context1

                // Run middleware for each context
                let response1 = rateLimiter.check(context1);
                let response2 = rateLimiter.check(context2);
                let response3 = rateLimiter.check(context3);

                // Extract rate limit headers

                let #allowed({ responseHeaders = responseHeaders1 }) = response1 else Runtime.trap("Expected allowed response");
                let #allowed({ responseHeaders = responseHeaders2 }) = response2 else Runtime.trap("Expected allowed response");
                let #allowed({ responseHeaders = responseHeaders3 }) = response3 else Runtime.trap("Expected allowed response");

                // First and third requests should affect the same counter (same path)
                // Second request should have its own counter
                assert (getHeader(responseHeaders1, "X-RateLimit-Remaining") == ?"4");
                assert (getHeader(responseHeaders2, "X-RateLimit-Remaining") == ?"4");
                assert (getHeader(responseHeaders3, "X-RateLimit-Remaining") == ?"3"); // One less because it's the same key as context1

            },
        );

        test(
            "skip rate limiting function",
            func() {
                // Skip rate limiting for requests with a specific header
                let skipFunction = func(ctx : HttpContext.HttpContext) : Bool {
                    switch (ctx.getHeader("X-Skip-Rate-Limit")) {
                        case (?"true") true;
                        case (_) false;
                    };
                };

                let config : RateLimiterMiddleware.Config = {
                    limit = 2; // Low limit for testing
                    windowSeconds = 60;
                    includeResponseHeaders = true;
                    limitExceededMessage = null;
                    keyExtractor = #ip;
                    skipIf = ?skipFunction;
                };

                let rateLimiter = RateLimiter.RateLimiter(config);

                // Create contexts with the same IP but different skip headers
                let context1 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], null);
                let context2 = createContext(
                    #get,
                    "/test",
                    [
                        ("X-Forwarded-For", "192.168.1.1"),
                        ("X-Skip-Rate-Limit", "true"),
                    ],
                    null,
                );
                let context3 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], null);

                // First request - normal
                let response1 = rateLimiter.check(context1);
                // Second request - should be skipped from rate limiting
                let response2 = rateLimiter.check(context2);
                // Third request - should be counted as the second request for this IP
                let response3 = rateLimiter.check(context3);

                let #allowed({ responseHeaders = responseHeaders1 }) = response1 else Runtime.trap("Expected allowed response");
                let #skipped = response2 else Runtime.trap("Expected skipped response");
                let #allowed({ responseHeaders = responseHeaders3 }) = response3 else Runtime.trap("Expected allowed response");

                assert (getHeader(responseHeaders1, "X-RateLimit-Remaining") == ?"1");
                assert (getHeader(responseHeaders3, "X-RateLimit-Limit") == ?"2");
            },
        );

        test(
            "rate limit exceeded",
            func() {
                let config : RateLimiterMiddleware.Config = {
                    limit = 2; // Low limit to easily test exceeding
                    windowSeconds = 60;
                    includeResponseHeaders = true;
                    limitExceededMessage = ?"Custom rate limit exceeded message";
                    keyExtractor = #ip;
                    skipIf = null;
                };

                let rateLimiter = RateLimiter.RateLimiter(config);

                // Create three contexts with the same IP to exceed the limit
                let context1 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], null);
                let context2 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], null);
                let context3 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], null);

                // First two requests should succeed
                let response1 = rateLimiter.check(context1);
                let response2 = rateLimiter.check(context2);
                // Third request should be rate limited
                let response3 = rateLimiter.check(context3);

                // Check status codes
                let #allowed({ responseHeaders = responseHeaders1 }) = response1 else Runtime.trap("Expected allowed response");
                let #allowed({ responseHeaders = responseHeaders2 }) = response2 else Runtime.trap("Expected allowed response");
                let #limited(limitedResponse3) = response3 else Runtime.trap("Expected limited response");

                assert (getHeader(responseHeaders1, "X-RateLimit-Limit") == ?"2");
                assert (getHeader(responseHeaders1, "X-RateLimit-Remaining") == ?"1");
                assert (getHeader(responseHeaders2, "X-RateLimit-Limit") == ?"2");
                assert (getHeader(responseHeaders2, "X-RateLimit-Remaining") == ?"0");
                assert (getHeader(limitedResponse3.headers, "X-RateLimit-Limit") == ?"2");
                assert (getHeader(limitedResponse3.headers, "X-RateLimit-Remaining") == ?"0");
                assert (getHeader(limitedResponse3.headers, "Retry-After") != null);
                assert (limitedResponse3.statusCode == 429); // Rate limit exceeded
            },
        );

        test(
            "response headers configuration",
            func() {
                // Test with headers disabled
                let config1 : RateLimiterMiddleware.Config = {
                    limit = 3;
                    windowSeconds = 60;
                    includeResponseHeaders = false;
                    limitExceededMessage = null;
                    keyExtractor = #ip;
                    skipIf = null;
                };

                let rateLimiter1 = RateLimiter.RateLimiter(config1);
                let context = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], null);
                let response = rateLimiter1.check(context);

                // Headers should not be included
                let #allowed({ responseHeaders = responseHeaders }) = response else Runtime.trap("Expected allowed response");
                assert (getHeader(responseHeaders, "X-RateLimit-Limit") == null);
                assert (getHeader(responseHeaders, "X-RateLimit-Remaining") == null);
                assert (getHeader(responseHeaders, "X-RateLimit-Reset") == null);

                // Test with headers enabled
                let config2 : RateLimiterMiddleware.Config = {
                    limit = 3;
                    windowSeconds = 60;
                    includeResponseHeaders = true;
                    limitExceededMessage = null;
                    keyExtractor = #ip;
                    skipIf = null;
                };

                let rateLimiter2 = RateLimiter.RateLimiter(config2);
                let response2 = rateLimiter2.check(context);
                let #allowed({ responseHeaders = responseHeaders2 }) = response2 else Runtime.trap("Expected allowed response");
                // Headers should be included
                assert (getHeader(responseHeaders2, "X-RateLimit-Limit") == ?"3");
                assert (getHeader(responseHeaders2, "X-RateLimit-Remaining") == ?"2");
                assert (getHeader(responseHeaders2, "X-RateLimit-Reset") != null);
            },
        );

        test(
            "custom error message",
            func() {
                // Config with custom message
                let config1 : RateLimiterMiddleware.Config = {
                    limit = 1;
                    windowSeconds = 60;
                    includeResponseHeaders = true;
                    limitExceededMessage = ?"My custom error message";
                    keyExtractor = #ip;
                    skipIf = null;
                };

                let rateLimiter1 = RateLimiter.RateLimiter(config1);
                let context = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.1")], null);

                // First request succeeds
                let _ = rateLimiter1.check(context);
                // Second request gets limited
                let response = rateLimiter1.check(context);

                let #limited(limitedResponse) = response else Runtime.trap("Expected limited response");

                assert (limitedResponse.statusCode == 429);

                // Config with no message (should use default)
                let config2 : RateLimiterMiddleware.Config = {
                    limit = 1;
                    windowSeconds = 60;
                    includeResponseHeaders = true;
                    limitExceededMessage = null;
                    keyExtractor = #ip;
                    skipIf = null;
                };

                let rateLimiter2 = RateLimiter.RateLimiter(config2);
                let context2 = createContext(#get, "/test", [("X-Forwarded-For", "192.168.1.2")], null);

                // First request succeeds
                let _ = rateLimiter2.check(context2);
                // Second request gets limited
                let response2 = rateLimiter2.check(context2);

                let #limited(limitedResponse2) = response2 else Runtime.trap("Expected limited response");

                assert (limitedResponse2.statusCode == 429);
            },
        );
    },
);
