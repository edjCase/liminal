import { test } "mo:test";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Blob "mo:new-base/Blob";
import Iter "mo:new-base/Iter";
import Runtime "mo:new-base/Runtime";
import Nat "mo:new-base/Nat";
import Nat16 "mo:new-base/Nat16";
import Liminal "../src/lib";
import CSRFMiddleware "../src/Middleware/CSRF";
import RouterMiddleware "../src/Middleware/Router";
import Router "../src/Router";
import HttpMethod "../src/HttpMethod";

// Helper functions for testing assertions
func assertStatusCode(actual : Nat16, expected : Nat) : () {
    let actualNat = Nat16.toNat(actual);
    if (actualNat != expected) {
        Runtime.trap("Status Code check failed\nExpected: " # Nat.toText(expected) # "\nActual: " # Nat.toText(actualNat));
    };
};

func assertOptionText(actual : ?Text, expectedContains : Text, message : Text) : () {
    switch (actual) {
        case (?text) {
            if (not Text.contains(text, #text(expectedContains))) {
                Runtime.trap(message # "\nExpected to contain: '" # expectedContains # "'\nActual: '" # text # "'");
            };
        };
        case (null) {
            Runtime.trap(message # "\nExpected header with content '" # expectedContains # "'\nbut header was null");
        };
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

// Helper function to find header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
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
test(
    "should allow GET requests without CSRF token",
    func() : () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 2: POST requests are blocked without CSRF token
test(
    "should block POST requests without CSRF token",
    func() : () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #post,
            "/submit",
            [("Content-Type", "application/json")],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 3: PUT requests are blocked without CSRF token
test(
    "should block PUT requests without CSRF token",
    func() : () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #put,
            "/update",
            [("Content-Type", "application/json")],
            "{\"data\": \"updated\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 4: DELETE requests are blocked without CSRF token
test(
    "should block DELETE requests without CSRF token",
    func() : () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #delete,
            "/delete",
            [],
            "",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 5: POST request with valid CSRF token is allowed
test(
    "should allow POST request with valid CSRF token",
    func() : () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        // Set a token in storage
        tokenStorage.set("valid-token-123");

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", "valid-token-123"),
            ],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 6: POST request with invalid CSRF token is blocked
test(
    "should block POST request with invalid CSRF token",
    func() : () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        // Set a different token in storage
        tokenStorage.set("valid-token-123");

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", "invalid-token-456"),
            ],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 7: Custom header name for CSRF token
test(
    "should support custom header name for CSRF token",
    func() : () {
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

        tokenStorage.set("custom-token-789");

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-Custom-CSRF-Token", "custom-token-789"),
            ],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 8: Exempt paths are not protected
test(
    "should allow POST to exempt paths without CSRF token",
    func() : () {
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

        let request = createRequest(
            #post,
            "/api/public",
            [("Content-Type", "application/json")],
            "{\"data\": \"public\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 9: Custom protected methods
test(
    "should only protect specified HTTP methods",
    func() : () {
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

        let putResponse = app.http_request(putRequest);
        assertStatusCode(putResponse.status_code, 200);

        // POST should still be blocked without token
        let postRequest = createRequest(
            #post,
            "/submit",
            [("Content-Type", "application/json")],
            "{\"data\": \"test\"}",
        );

        let postResponse = app.http_request(postRequest);
        assertStatusCode(postResponse.status_code, 403);
    },
);

// Test 10: Missing token in storage
test(
    "should block request when token not found in storage",
    func() : () {
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

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 11: Token validation for different HTTP methods
test(
    "should validate CSRF token for all protected methods",
    func() : () {
        let (app, tokenStorage) = createAppWithCSRF(null);
        tokenStorage.set("valid-token-123");

        // Test POST
        let postRequest = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", "valid-token-123"),
            ],
            "{\"data\": \"test\"}",
        );
        let postResponse = app.http_request(postRequest);
        assertStatusCode(postResponse.status_code, 200);

        // Test PUT
        let putRequest = createRequest(
            #put,
            "/update",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", "valid-token-123"),
            ],
            "{\"data\": \"updated\"}",
        );
        let putResponse = app.http_request(putRequest);
        assertStatusCode(putResponse.status_code, 200);

        // Test DELETE
        let deleteRequest = createRequest(
            #delete,
            "/delete",
            [("X-CSRF-Token", "valid-token-123")],
            "",
        );
        let deleteResponse = app.http_request(deleteRequest);
        assertStatusCode(deleteResponse.status_code, 200);
    },
);

// Test 12: Empty CSRF token header
test(
    "should block request with empty CSRF token header",
    func() : () {
        let (app, tokenStorage) = createAppWithCSRF(null);
        tokenStorage.set("valid-token-123");

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", ""),
            ],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 13: Case-sensitive token validation
test(
    "should perform case-sensitive token validation",
    func() : () {
        let (app, tokenStorage) = createAppWithCSRF(null);
        tokenStorage.set("ValidToken123");

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", "validtoken123"), // Different case
            ],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 14: Multiple exempt paths
test(
    "should handle multiple exempt paths",
    func() : () {
        let tokenStorage = MockTokenStorage();
        let config = {
            CSRFMiddleware.defaultConfig({
                get = tokenStorage.get;
                set = tokenStorage.set;
                clear = tokenStorage.clear;
            }) with
            exemptPaths = ["/api/public", "/webhooks"];
        };
        let (app, _) = createAppWithCSRF(?config);

        // Both paths should be exempt
        let request1 = createRequest(
            #post,
            "/api/public",
            [("Content-Type", "application/json")],
            "{\"data\": \"public\"}",
        );
        let response1 = app.http_request(request1);
        assertStatusCode(response1.status_code, 200);

        // Test with a path that matches the prefix
        let request2 = createRequest(
            #post,
            "/api/public/endpoint",
            [("Content-Type", "application/json")],
            "{\"data\": \"endpoint\"}",
        );
        let response2 = app.http_request(request2);
        assertStatusCode(response2.status_code, 200);
    },
);

// Test 15: Non-exempt path requires token
test(
    "should require token for non-exempt paths",
    func() : () {
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

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 16: Token storage integration
test(
    "should properly integrate with token storage",
    func() : () {
        let (app, tokenStorage) = createAppWithCSRF(null);

        // Initially no token
        switch (tokenStorage.get()) {
            case (?_) Runtime.trap("Expected no token initially");
            case (null) {}; // Expected
        };

        // Set token and verify it's stored
        tokenStorage.set("stored-token-456");
        switch (tokenStorage.get()) {
            case (?token) {
                if (token != "stored-token-456") {
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
                ("X-CSRF-Token", "stored-token-456"),
            ],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);
        assertStatusCode(response.status_code, 200);
    },
);

// Test 17: PATCH method protection
test(
    "should protect PATCH requests by default",
    func() : () {
        let (app, _) = createAppWithCSRF(null);

        let request = createRequest(
            #patch,
            "/update",
            [("Content-Type", "application/json")],
            "{\"data\": \"patched\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 18: Valid token for PATCH request
test(
    "should allow PATCH request with valid CSRF token",
    func() : () {
        let (app, tokenStorage) = createAppWithCSRF(null);
        tokenStorage.set("patch-token-789");

        let request = createRequest(
            #patch,
            "/update",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", "patch-token-789"),
            ],
            "{\"data\": \"patched\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 19: Request with wrong header name
test(
    "should block request with token in wrong header",
    func() : () {
        let (app, tokenStorage) = createAppWithCSRF(null);
        tokenStorage.set("correct-token");

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-Wrong-Header", "correct-token"), // Wrong header name
            ],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 20: CSRF middleware preserves other response headers
test(
    "should preserve response headers from downstream middleware",
    func() : () {
        let (app, tokenStorage) = createAppWithCSRF(null);
        tokenStorage.set("header-test-token");

        let request = createRequest(
            #post,
            "/submit",
            [
                ("Content-Type", "application/json"),
                ("X-CSRF-Token", "header-test-token"),
            ],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
        assertArrayContains(response.headers, "Content-Type", "application/json", "Should preserve Content-Type header");
    },
);
