import { test; suite } "mo:test";
import Blob "mo:new-base/Blob";
import Runtime "mo:new-base/Runtime";
import HttpMethod "../src/HttpMethod";
import CORS "../src/CORS";
import HttpContext "../src/HttpContext";
import ContentNegotiation "../src/ContentNegotiation";
import Serde "mo:serde";
import Logging "../src/Logging";

// Helper function to find header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
  for ((k, v) in headers.vals()) {
    if (k == key) return ?v;
  };
  null;
};

func dummyErrorSerialzer(
  _ : HttpContext.HttpError
) : HttpContext.ErrorSerializerResponse {
  // Dummy error serializer for testing
  return {
    headers = [];
    body = null;
  };
};

func dummyCandidRepresentationNegotiator(
  candid : Serde.Candid.Candid,
  _ : ContentNegotiation.ContentPreference,
) : ?HttpContext.CandidNegotiatedContent {
  // Dummy Candid representation negotiator for testing
  return ?{
    body = to_candid (candid);
    contentType = "application/octet-stream";
  };
};

suite(
  "CORS Middleware Tests",
  func() : () {

    test(
      "custom origin handling",
      func() : () {

        // Test with allowed origin
        let context = HttpContext.HttpContext(
          {
            method = HttpMethod.toText(#get);
            url = "/test";
            headers = [("Origin", "http://allowed-domain.com")];
            body = Blob.fromArray([]);
          },
          null,
          {
            errorSerializer = dummyErrorSerialzer;
            candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
            logger = Logging.buildDebugLogger(#warning);
          },
        );
        let response1 = CORS.handlePreflight(
          context,
          {
            CORS.defaultOptions with allowOrigins = ["http://allowed-domain.com"]
          },
        );
        switch (response1) {
          case (#next({ corsHeaders })) {
            assert (getHeader(corsHeaders, "Access-Control-Allow-Origin") == ?"http://allowed-domain.com");
            assert (getHeader(corsHeaders, "Vary") == ?"Origin");
          };
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
        };

        // Test with different origin - should return response without CORS headers
        let context2 = HttpContext.HttpContext(
          {
            method = HttpMethod.toText(#get);
            url = "/test";
            headers = [("Origin", "http://disallowed-domain.com")];
            body = Blob.fromArray([]);
          },
          null,
          {
            errorSerializer = dummyErrorSerialzer;
            candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
            logger = Logging.buildDebugLogger(#warning);
          },
        );
        let response2 = CORS.handlePreflight(
          context2,
          {
            CORS.defaultOptions with allowOrigins = ["http://other-domain.com"]
          },
        );
        switch (response2) {
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
          case (#next({ corsHeaders })) {
            // No CORS headers should be set
            assert (corsHeaders.size() == 0);
          };
        };
      },
    );

    test(
      "preflight request handling",
      func() : () {

        // Test OPTIONS request
        let context = HttpContext.HttpContext(
          {
            method = HttpMethod.toText(#options);
            url = "/test";
            headers = [
              ("Origin", "http://example.com"),
              ("Access-Control-Request-Method", "GET"),
              ("Access-Control-Request-Headers", "X-Custom-Header"),
            ];
            body = Blob.fromArray([]);
          },
          null,
          {
            errorSerializer = dummyErrorSerialzer;
            candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
            logger = Logging.buildDebugLogger(#warning);
          },
        );
        let response = CORS.handlePreflight(
          context,
          {
            CORS.defaultOptions with
            allowMethods = [#get, #post, #put];
            allowHeaders = ["Content-Type", "X-Custom-Header"];
            maxAge = ?3600;
          },
        );
        switch (response) {
          case (#next(_)) Runtime.trap("Expected #complete, got #next");
          case (#complete(response)) {
            // Status code can be 200, no need to assert a specific status
            assert (getHeader(response.headers, "Access-Control-Allow-Origin") == ?"*");
            assert (getHeader(response.headers, "Access-Control-Allow-Methods") == ?"GET, POST, PUT");
            assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type, X-Custom-Header");
            assert (getHeader(response.headers, "Access-Control-Max-Age") == ?"3600");
          };
        };
      },
    );

    test(
      "credentials handling",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#get);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          {
            CORS.defaultOptions with
            allowCredentials = true;
          },
        );

        // Test request with credentials
        switch (response) {
          case (#next({ corsHeaders })) {
            assert (getHeader(corsHeaders, "Access-Control-Allow-Origin") == ?"http://example.com");
            assert (getHeader(corsHeaders, "Access-Control-Allow-Credentials") == ?"true");
            assert (getHeader(corsHeaders, "Vary") == ?"Origin");
          };
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
        };
      },
    );

    test(
      "exposed headers",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#get);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          {
            CORS.defaultOptions with
            exposeHeaders = ["Content-Length", "X-Custom-Response"];
          },
        );

        // Test request with exposed headers
        switch (response) {
          case (#next({ corsHeaders })) {
            assert (getHeader(corsHeaders, "Access-Control-Expose-Headers") == ?"Content-Length, X-Custom-Response");
          };
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
        };
      },
    );

    test(
      "no origin header",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#get);
              url = "/test";
              headers = [];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          CORS.defaultOptions,
        );
        // Test request with no origin header
        switch (response) {
          case (#next({ corsHeaders })) {
            assert (corsHeaders.size() == 0); // No CORS headers should be set
          };
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
        };
      },
    );

    test(
      "preflight request disallowed method",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                ("Access-Control-Request-Method", "PUT") // Requesting PUT method
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          {
            CORS.defaultOptions with allowMethods = [#get, #post] // #put is not allowed
          },
        );
        switch (response) {
          case (#next(_)) Runtime.trap("Expected #complete, got #next");
          case (#complete(response)) {
            // No need to assert status code, just ensure CORS headers are not present
            assert (getHeader(response.headers, "Access-Control-Allow-Methods") == null);
            assert (getHeader(response.headers, "Access-Control-Allow-Origin") == null);
          };
        };
      },
    );

    test(
      "preflight request disallowed header",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                ("Access-Control-Request-Method", "GET"), // Need valid method first
                ("Access-Control-Request-Headers", "X-Custom-Header") // Requesting X-Custom-Header
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          {
            CORS.defaultOptions with allowHeaders = ["Content-Type"] // "X-Custom-Header" is not allowed
          },
        );
        switch (response) {
          case (#next(_)) Runtime.trap("Expected #complete, got #next");
          case (#complete(response)) {
            // No need to assert status code, just ensure CORS headers are not present
            assert (getHeader(response.headers, "Access-Control-Allow-Headers") == null);
            assert (getHeader(response.headers, "Access-Control-Allow-Origin") == null);
          };
        };
      },
    );

    test(
      "preflight request with multiple request headers",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                ("Access-Control-Request-Method", "GET"),
                ("Access-Control-Request-Headers", "Content-Type, Authorization"),
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          {
            CORS.defaultOptions with allowHeaders = ["Content-Type", "Authorization"]
          },
        );
        switch (response) {
          case (#next(_)) Runtime.trap("Expected #complete, got #next");
          case (#complete(response)) {
            // Just verify the headers are present, don't assert specific status
            assert (getHeader(response.headers, "Access-Control-Allow-Origin") == ?"*");
            assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type, Authorization");
          };
        };
      },
    );

    test(
      "preflight request with case-insensitive header matching",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                ("Access-Control-Request-Method", "GET"),
                ("Access-Control-Request-Headers", "content-type") // lowercase
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          {
            CORS.defaultOptions with allowHeaders = ["Content-Type"]
          },
        );
        switch (response) {
          case (#next(_)) Runtime.trap("Expected #complete, got #next");
          case (#complete(response)) {
            // Just verify the headers are present, don't assert specific status
            assert (getHeader(response.headers, "Access-Control-Allow-Origin") == ?"*");
            assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type");
          };
        };
      },
    );

    test(
      "preflight request with wildcard everything",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                ("Access-Control-Request-Method", "GET"),
                ("Access-Control-Request-Headers", "content-type"),
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          {
            CORS.defaultOptions with allowHeaders = [];
            allowOrigins = [];
            allowMethods = [];
          },
        );
        switch (response) {
          case (#next(_)) Runtime.trap("Expected #complete, got #next");
          case (#complete(response)) {
            // Just verify the headers are present, don't assert specific status
            assert (getHeader(response.headers, "Access-Control-Allow-Origin") == ?"*");
            assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"*");
            assert (getHeader(response.headers, "Access-Control-Allow-Methods") == ?"*");
          };
        };
      },
    );

    test(
      "options request with no request method (not preflight)",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                // No Access-Control-Request-Method header
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          CORS.defaultOptions,
        );
        switch (response) {
          case (#next({ corsHeaders })) {
            // Treated as a normal OPTIONS request
            assert (getHeader(corsHeaders, "Access-Control-Allow-Origin") == ?"*");
          };
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
        };
      },
    );

    test(
      "wildcard origin with credentials",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#get);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          {
            CORS.defaultOptions with
            allowCredentials = true;
            allowOrigins = [];
          },
        );
        switch (response) {
          case (#next({ corsHeaders })) {
            // Should not use wildcard with credentials
            assert (getHeader(corsHeaders, "Access-Control-Allow-Origin") == ?"http://example.com");
            assert (getHeader(corsHeaders, "Vary") == ?"Origin");
            assert (getHeader(corsHeaders, "Access-Control-Allow-Credentials") == ?"true");
          };
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
        };
      },
    );

    test(
      "preflight request with invalid method format",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                ("Access-Control-Request-Method", "INVALID_METHOD"),
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          CORS.defaultOptions,
        );
        switch (response) {
          case (#next(_)) Runtime.trap("Expected #complete, got #next");
          case (#complete(response)) {
            // No CORS headers should be set for invalid method
            assert (response.headers.size() == 0);
          };
        };
      },
    );

    test(
      "preflight request with invalid origin format",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "invalid-origin"),
                ("Access-Control-Request-Method", "GET"),
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          CORS.defaultOptions,
        );
        switch (response) {
          case (#next({ corsHeaders })) {
            // Per spec, no specific status code is mandated for invalid origins
            // Just verify no CORS headers are set
            assert (getHeader(corsHeaders, "Access-Control-Allow-Origin") == null);
          };
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
        };
      },
    );

    test(
      "preflight request with invalid headers format",
      func() : () {
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                ("Access-Control-Request-Method", "GET"),
                ("Access-Control-Request-Headers", ",,invalid,,"),
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          CORS.defaultOptions,
        );
        switch (response) {
          case (#next(_)) Runtime.trap("Expected #complete, got #next");
          case (#complete(response)) {
            // No CORS headers for invalid format
            assert (response.headers.size() == 0);
          };
        };
      },
    );

    test(
      "simple method test",
      func() : () {
        // GET is a simple method, should not require preflight
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#get);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                ("Content-Type", "text/plain"), // Simple header value
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          CORS.defaultOptions,
        );
        switch (response) {
          case (#next({ corsHeaders })) {
            assert (getHeader(corsHeaders, "Access-Control-Allow-Origin") == ?"*");
          };
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
        };
      },
    );

    test(
      "content-type with non-simple value",
      func() : () {
        // Preflight should be required for non-simple Content-Type
        let response = CORS.handlePreflight(
          HttpContext.HttpContext(
            {
              method = HttpMethod.toText(#options);
              url = "/test";
              headers = [
                ("Origin", "http://example.com"),
                ("Access-Control-Request-Method", "POST"),
                ("Access-Control-Request-Headers", "Content-Type"),
              ];
              body = Blob.fromArray([]);
            },
            null,
            {
              errorSerializer = dummyErrorSerialzer;
              candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
              logger = Logging.buildDebugLogger(#warning);
            },
          ),
          {
            CORS.defaultOptions with
            allowHeaders = ["Content-Type"];
          },
        );
        switch (response) {
          case (#next(_)) Runtime.trap("Expected #complete, got #next");
          case (#complete(response)) {
            assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type");
          };
        };
      },
    );

    // Add a new test to verify exposure of only allowed headers to client
    test(
      "exposed headers filtering",
      func() : () {
        let context = HttpContext.HttpContext(
          {
            method = HttpMethod.toText(#get);
            url = "/test";
            headers = [
              ("Origin", "http://example.com"),
            ];
            body = Blob.fromArray([]);
          },
          null,
          {
            errorSerializer = dummyErrorSerialzer;
            candidRepresentationNegotiator = dummyCandidRepresentationNegotiator;
            logger = Logging.buildDebugLogger(#warning);
          },
        );

        // Test with limited exposed headers
        let response = CORS.handlePreflight(
          context,
          {
            CORS.defaultOptions with
            exposeHeaders = ["Content-Length"]; // Only expose Content-Length
          },
        );

        switch (response) {
          case (#next({ corsHeaders })) {
            // Verify only specified headers are exposed
            assert (getHeader(corsHeaders, "Access-Control-Expose-Headers") == ?"Content-Length");
            // Other headers should not be exposed
          };
          case (#complete(_)) Runtime.trap("Expected #next, got #complete");
        };
      },
    );
  },
);
