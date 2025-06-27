import { test } "mo:test/async";
import Text "mo:new-base/Text";
import Blob "mo:new-base/Blob";
import Nat16 "mo:new-base/Nat16";
import Nat "mo:new-base/Nat";
import Runtime "mo:new-base/Runtime";

import Liminal "../src/lib";
import RateLimiterMiddleware "../src/Middleware/RateLimiter";
import RouterMiddleware "../src/Middleware/Router";
import Router "../src/Router";
import HttpMethod "../src/HttpMethod";
import Identity "../src/Identity";
import HttpContext "../src/HttpContext";
import App "../src/App";

// Helper function to find header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
};

// Helper to create HTTP request
func createRequest(
    method : HttpMethod.HttpMethod,
    url : Text,
    headers : [(Text, Text)],
    body : Blob,
) : Liminal.RawQueryHttpRequest {
    {
        method = HttpMethod.toText(method);
        url = url;
        headers = headers;
        body = body;
        certificate_version = null;
    };
};

// Helper functions for testing assertions
func assertStatusCode(actual : Nat16, expected : Nat) : () {
    let actualNat = Nat16.toNat(actual);
    if (actualNat != expected) {
        Runtime.trap("Status Code check failed\nExpected: " # Nat.toText(expected) # "\nActual: " # Nat.toText(actualNat));
    };
};

func assertHeaderExists(headers : [(Text, Text)], key : Text, message : Text) : Text {
    switch (getHeader(headers, key)) {
        case (?value) value;
        case (null) Runtime.trap(message # " - Expected header '" # key # "' but was not found");
    };
};

func assertHeaderValue(headers : [(Text, Text)], key : Text, expectedValue : Text, message : Text) : () {
    let actualValue = assertHeaderExists(headers, key, message);
    if (actualValue != expectedValue) {
        Runtime.trap(message # "\nExpected: '" # expectedValue # "'\nActual: '" # actualValue # "'");
    };
};

// Test 1: Basic rate limiting with IP-based key
await test(
    "should allow requests within rate limit",
    func() : async () {
        let rateLimitConfig = {
            limit = 3;
            windowSeconds = 60;
            includeResponseHeaders = true;
            limitExceededMessage = null;
            keyExtractor = #ip;
            skipIf = null;
        };

        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/test",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"Success";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        let app = Liminal.App({
            middleware = [
                RateLimiterMiddleware.new(rateLimitConfig),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        // First request should be allowed
        let request1 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response1 = await* app.http_request_update(request1);
        assertStatusCode(response1.status_code, 200);
        assertHeaderValue(response1.headers, "X-RateLimit-Limit", "3", "Rate limit header");
        assertHeaderValue(response1.headers, "X-RateLimit-Remaining", "2", "Remaining requests header");

        // Second request should be allowed
        let request2 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response2 = await* app.http_request_update(request2);
        assertStatusCode(response2.status_code, 200);
        assertHeaderValue(response2.headers, "X-RateLimit-Remaining", "1", "Remaining requests header");

        // Third request should be allowed
        let request3 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response3 = await* app.http_request_update(request3);
        assertStatusCode(response3.status_code, 200);
        assertHeaderValue(response3.headers, "X-RateLimit-Remaining", "0", "Remaining requests header");
    },
);

// Test 2: Rate limit exceeded
await test(
    "should block requests when rate limit exceeded",
    func() : async () {
        let rateLimitConfig = {
            limit = 2;
            windowSeconds = 60;
            includeResponseHeaders = true;
            limitExceededMessage = ?"Rate limit exceeded";
            keyExtractor = #ip;
            skipIf = null;
        };

        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/test",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"Success";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        let app = Liminal.App({
            middleware = [
                RateLimiterMiddleware.new(rateLimitConfig),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        // First two requests should be allowed
        let request1 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response1 = await* app.http_request_update(request1);
        assertStatusCode(response1.status_code, 200);

        let request2 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response2 = await* app.http_request_update(request2);
        assertStatusCode(response2.status_code, 200);

        // Third request should be blocked
        let request3 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response3 = await* app.http_request_update(request3);
        assertStatusCode(response3.status_code, 429);

        // Check that rate limit headers are still present
        let _ = assertHeaderExists(response3.headers, "X-RateLimit-Limit", "Rate limit header should exist");
        let _ = assertHeaderExists(response3.headers, "X-RateLimit-Remaining", "Remaining requests header should exist");
    },
);

// Test 3: Different IPs have separate rate limits
await test(
    "should track rate limits separately for different IPs",
    func() : async () {
        let rateLimitConfig = {
            limit = 2;
            windowSeconds = 60;
            includeResponseHeaders = true;
            limitExceededMessage = null;
            keyExtractor = #ip;
            skipIf = null;
        };

        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/test",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"Success";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        let app = Liminal.App({
            middleware = [
                RateLimiterMiddleware.new(rateLimitConfig),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        // Exhaust rate limit for first IP
        let request1a = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response1a = await* app.http_request_update(request1a);
        assertStatusCode(response1a.status_code, 200);

        let request1b = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response1b = await* app.http_request_update(request1b);
        assertStatusCode(response1b.status_code, 200);

        let request1c = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response1c = await* app.http_request_update(request1c);
        assertStatusCode(response1c.status_code, 429);

        // Second IP should still be allowed
        let request2a = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.2")],
            Blob.fromArray([]),
        );
        let response2a = await* app.http_request_update(request2a);
        assertStatusCode(response2a.status_code, 200);
        assertHeaderValue(response2a.headers, "X-RateLimit-Remaining", "1", "Second IP should have fresh rate limit");
    },
);

// Test 4: Skip function bypasses rate limiting
await test(
    "should skip rate limiting when skip function returns true",
    func() : async () {
        let skipFunction = func(context : HttpContext.HttpContext) : Bool {
            // Skip rate limiting for requests with special header
            switch (getHeader(context.request.headers, "X-Skip-Rate-Limit")) {
                case (?"true") true;
                case (_) false;
            };
        };

        let rateLimitConfig = {
            limit = 1;
            windowSeconds = 60;
            includeResponseHeaders = true;
            limitExceededMessage = null;
            keyExtractor = #ip;
            skipIf = ?skipFunction;
        };

        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/test",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"Success";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        let app = Liminal.App({
            middleware = [
                RateLimiterMiddleware.new(rateLimitConfig),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        // First request exhausts the rate limit
        let request1 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response1 = await* app.http_request_update(request1);
        assertStatusCode(response1.status_code, 200);

        // Second request would normally be blocked
        let request2 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response2 = await* app.http_request_update(request2);
        assertStatusCode(response2.status_code, 429);

        // Third request with skip header should be allowed
        let request3 = createRequest(
            #get,
            "/test",
            [
                ("X-Forwarded-For", "192.168.1.1"),
                ("X-Skip-Rate-Limit", "true"),
            ],
            Blob.fromArray([]),
        );
        let response3 = await* app.http_request_update(request3);
        assertStatusCode(response3.status_code, 200);
    },
);

// Test 5: Identity-based rate limiting
await test(
    "should use identity ID for rate limiting when authenticated",
    func() : async () {
        let rateLimitConfig = {
            limit = 2;
            windowSeconds = 60;
            includeResponseHeaders = true;
            limitExceededMessage = null;
            keyExtractor = #identityIdOrIp;
            skipIf = null;
        };

        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/test",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"Success";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        let app = Liminal.App({
            middleware = [
                {
                    name = "Add Identity";
                    handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                        next();
                    };
                    handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                        // Simulate authenticated identity

                        // Set a test identity for this request
                        let testIdentity : Identity.Identity = {
                            kind = #jwt({
                                header = [];
                                payload = [];
                                signature = {
                                    algorithm = "none";
                                    message = "";
                                    value = "";
                                };
                            });
                            getId = func() : ?Text = ?"user123";
                            isAuthenticated = func() : Bool = true;
                        };
                        context.setIdentity(testIdentity);
                        await* next();
                    };
                },
                RateLimiterMiddleware.new(rateLimitConfig),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        // First request should be allowed
        let request1 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response1 = await* app.http_request_update(request1);
        assertStatusCode(response1.status_code, 200);

        // Second request from different IP but same identity should share rate limit
        let request2 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.2")],
            Blob.fromArray([]),
        );
        let response2 = await* app.http_request_update(request2);
        assertStatusCode(response2.status_code, 200);

        // Third request should be blocked as identity rate limit is exhausted
        let request3 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.3")],
            Blob.fromArray([]),
        );
        let response3 = await* app.http_request_update(request3);
        assertStatusCode(response3.status_code, 429);
    },
);

// Test 6: Rate limiting applies only to update requests, not queries
await test(
    "should not rate limit query requests",
    func() : async () {
        let rateLimitConfig = {
            limit = 1;
            windowSeconds = 60;
            includeResponseHeaders = true;
            limitExceededMessage = null;
            keyExtractor = #ip;
            skipIf = null;
        };

        let app = Liminal.App({
            middleware = [RateLimiterMiddleware.new(rateLimitConfig)];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        // Multiple query requests should all be allowed regardless of rate limit
        let request1 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response1 = app.http_request(request1);
        assertStatusCode(response1.status_code, 404); // No route configured, but not rate limited

        let request2 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response2 = app.http_request(request2);
        assertStatusCode(response2.status_code, 404); // Still not rate limited

        let request3 = createRequest(
            #get,
            "/test",
            [("X-Forwarded-For", "192.168.1.1")],
            Blob.fromArray([]),
        );
        let response3 = app.http_request(request3);
        assertStatusCode(response3.status_code, 404); // Still not rate limited
    },
);
