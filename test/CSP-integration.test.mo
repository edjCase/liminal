import { test } "mo:test";
import Array "mo:core@1/Array";
import Text "mo:core@1/Text";
import Blob "mo:core@1/Blob";
import Iter "mo:core@1/Iter";
import Runtime "mo:core@1/Runtime";
import Nat "mo:core@1/Nat";
import Nat16 "mo:core@1/Nat16";
import Liminal "../src/lib";
import CSPMiddleware "../src/Middleware/CSP";
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

func assertOptionTextNotContains(actual : ?Text, shouldNotContain : Text, message : Text) : () {
  switch (actual) {
    case (?text) {
      if (Text.contains(text, #text(shouldNotContain))) {
        Runtime.trap(message # "\nExpected NOT to contain: '" # shouldNotContain # "'\nActual: '" # text # "'");
      };
    };
    case (null) {
      Runtime.trap(message # " - Expected header to exist but was null");
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

// Helper to create a basic app with CSP middleware
func createAppWithCSP(cspOptions : ?CSPMiddleware.Options) : Liminal.App {
  let options = switch (cspOptions) {
    case (?opts) opts;
    case (null) CSPMiddleware.defaultOptions;
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
            body = ?"<html><body>Hello World</body></html>";
            streamingStrategy = null;
          };
        },
      ),
      Router.getQuery(
        "/api/data",
        func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
          {
            statusCode = 200;
            headers = [("Content-Type", "application/json")];
            body = ?"{\"data\": \"test\"}";
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
      Router.getQuery(
        "/test",
        func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
          {
            statusCode = 200;
            headers = [("Content-Type", "text/html")];
            body = ?"<html><body>Test</body></html>";
            streamingStrategy = null;
          };
        },
      ),
    ];
  };

  Liminal.App({
    middleware = [
      CSPMiddleware.new(options),
      RouterMiddleware.new(routerConfig),
    ];
    errorSerializer = Liminal.defaultJsonErrorSerializer;
    candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
    logger = Liminal.buildDebugLogger(#warning);
    urlNormalization = {
      pathIsCaseSensitive = false;
      preserveTrailingSlash = false;
      queryKeysAreCaseSensitive = false;
      removeEmptyPathSegments = true;
      resolvePathDotSegments = true;
      usernameIsCaseSensitive = false;
    };
  });
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

// Test 1: Default CSP headers are added
test(
  "should add default CSP headers",
  func() : () {
    let app = createAppWithCSP(null);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    let cspHeader = getHeader(response.headers, "Content-Security-Policy");
    switch (cspHeader) {
      case (?_) {
        assertOptionText(cspHeader, "default-src 'self'", "CSP header should contain default-src 'self'");
        assertOptionText(cspHeader, "script-src 'self'", "CSP header should contain script-src 'self'");
        assertOptionText(cspHeader, "object-src 'none'", "CSP header should contain object-src 'none'");
      };
      case (null) {
        Runtime.trap("Expected Content-Security-Policy header but it was missing");
      };
    };
    assertStatusCode(response.status_code, 200);
  },
);

// Test 2: Custom script-src policy
test(
  "should handle custom script-src policy",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      scriptSrc = ["'self'", "https://cdn.example.com", "'unsafe-inline'"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "script-src 'self' https://cdn.example.com 'unsafe-inline'", "CSP header should contain custom script-src");
  },
);

// Test 3: Custom img-src policy
test(
  "should handle custom img-src policy",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      imgSrc = ["'self'", "data:", "https://*.example.com"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "img-src 'self' data: https://*.example.com", "CSP header should contain custom img-src");
  },
);

// Test 4: Frame ancestors policy
test(
  "should handle frame-ancestors policy",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      frameAncestors = ["'self'", "https://trusted-parent.com"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "frame-ancestors 'self' https://trusted-parent.com", "CSP header should contain frame-ancestors policy");
  },
);

// Test 5: Connect-src policy for API endpoints
test(
  "should handle connect-src policy",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      connectSrc = ["'self'", "https://api.example.com", "wss://websocket.example.com"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/api/data",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "connect-src 'self' https://api.example.com wss://websocket.example.com", "CSP header should contain connect-src policy");
  },
);

// Test 6: Style-src policy
test(
  "should handle style-src policy",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      styleSrc = ["'self'", "https://fonts.googleapis.com"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "style-src 'self' https://fonts.googleapis.com", "CSP header should contain style-src policy");
  },
);

// Test 7: Font-src policy
test(
  "should handle font-src policy",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      fontSrc = ["'self'", "https://fonts.gstatic.com", "data:"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "font-src 'self' https://fonts.gstatic.com data:", "CSP header should contain font-src policy");
  },
);

// Test 8: Object-src none policy
test(
  "should handle object-src none policy",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      objectSrc = ["'none'"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "object-src 'none'", "CSP header should contain object-src 'none' policy");
  },
);

// Test 9: Base-uri policy
test(
  "should handle base-uri policy",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      baseUri = ["'self'"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "base-uri 'self'", "CSP header should contain base-uri policy");
  },
);

