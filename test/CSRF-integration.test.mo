import { test } "mo:test/async";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Blob "mo:new-base/Blob";
import Runtime "mo:new-base/Runtime";
import Nat "mo:new-base/Nat";
import Nat16 "mo:new-base/Nat16";
import Liminal "../src/lib";
import CSRFMiddleware "../src/Middleware/CSRF";
import RouterMiddleware "../src/Middleware/Router";
import Router "../src/Router";
import HttpMethod "../src/HttpMethod";
import Int "mo:new-base/Int";
import Time "mo:new-base/Time";

// Helper functions for testing assertions
func assertStatusCode(actual : Nat16, expected : Nat) : () {
    let actualNat = Nat16.toNat(actual);
    if (actualNat != expected) {
        Runtime.trap("Status Code check failed\nExpected: " # Nat.toText(expected) # "\nActual: " # Nat.toText(actualNat));
    };
};

func assertArrayContains(headers : [(Text, Text)], expectedName : Text, expectedValue : Text, message : Text) : () {
    if (expectedValue == "") {
        // Just check if header exists
        let found = Array.any<(Text, Text)>(
            headers,
            func((name, value)) {
                name == expectedName;
            },
        );
        if (not found) {
            let headersList = Text.join("; ", Array.map<(Text, Text), Text>(headers, func((n, v)) { n # "=" # v }).vals());
            Runtime.trap(message # "\nExpected header: " # expectedName # " (any value)\nHeaders found: " # headersList);
        };
    } else {
        // Check for specific header value
        let found = Array.any<(Text, Text)>(
            headers,
            func((name, value)) {
                name == expectedName and value == expectedValue;
            },
        );
        if (not found) {
            let headerPairs = Array.map<(Text, Text), Text>(headers, func((n, v)) { n # "=" # v });
            let headersList = Text.join("; ", headerPairs.vals());
            Runtime.trap(message # "\nExpected header: " # expectedName # "=" # expectedValue # "\nHeaders found: " # headersList);
        };
    };
};

func createToken(timestamp : Int, suffix : Text) : Text {
    let base = Int.toText(timestamp);
    return base # "-" # suffix;
};

// Mock token storage for testing
class MockTokenStorage() {
    private var token : ?Text = null;

    public func get() : ?Text {
        token;
    };

    public func set(newToken : Text) : () {
        token := ?newToken;
    };

    public func clear() : () {
        token := null;
    };
};

// Helper to create a basic app with CSRF middleware
func createAppWithCSRF(csrfConfig : ?CSRFMiddleware.Config) : (Liminal.App, MockTokenStorage) {
    let tokenStorage = MockTokenStorage();

    let config = switch (csrfConfig) {
        case (?cfg) cfg;
        case (null) CSRFMiddleware.defaultConfig({
            get = tokenStorage.get;
            set = tokenStorage.set;
            clear = tokenStorage.clear;
        });
    };

    let routerConfig : RouterMiddleware.Config = {
        prefix = null;
        identityRequirement = null;
        routes = [
            Router.getQuery(
                "/",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "text/html")];
                        body = ?"<html><body>Home Page</body></html>";
                        streamingStrategy = null;
                    };
                },
            ),
            Router.getQuery(
                "/form",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "text/html")];
                        body = ?"<html><body><form><input type='submit'/></form></body></html>";
                        streamingStrategy = null;
                    };
                },
            ),
            Router.postQuery(
                "/submit",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "application/json")];
                        body = ?"{\"success\": true}";
                        streamingStrategy = null;
                    };
                },
            ),
            Router.putQuery(
                "/update",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "application/json")];
                        body = ?"{\"updated\": true}";
                        streamingStrategy = null;
                    };
                },
            ),
            Router.deleteQuery(
                "/delete",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "application/json")];
                        body = ?"{\"deleted\": true}";
                        streamingStrategy = null;
                    };
                },
            ),
            Router.patchQuery(
                "/update",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "application/json")];
                        body = ?"{\"patched\": true}";
                        streamingStrategy = null;
                    };
                },
            ),
            Router.getQuery(
                "/api/public",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "application/json")];
                        body = ?"{\"public\": true}";
                        streamingStrategy = null;
                    };
                },
            ),
        ];
    };

    let app = Liminal.App({
        middleware = [
            CSRFMiddleware.new(config),
            RouterMiddleware.new(routerConfig),
        ];
        errorSerializer = Liminal.defaultJsonErrorSerializer;
        candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
        logger = Liminal.buildDebugLogger(#warning);
    });

    (app, tokenStorage);
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

// Test 1: GET requests are allowed without CSRF token
await test(
    "should allow GET requests without CSRF token",
    func() : async () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #get,
            "/",
            [],
            Text.encodeUtf8(""),
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 2: POST requests are blocked without CSRF token
await test(
    "should block POST requests without CSRF token",
    func() : async () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #post,
            "/submit",
            [("Content-Type", "application/json")],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 3: PUT requests are blocked without CSRF token
await test(
    "should block PUT requests without CSRF token",
    func() : async () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #put,
            "/update",
            [("Content-Type", "application/json")],
            "{\"data\": \"updated\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 4: DELETE requests are blocked without CSRF token
await test(
    "should block DELETE requests without CSRF token",
    func() : async () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #delete,
            "/delete",
            [],
            "",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 5: POST request with valid CSRF token is allowed
await test(
    "should allow POST request with valid CSRF token",
    func() : async () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        let token = createToken(Time.now(), "abcd");
        // Set a token in storage
        tokenStorage.set(token);

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", token),
            ],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 6: POST request with invalid CSRF token is blocked
await test(
    "should block POST request with invalid CSRF token",
    func() : async () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        let token = createToken(Time.now(), "abcd");
        // Set a different token in storage
        tokenStorage.set(token);

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", createToken(Time.now(), "efgh")),
            ],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 7: Custom header name for CSRF token
await test(
    "should support custom header name for CSRF token",
    func() : async () {
        let tokenStorage = MockTokenStorage();
        let config = {
            CSRFMiddleware.defaultConfig({
                get = tokenStorage.get;
                set = tokenStorage.set;
                clear = tokenStorage.clear;
            }) with
            headerName = "X-Custom-CSRF-Token";
        };
        let (app, _) = createAppWithCSRF(?config);
        let token = createToken(Time.now(), "abcd");

        tokenStorage.set(token);

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-Custom-CSRF-Token", token),
            ],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 8: Exempt paths are not protected
await test(
    "should allow POST to exempt paths without CSRF token",
    func() : async () {
        let tokenStorage = MockTokenStorage();
        let config = {
            CSRFMiddleware.defaultConfig({
                get = tokenStorage.get;
                set = tokenStorage.set;
                clear = tokenStorage.clear;
            }) with
            exemptPaths = ["/submit"];
        };
        let (app, _) = createAppWithCSRF(?config);

        let request = createRequest(
            #post,
            "/submit",
            [("Content-Type", "application/json")],
            "{\"data\": \"public\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 9: Custom protected methods
await test(
    "should only protect specified HTTP methods",
    func() : async () {
        let tokenStorage = MockTokenStorage();
        let config = {
            CSRFMiddleware.defaultConfig({
                get = tokenStorage.get;
                set = tokenStorage.set;
                clear = tokenStorage.clear;
            }) with
            protectedMethods = [#post]; // Only POST is protected
        };
        let (app, _) = createAppWithCSRF(?config);

        // PUT should be allowed without token
        let putRequest = createRequest(
            #put,
            "/update",
            [("Content-Type", "application/json")],
            "{\"data\": \"updated\"}",
        );

        let putResponse = await* app.http_request_update(putRequest);
        assertStatusCode(putResponse.status_code, 200);

        // POST should still be blocked without token
        let postRequest = createRequest(
            #post,
            "/submit",
            [("Content-Type", "application/json")],
            "{\"data\": \"test\"}",
        );

        let postResponse = await* app.http_request_update(postRequest);
        assertStatusCode(postResponse.status_code, 403);
    },
);

// Test 10: Missing token in storage
await test(
    "should block request when token not found in storage",
    func() : async () {
        let (app, _) = createAppWithCSRF(null);
        // Don't set any token in storage

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", "some-token"),
            ],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 11: Token validation for different HTTP methods
await test(
    "should validate CSRF token for all protected methods",
    func() : async () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        let token = createToken(Time.now(), "abcd");
        tokenStorage.set(token);

        // Test POST
        let postRequest = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", token),
            ],
            "{\"data\": \"test\"}",
        );
        let postResponse = await* app.http_request_update(postRequest);
        assertStatusCode(postResponse.status_code, 200);

        // Test PUT
        let putRequest = createRequest(
            #put,
            "/update",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", token),
            ],
            "{\"data\": \"updated\"}",
        );
        let putResponse = await* app.http_request_update(putRequest);
        assertStatusCode(putResponse.status_code, 200);

        // Test DELETE
        let deleteRequest = createRequest(
            #delete,
            "/delete",
            [("X-CSRF-Token", token)],
            "",
        );
        let deleteResponse = await* app.http_request_update(deleteRequest);
        assertStatusCode(deleteResponse.status_code, 200);
    },
);

// Test 12: Empty CSRF token header
await test(
    "should block request with empty CSRF token header",
    func() : async () {
        let (app, tokenStorage) = createAppWithCSRF(null);
        let token = createToken(Time.now(), "abcd");
        tokenStorage.set(token);

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", ""),
            ],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 13: Case-sensitive token validation
await test(
    "should perform case-sensitive token validation",
    func() : async () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        let token = createToken(Time.now(), "abcd");
        tokenStorage.set(token);

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", createToken(Time.now(), "ABCD")), // Different case
            ],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 14: Multiple exempt paths
await test(
    "should handle multiple exempt paths",
    func() : async () {
        let tokenStorage = MockTokenStorage();
        let config = {
            CSRFMiddleware.defaultConfig({
                get = tokenStorage.get;
                set = tokenStorage.set;
                clear = tokenStorage.clear;
            }) with
            exemptPaths = ["/submit", "/webhooks"];
        };
        let (app, _) = createAppWithCSRF(?config);

        // Both paths should be exempt
        let request1 = createRequest(
            #post,
            "/submit",
            [("Content-Type", "application/json")],
            "{\"data\": \"public\"}",
        );
        let response1 = await* app.http_request_update(request1);
        assertStatusCode(response1.status_code, 200);
    },
);

// Test 15: Non-exempt path requires token
await test(
    "should require token for non-exempt paths",
    func() : async () {
        let tokenStorage = MockTokenStorage();
        let config = {
            CSRFMiddleware.defaultConfig({
                get = tokenStorage.get;
                set = tokenStorage.set;
                clear = tokenStorage.clear;
            }) with
            exemptPaths = ["/api/public"];
        };
        let (app, _) = createAppWithCSRF(?config);

        // This path is not exempt, so should require token
        let request = createRequest(
            #post,
            "/submit",
            [("Content-Type", "application/json")],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 16: Token storage integration
await test(
    "should properly integrate with token storage",
    func() : async () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        // Initially no token
        switch (tokenStorage.get()) {
            case (?_) Runtime.trap("Expected no token initially");
            case (null) {}; // Expected
        };

        let token = createToken(Time.now(), "abcd");
        // Set token and verify it's stored
        tokenStorage.set(token);
        switch (tokenStorage.get()) {
            case (?t) {
                if (t != token) {
                    Runtime.trap("Token not stored correctly");
                };
            };
            case (null) Runtime.trap("Token should be stored");
        };

        // Use the stored token in a request
        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", token),
            ],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);
        assertStatusCode(response.status_code, 200);
    },
);

// Test 17: PATCH method protection
await test(
    "should protect PATCH requests by default",
    func() : async () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #patch,
            "/update",
            [("Content-Type", "application/json")],
            "{\"data\": \"patched\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 18: Valid token for PATCH request
await test(
    "should allow PATCH request with valid CSRF token",
    func() : async () {
        let (app, tokenStorage) = createAppWithCSRF(null);
        let token = createToken(Time.now(), "abcd");
        tokenStorage.set(token);

        let request = createRequest(
            #patch,
            "/update",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", token),
            ],
            "{\"data\": \"patched\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 19: Request with wrong header name
await test(
    "should block request with token in wrong header",
    func() : async () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        let token = createToken(Time.now(), "abcd");
        tokenStorage.set(token);

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-Wrong-Header", token), // Wrong header name
            ],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 20: CSRF middleware preserves other response headers
await test(
    "should preserve response headers from downstream middleware",
    func() : async () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        let token = createToken(Time.now(), "abcd");
        tokenStorage.set(token);

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", token),
            ],
            "{\"data\": \"test\"}",
        );

        let response = await* app.http_request_update(request);

        assertStatusCode(response.status_code, 200);
        assertArrayContains(response.headers, "Content-Type", "application/json", "Should preserve Content-Type header");
    },
);
