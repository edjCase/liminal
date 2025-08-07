import { test } "mo:test/async";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Runtime "mo:core/Runtime";
import Nat "mo:core/Nat";
import Nat16 "mo:core/Nat16";
import Liminal "../src/lib";
import CSRFMiddleware "../src/Middleware/CSRF";
import RouterMiddleware "../src/Middleware/Router";
import Router "../src/Router";
import HttpMethod "../src/HttpMethod";
import Int "mo:core/Int";
import Time "mo:core/Time";

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

// ================================
// UPDATE CALL TESTS (EXISTING)
// ================================

// Test 1: GET requests are allowed without CSRF token
await test(
  "UPDATE: should allow GET requests without CSRF token",
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
  "UPDATE: should block POST requests without CSRF token",
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
  "UPDATE: should block PUT requests without CSRF token",
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
  "UPDATE: should block DELETE requests without CSRF token",
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
  "UPDATE: should allow POST request with valid CSRF token",
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
  "UPDATE: should block POST request with invalid CSRF token",
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
  "UPDATE: should support custom header name for CSRF token",
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
  "UPDATE: should allow POST to exempt paths without CSRF token",
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
  "UPDATE: should only protect specified HTTP methods",
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
  "UPDATE: should block request when token not found in storage",
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

// ================================
// QUERY CALL TESTS (NEW)
// ================================

// Test 11: Query - GET requests are allowed without CSRF token
await test(
  "QUERY: should allow GET requests without CSRF token",
  func() : async () {
    let (app, _) = createAppWithCSRF(null);

    let request = createRequest(
      #get,
      "/",
      [],
      Text.encodeUtf8(""),
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
  },
);

// Test 12: Query - POST requests are blocked without CSRF token
await test(
  "QUERY: should block POST requests without CSRF token",
  func() : async () {
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

// Test 13: Query - PUT requests are blocked without CSRF token
await test(
  "QUERY: should block PUT requests without CSRF token",
  func() : async () {
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

// Test 14: Query - DELETE requests are blocked without CSRF token
await test(
  "QUERY: should block DELETE requests without CSRF token",
  func() : async () {
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

// Test 15: Query - POST request with valid CSRF token (per-session rotation)
await test(
  "QUERY: should allow POST request with valid CSRF token and per-session rotation",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #perSession; // No token generation needed
    };
    let (app, _) = createAppWithCSRF(?config);

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

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
  },
);

// Test 16: Query - POST request with invalid CSRF token
await test(
  "QUERY: should block POST request with invalid CSRF token",
  func() : async () {
    let (app, tokenStorage) = createAppWithCSRF(null);

    let token = createToken(Time.now(), "abcd");
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

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 403);
  },
);

// Test 17: Query - Exempt paths are not protected
await test(
  "QUERY: should allow POST to exempt paths without CSRF token",
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

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
  },
);

// Test 18: Query - Custom protected methods
await test(
  "QUERY: should only protect specified HTTP methods",
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

// Test 19: Query - Missing token in storage
await test(
  "QUERY: should block request when token not found in storage",
  func() : async () {
    let (app, _) = createAppWithCSRF(null);

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

// Test 20: Query - Custom header name for CSRF token
await test(
  "QUERY: should support custom header name for CSRF token",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      headerName = "X-Custom-CSRF-Token";
      tokenRotation = #perSession;
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

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
  },
);

// Test 21: Query - Token validation for different HTTP methods
await test(
  "QUERY: should validate CSRF token for all protected methods",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #perSession;
    };
    let (app, _) = createAppWithCSRF(?config);

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
    let postResponse = app.http_request(postRequest);
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
    let putResponse = app.http_request(putRequest);
    assertStatusCode(putResponse.status_code, 200);

    // Test DELETE
    let deleteRequest = createRequest(
      #delete,
      "/delete",
      [("X-CSRF-Token", token)],
      "",
    );
    let deleteResponse = app.http_request(deleteRequest);
    assertStatusCode(deleteResponse.status_code, 200);
  },
);

// Test 22: Query - PATCH method protection
await test(
  "QUERY: should protect PATCH requests by default",
  func() : async () {
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

// Test 23: Query - Valid token for PATCH request
await test(
  "QUERY: should allow PATCH request with valid CSRF token",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #perSession;
    };
    let (app, _) = createAppWithCSRF(?config);
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

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
  },
);

// Test 24: Query - Request with wrong header name
await test(
  "QUERY: should block request with token in wrong header",
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

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 403);
  },
);

// Test 25: Query - Empty CSRF token header
await test(
  "QUERY: should block request with empty CSRF token header",
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

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 403);
  },
);

// Test 26: Query - Case-sensitive token validation
await test(
  "QUERY: should perform case-sensitive token validation",
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

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 403);
  },
);

// ================================
// QUERY UPGRADE TESTS (CRITICAL)
// ================================

// Test 27: Query should upgrade when per-request token rotation is needed for GET
await test(
  "QUERY: should upgrade GET request when per-request token rotation is configured",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #perRequest; // This should cause upgrade
    };
    let (app, _) = createAppWithCSRF(?config);

    let request = createRequest(
      #get,
      "/",
      [],
      Text.encodeUtf8(""),
    );

    let response = app.http_request(request);

    assert (response.upgrade == true);
  },
);