// Test 10: Form-action policy
test(
  "should handle form-action policy",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      formAction = ["'self'", "https://forms.example.com"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "form-action 'self' https://forms.example.com", "CSP header should contain form-action policy");
  },
);

// Test 11: Upgrade insecure requests
test(
  "should handle upgrade-insecure-requests",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      upgradeInsecureRequests = true;
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "upgrade-insecure-requests", "CSP header should contain upgrade-insecure-requests");
  },
);

// Test 12: Disable upgrade insecure requests
test(
  "should not include upgrade-insecure-requests when disabled",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      upgradeInsecureRequests = false;
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionTextNotContains(getHeader(response.headers, "Content-Security-Policy"), "upgrade-insecure-requests", "CSP header should NOT contain upgrade-insecure-requests when disabled");
  },
);

// Test 13: Empty directives are omitted
test(
  "should omit empty directives",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      scriptSrc = []; // Empty directive
      styleSrc = ["'self'"]; // Non-empty directive
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    let cspHeader = getHeader(response.headers, "Content-Security-Policy");
    assertOptionTextNotContains(cspHeader, "script-src", "CSP header should NOT contain script-src when empty");
    assertOptionText(cspHeader, "style-src 'self'", "CSP header should contain style-src 'self'");
  },
);

// Test 14: Style-src-elem directive
test(
  "should handle style-src-elem directive",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      styleSrcElem = ["'self'", "'unsafe-inline'"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "style-src-elem 'self' 'unsafe-inline'", "CSP header should contain style-src-elem directive");
  },
);

// Test 15: Restrictive policy for sensitive content
test(
  "should handle restrictive policy for sensitive content",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      defaultSrc = ["'none'"];
      scriptSrc = ["'self'"];
      styleSrc = ["'self'"];
      imgSrc = ["'self'"];
      connectSrc = ["'self'"];
      fontSrc = ["'none'"];
      objectSrc = ["'none'"];
      frameAncestors = ["'none'"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    let cspHeader = getHeader(response.headers, "Content-Security-Policy");
    assertOptionText(cspHeader, "default-src 'none'", "CSP header should contain default-src 'none'");
    assertOptionText(cspHeader, "script-src 'self'", "CSP header should contain script-src 'self'");
    assertOptionText(cspHeader, "frame-ancestors 'none'", "CSP header should contain frame-ancestors 'none'");
  },
);

// Test 16: CSP headers are preserved with other headers
test(
  "should preserve existing headers while adding CSP",
  func() : () {

    let app = createAppWithCSP(null);

    let request = createRequest(
      #get,
      "/test",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertArrayContains(response.headers, "Content-Security-Policy", "", "Should have CSP header"); // Just check it exists
    assertArrayContains(response.headers, "Content-Type", "text/html", "Should preserve Content-Type header");
    // Note: Assuming Cache-Control and X-Custom-Header are not actually set by the test route
    // If they were set, we would add those checks here
  },
);

// Test 17: CSP with nonce for inline scripts
test(
  "should support nonce-based CSP for inline scripts",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      scriptSrc = ["'self'", "'nonce-abc123'"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "script-src 'self' 'nonce-abc123'", "CSP header should contain nonce-based script-src");
  },
);

// Test 18: CSP with hash-based inline content
test(
  "should support hash-based CSP for inline content",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      styleSrc = ["'self'", "'sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU='"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "style-src 'self' 'sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU='", "CSP header should contain hash-based style-src");
  },
);

// Test 19: CSP works on different HTTP methods
test(
  "should apply CSP headers to POST requests",
  func() : () {
    let app = createAppWithCSP(null);

    let request = createRequest(
      #post,
      "/submit",
      [("Content-Type", "application/json")],
      "{\"data\": \"test\"}",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);
    assertOptionText(getHeader(response.headers, "Content-Security-Policy"), "default-src 'self'", "CSP header should contain default-src 'self' for POST requests");
  },
);

// Test 20: CSP header format validation
test(
  "should generate properly formatted CSP header",
  func() : () {
    let cspOptions = {
      CSPMiddleware.defaultOptions with
      defaultSrc = ["'self'"];
      scriptSrc = ["'self'", "https://cdn.example.com"];
      styleSrc = ["'self'", "'unsafe-inline'"];
    };
    let app = createAppWithCSP(?cspOptions);

    let request = createRequest(
      #get,
      "/",
      [],
      "",
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);

    let cspHeader = getHeader(response.headers, "Content-Security-Policy");
    switch (cspHeader) {
      case (?csp) {
        // Check that directives are separated by semicolons
        let parts = Text.split(csp, #char ';');
        let partsArray = Iter.toArray(parts);
        if (Array.size(partsArray) < 3) {
          Runtime.trap("CSP header should have multiple directives separated by semicolons.\nExpected: >= 3\nActual: " # Nat.toText(Array.size(partsArray)) # " in header: " # csp);
        };
      };
      case (null) {
        Runtime.trap("Expected Content-Security-Policy header but it was missing");
      };
    };
  },
);
