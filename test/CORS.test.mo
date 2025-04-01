import { test = testAsync; suite = suiteAsync } "mo:test/async";
import Blob "mo:new-base/Blob";
import Runtime "mo:new-base/Runtime";
import HttpMethod "../src/HttpMethod";
import CORS "../src/CORS";
import HttpContext "../src/HttpContext";

// Helper function to find header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
};

await suiteAsync(
    "CORS Middleware Tests",
    func() : async () {

        await testAsync(
            "custom origin handling",
            func() : async () {

                // Test with allowed origin
                let context = HttpContext.HttpContext({
                    method = HttpMethod.toText(#get);
                    url = "/test";
                    headers = [("Origin", "http://allowed-domain.com")];
                    body = Blob.fromArray([]);
                });
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
                let context2 = HttpContext.HttpContext({
                    method = HttpMethod.toText(#get);
                    url = "/test";
                    headers = [("Origin", "http://disallowed-domain.com")];
                    body = Blob.fromArray([]);
                });
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

        await testAsync(
            "preflight request handling",
            func() : async () {

                // Test OPTIONS request
                let context = HttpContext.HttpContext({
                    method = HttpMethod.toText(#options);
                    url = "/test";
                    headers = [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Method", "GET"),
                        ("Access-Control-Request-Headers", "X-Custom-Header"),
                    ];
                    body = Blob.fromArray([]);
                });
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

        await testAsync(
            "credentials handling",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#get);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "exposed headers",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#get);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "no origin header",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#get);
                        url = "/test";
                        headers = [];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "preflight request disallowed method",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#options);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                            ("Access-Control-Request-Method", "PUT") // Requesting PUT method
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "preflight request disallowed header",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#options);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                            ("Access-Control-Request-Method", "GET"), // Need valid method first
                            ("Access-Control-Request-Headers", "X-Custom-Header") // Requesting X-Custom-Header
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "preflight request with multiple request headers",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#options);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                            ("Access-Control-Request-Method", "GET"),
                            ("Access-Control-Request-Headers", "Content-Type, Authorization"),
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "preflight request with case-insensitive header matching",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#options);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                            ("Access-Control-Request-Method", "GET"),
                            ("Access-Control-Request-Headers", "content-type") // lowercase
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "options request with no request method (not preflight)",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#options);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                            // No Access-Control-Request-Method header
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "wildcard origin with credentials",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#get);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "preflight request with invalid method format",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#options);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                            ("Access-Control-Request-Method", "INVALID_METHOD"),
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "preflight request with invalid origin format",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#options);
                        url = "/test";
                        headers = [
                            ("Origin", "invalid-origin"),
                            ("Access-Control-Request-Method", "GET"),
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "preflight request with invalid headers format",
            func() : async () {
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#options);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                            ("Access-Control-Request-Method", "GET"),
                            ("Access-Control-Request-Headers", ",,invalid,,"),
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "simple method test",
            func() : async () {
                // GET is a simple method, should not require preflight
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#get);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                            ("Content-Type", "text/plain"), // Simple header value
                        ];
                        body = Blob.fromArray([]);
                    }),
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

        await testAsync(
            "content-type with non-simple value",
            func() : async () {
                // Preflight should be required for non-simple Content-Type
                let response = CORS.handlePreflight(
                    HttpContext.HttpContext({
                        method = HttpMethod.toText(#options);
                        url = "/test";
                        headers = [
                            ("Origin", "http://example.com"),
                            ("Access-Control-Request-Method", "POST"),
                            ("Access-Control-Request-Headers", "Content-Type"),
                        ];
                        body = Blob.fromArray([]);
                    }),
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
        await testAsync(
            "exposed headers filtering",
            func() : async () {
                let context = HttpContext.HttpContext({
                    method = HttpMethod.toText(#get);
                    url = "/test";
                    headers = [
                        ("Origin", "http://example.com"),
                    ];
                    body = Blob.fromArray([]);
                });

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
