import { test = testAsync; suite = suiteAsync } "mo:test/async";
import Blob "mo:new-base/Blob";
import Runtime "mo:new-base/Runtime";
import Debug "mo:base/Debug";
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

                // Test with different origin
                let response2 = CORS.handlePreflight(
                    context,
                    {
                        CORS.defaultOptions with allowOrigins = ["http://other-domain.com"]
                    },
                );
                switch (response2) {
                    case (#next({ corsHeaders })) {
                        assert (getHeader(corsHeaders, "Access-Control-Allow-Origin") == null);
                        assert (getHeader(corsHeaders, "Vary") == null);
                    };
                    case (#complete(_)) Runtime.trap("Expected #next, got #complete");
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
                        assert (response.statusCode == 204);
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
                        assert (getHeader(corsHeaders, "Access-Control-Allow-Credentials") == ?"true");
                    };
                    case (#complete(response)) Runtime.trap("Expected #next, got #complete");
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
                    case (#complete(response)) Runtime.trap("Expected #next, got #complete");
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
                        assert (getHeader(corsHeaders, "Access-Control-Allow-Origin") == null);
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
                        assert (getHeader(response.headers, "Access-Control-Allow-Methods") == ?"GET, POST");
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
                        assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type"); // Should not set allow headers
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
                        assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type");
                    };
                };
            },
        );

        await testAsync(
            "preflight request with no request method",
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
                    case (#next(_)) Runtime.trap("Expected #complete, got #next");
                    case (#complete(response)) {
                        assert (response.statusCode == 204);
                        assert (getHeader(response.headers, "Access-Control-Allow-Methods") == null);
                    };
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
                    };
                    case (#complete(_)) Runtime.trap("Expected #complete, got #next");
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
                        assert (response.statusCode == 204);
                        // No specific handling for invalid methods, just return 204
                        Debug.print(debug_show (response.headers));
                        assert (getHeader(response.headers, "Access-Control-Allow-Methods") == null);
                    };
                };
            },
        );

    },
);
