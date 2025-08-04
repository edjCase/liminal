import { test } "mo:test";
import Text "mo:new-base/Text";
import Blob "mo:new-base/Blob";
import Nat16 "mo:new-base/Nat16";

import Liminal "../src/lib";
import CORSMiddleware "../src/Middleware/CORS";
import HttpMethod "../src/HttpMethod";

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

// Test 1: Simple CORS request with allowed origin
test(
  "should allow request from allowed origin",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = ["http://example.com"];
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #get,
      "/test",
      [("Origin", "http://example.com")],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    // Check CORS headers are present
    let hasOriginHeader = switch (getHeader(response.headers, "Access-Control-Allow-Origin")) {
      case (?"http://example.com") true;
      case (_) false;
    };
    assert hasOriginHeader;
  },
);

// Test 2: Request from disallowed origin
test(
  "should reject request from disallowed origin",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = ["http://allowed.com"];
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #get,
      "/test",
      [("Origin", "http://disallowed.com")],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    // Should not have CORS headers for disallowed origin
    let hasOriginHeader = switch (getHeader(response.headers, "Access-Control-Allow-Origin")) {
      case (null) false;
      case (_) true;
    };
    assert (not hasOriginHeader);
  },
);

// Test 3: Wildcard origin allows any origin
test(
  "should allow any origin with wildcard",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = []; // Empty means wildcard
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #get,
      "/test",
      [("Origin", "http://any-origin.com")],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    // Should have wildcard origin header
    let hasWildcardOrigin = switch (getHeader(response.headers, "Access-Control-Allow-Origin")) {
      case (?"*") true;
      case (_) false;
    };
    assert hasWildcardOrigin;
  },
);

// Test 4: Preflight OPTIONS request - allowed method
test(
  "should handle preflight for allowed method",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = ["http://example.com"];
      allowMethods = [#get, #post]; // Allow POST
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #options,
      "/test",
      [
        ("Origin", "http://example.com"),
        ("Access-Control-Request-Method", "POST"),
      ],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    assert (Nat16.toNat(response.status_code) == 200);

    let hasOriginHeader = switch (getHeader(response.headers, "Access-Control-Allow-Origin")) {
      case (?"http://example.com") true;
      case (_) false;
    };
    assert hasOriginHeader;

    let allowsMethod = switch (getHeader(response.headers, "Access-Control-Allow-Methods")) {
      case (?methods) Text.contains(methods, #text("POST"));
      case (null) false;
    };
    assert allowsMethod;
  },
);

// Test 5: Preflight OPTIONS request - disallowed method
test(
  "should reject preflight for disallowed method",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = ["http://example.com"];
      allowMethods = [#get]; // Only GET allowed
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #options,
      "/test",
      [
        ("Origin", "http://example.com"),
        ("Access-Control-Request-Method", "PUT"), // PUT not allowed
      ],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    // Should return success but without CORS headers for disallowed method
    assert (Nat16.toNat(response.status_code) == 200);

    // Check that CORS headers are not present (method not allowed)
    let allowOriginHeader = getHeader(response.headers, "Access-Control-Allow-Origin");
    let allowMethodsHeader = getHeader(response.headers, "Access-Control-Allow-Methods");

    assert (allowOriginHeader == null);
    assert (allowMethodsHeader == null);
  },
);

// Test 6: Preflight with custom headers
test(
  "should handle preflight with allowed headers",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = ["http://example.com"];
      allowHeaders = ["Content-Type", "Authorization"];
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #options,
      "/test",
      [
        ("Origin", "http://example.com"),
        ("Access-Control-Request-Method", "POST"),
        ("Access-Control-Request-Headers", "Content-Type"),
      ],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    assert (Nat16.toNat(response.status_code) == 200);

    let hasOriginHeader = switch (getHeader(response.headers, "Access-Control-Allow-Origin")) {
      case (?"http://example.com") true;
      case (_) false;
    };
    assert hasOriginHeader;

    let allowsHeaders = switch (getHeader(response.headers, "Access-Control-Allow-Headers")) {
      case (?headers) Text.contains(headers, #text("Content-Type"));
      case (null) false;
    };
    assert allowsHeaders;
  },
);

// Test 7: Credentials support
test(
  "should handle credentials properly",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = ["http://example.com"];
      allowCredentials = true;
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #get,
      "/test",
      [("Origin", "http://example.com")],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    let hasCredentialsHeader = switch (getHeader(response.headers, "Access-Control-Allow-Credentials")) {
      case (?"true") true;
      case (_) false;
    };
    assert hasCredentialsHeader;

    let hasVaryHeader = switch (getHeader(response.headers, "Vary")) {
      case (?vary) Text.contains(vary, #text("Origin"));
      case (null) false;
    };
    assert hasVaryHeader;
  },
);

// Test 8: Exposed headers
test(
  "should expose configured headers",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = ["http://example.com"];
      exposeHeaders = ["X-Total-Count", "X-Custom-Header"];
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #get,
      "/test",
      [("Origin", "http://example.com")],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    let hasExposeHeaders = switch (getHeader(response.headers, "Access-Control-Expose-Headers")) {
      case (?headers) Text.contains(headers, #text("X-Total-Count"));
      case (null) false;
    };
    assert hasExposeHeaders;
  },
);

// Test 9: Max age configuration
test(
  "should set max age for preflight requests",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = ["http://example.com"];
      maxAge = ?3600;
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #options,
      "/test",
      [
        ("Origin", "http://example.com"),
        ("Access-Control-Request-Method", "GET"),
      ],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    let hasMaxAge = switch (getHeader(response.headers, "Access-Control-Max-Age")) {
      case (?"3600") true;
      case (_) false;
    };
    assert hasMaxAge;
  },
);

// Test 10: No origin header
test(
  "should handle requests without origin header",
  func() : () {
    let corsOptions = CORSMiddleware.defaultOptions;

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #get,
      "/test",
      [], // No Origin header
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    // Should not have CORS headers when no Origin header is present
    let hasOriginHeader = switch (getHeader(response.headers, "Access-Control-Allow-Origin")) {
      case (null) false;
      case (_) true;
    };
    assert (not hasOriginHeader);
  },
);

// Test 11: Multiple allowed origins
test(
  "should handle multiple allowed origins",
  func() : () {
    let corsOptions = {
      CORSMiddleware.defaultOptions with
      allowOrigins = ["http://app1.com", "http://app2.com"];
    };

    let app = Liminal.App({
      middleware = [CORSMiddleware.new(corsOptions)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    let request = createRequest(
      #get,
      "/test",
      [("Origin", "http://app2.com")],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    let hasCorrectOrigin = switch (getHeader(response.headers, "Access-Control-Allow-Origin")) {
      case (?"http://app2.com") true;
      case (_) false;
    };
    assert hasCorrectOrigin;
  },
);