// Test 28: Query should upgrade when per-request token rotation is needed for POST
await test(
  "QUERY: should upgrade POST request when per-request token rotation is configured",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #perRequest; // This should cause upgrade
    };
    let (app, _) = createAppWithCSRF(?config);

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

    let response = app.http_request(request);

    assert (response.upgrade == true);
  },
);

// Test 29: Query should upgrade when onSuccess token rotation is needed
await test(
  "QUERY: should upgrade POST request when onSuccess token rotation is configured",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #onSuccess; // This should cause upgrade after successful validation
    };
    let (app, _) = createAppWithCSRF(?config);

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

    let response = app.http_request(request);

    assert (response.upgrade == true);
  },
);

// Test 30: Query should NOT upgrade when per-session token rotation is used
await test(
  "QUERY: should NOT upgrade POST request when per-session token rotation is configured",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #perSession; // This should NOT cause upgrade
    };
    let (app, _) = createAppWithCSRF(?config);

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

    let response = app.http_request(request);

    // With per-session rotation, this should complete as a query without upgrade
    assertStatusCode(response.status_code, 200);

    // Verify that it did NOT upgrade
    assert (response.upgrade == false);

    // Check that NO new CSRF token was generated (no X-CSRF-Token header in response)
    let hasCSRFHeader = Array.any<(Text, Text)>(
      response.headers,
      func((name, value)) {
        name == config.headerName;
      },
    );
    if (hasCSRFHeader) {
      Runtime.trap("CSRF token should NOT be generated for per-session rotation in query mode");
    };
  },
);

// Test 31: Query - Token storage integration
await test(
  "QUERY: should properly integrate with token storage",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #perSession;
    };
    let (app, _) = createAppWithCSRF(?config);

    let token = createToken(Time.now(), "abcd");
    tokenStorage.set(token);

    // Verify token is stored
    switch (tokenStorage.get()) {
      case (?t) {
        if (t != token) {
          Runtime.trap("Token not stored correctly");
        };
      };
      case (null) Runtime.trap("Token should be stored");
    };

    let request = createRequest(
      #post,
      "/submit",
      [
        ("Content-Type", "application/json"),
        ("X-CSRF-Token", token),
      ],
      "{\"data\": \"test\"}",
    );

    let response = app.http_request(request);
    assertStatusCode(response.status_code, 200);
  },
);

// Test 32: Query - Multiple exempt paths
await test(
  "QUERY: should handle multiple exempt paths",
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

    let request = createRequest(
      #post,
      "/submit",
      [("Content-Type", "application/json")],
      "{\"data\": \"public\"}",
    );

    let response = app.http_request(request);
    assertStatusCode(response.status_code, 200);
  },
);

// Test 33: Query - Non-exempt path requires token
await test(
  "QUERY: should require token for non-exempt paths",
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

// Test 34: Query should NOT upgrade for GET requests with per-session rotation
await test(
  "QUERY: should NOT upgrade GET request when per-session token rotation is configured",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #perSession; // This should NOT cause upgrade for non-protected methods
    };
    let (app, _) = createAppWithCSRF(?config);

    let request = createRequest(
      #get,
      "/",
      [],
      Text.encodeUtf8(""),
    );

    let response = app.http_request(request);

    // GET with per-session rotation should complete as query without upgrade
    assertStatusCode(response.status_code, 200);
    assert (response.upgrade == false);
  },
);

// Test 35: Query should upgrade for onSuccess rotation with valid token
await test(
  "QUERY: should upgrade for onSuccess rotation even with valid token",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #onSuccess; // Should upgrade after successful validation
    };
    let (app, _) = createAppWithCSRF(?config);

    let token = createToken(Time.now(), "abcd");
    tokenStorage.set(token);

    let request = createRequest(
      #put,
      "/update",
      [
        ("Content-Type", "application/json"),
        ("X-CSRF-Token", token),
      ],
      "{\"data\": \"updated\"}",
    );

    let response = app.http_request(request);

    // Should upgrade because onSuccess needs token generation after validation
    assert (response.upgrade == true);
  },
);

// Test 36: Query should NOT upgrade for exempt paths even with per-request rotation
await test(
  "QUERY: should NOT upgrade for exempt paths even with per-request rotation",
  func() : async () {
    let tokenStorage = MockTokenStorage();
    let config = {
      CSRFMiddleware.defaultConfig({
        get = tokenStorage.get;
        set = tokenStorage.set;
        clear = tokenStorage.clear;
      }) with
      tokenRotation = #perRequest; // Would normally cause upgrade
      exemptPaths = ["/submit"]; // But this path is exempt
    };
    let (app, _) = createAppWithCSRF(?config);

    let request = createRequest(
      #post,
      "/submit",
      [("Content-Type", "application/json")],
      "{\"data\": \"test\"}",
    );

    let response = app.http_request(request);

    // Exempt paths should not upgrade regardless of rotation strategy
    assertStatusCode(response.status_code, 200);
    assert (response.upgrade == false);
  },
);
