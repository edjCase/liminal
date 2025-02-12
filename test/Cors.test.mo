import { test; suite } "mo:test";
import Types "../src/Types";
import Pipeline "../src/Pipeline";
import Blob "mo:base/Blob";
import HttpMethod "../src/HttpMethod";
import Cors "../src/Cors";
import HttpContext "../src/HttpContext";

// Helper function to find header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
};

// Helper to create mock request
func createMockRequest(method : HttpMethod.HttpMethod, headers : [(Text, Text)]) : (HttpContext.HttpContext, Pipeline.Next) {
    let httpContext = HttpContext.HttpContext({
        method = HttpMethod.toText(method);
        url = "/test";
        headers = headers;
        body = Blob.fromArray([]);
    });
    (
        httpContext,
        func() : Types.HttpResponse = {
            statusCode = 201;
            headers = [];
            body = null;
        },
    );
};

suite(
    "CORS Middleware Tests",
    func() {

        test(
            "custom origin handling",
            func() {
                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with allowOrigins = ["http://allowed-domain.com"]
                });

                // Test with allowed origin
                let request1 = createMockRequest(#get, [("Origin", "http://allowed-domain.com")]);
                let response1 = middleware.handle(request1);
                assert (getHeader(response1.headers, "Access-Control-Allow-Origin") == ?"http://allowed-domain.com");
                assert (getHeader(response1.headers, "Vary") == ?"Origin");

                // Test with different origin
                let request2 = createMockRequest(#get, [("Origin", "http://other-domain.com")]);
                let response2 = middleware.handle(request2);
                assert (getHeader(response2.headers, "Access-Control-Allow-Origin") == null);
                assert (getHeader(response2.headers, "Vary") == null);
            },
        );

        test(
            "preflight request handling",
            func() {

                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with
                    allowMethods = [#get, #post, #put];
                    allowHeaders = ["Content-Type", "X-Custom-Header"];
                    maxAge = ?3600;
                });

                // Test OPTIONS request
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Method", "GET"),
                        ("Access-Control-Request-Headers", "X-Custom-Header"),
                    ],
                );
                let response = middleware.handle(request);

                assert (response.statusCode == 204);
                assert (getHeader(response.headers, "Access-Control-Allow-Methods") == ?"GET, POST, PUT");
                assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type, X-Custom-Header");
                assert (getHeader(response.headers, "Access-Control-Max-Age") == ?"3600");
            },
        );

        test(
            "credentials handling",
            func() {

                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with
                    allowCredentials = true;
                });

                // Test request with credentials
                let request = createMockRequest(#get, [("Origin", "http://example.com")]);
                let response = middleware.handle(request);

                assert (getHeader(response.headers, "Access-Control-Allow-Credentials") == ?"true");
            },
        );

        test(
            "exposed headers",
            func() {

                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with
                    exposeHeaders = ["Content-Length", "X-Custom-Response"];
                });

                // Test request
                let request = createMockRequest(#get, [("Origin", "http://example.com")]);
                let response = middleware.handle(request);

                assert (getHeader(response.headers, "Access-Control-Expose-Headers") == ?"Content-Length, X-Custom-Response");
            },
        );

        test(
            "no origin header",
            func() {
                let middleware = Cors.createMiddleware(Cors.defaultOptions);
                let (httpContext, next) = createMockRequest(#get, []); // No Origin header
                let response = middleware.handle(httpContext, next);
                assert (getHeader(response.headers, "Access-Control-Allow-Origin") == null);
            },
        );

        test(
            "preflight request disallowed method",
            func() {
                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with allowMethods = [#get, #post] // #put is not allowed

                });
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Method", "PUT") // Requesting PUT method
                    ],
                );
                let response = middleware.handle(request);
                assert (getHeader(response.headers, "Access-Control-Allow-Methods") == ?"GET, POST");
            },
        );

        test(
            "preflight request disallowed header",
            func() {
                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with allowHeaders = ["Content-Type"] // "X-Custom-Header" is not allowed

                });
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Headers", "X-Custom-Header") // Requesting X-Custom-Header
                    ],
                );
                let response = middleware.handle(request);
                assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type"); // Should not set allow headers
            },
        );
        test(
            "preflight request with multiple request headers",
            func() {
                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with allowHeaders = ["Content-Type", "Authorization"]
                });
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Headers", "Content-Type, Authorization"),
                    ],
                );
                let response = middleware.handle(request);
                assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type, Authorization");
            },
        );

        test(
            "preflight request with case-insensitive header matching",
            func() {
                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with allowHeaders = ["Content-Type"]
                });
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Headers", "content-type") // lowercase
                    ],
                );
                let response = middleware.handle(request);
                assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type");
            },
        );

        test(
            "preflight request with no request method",
            func() {
                let middleware = Cors.createMiddleware(Cors.defaultOptions);
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com")
                        // No Access-Control-Request-Method header
                    ],
                );
                let response = middleware.handle(request);
                assert (response.statusCode == 204);
                assert (getHeader(response.headers, "Access-Control-Allow-Methods") == null);
            },
        );

        test(
            "wildcard origin with credentials",
            func() {
                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with
                    allowCredentials = true;
                    allowOrigins = [];
                });
                let request = createMockRequest(
                    #get,
                    [("Origin", "http://example.com")],
                );
                let response = middleware.handle(request);
                // Should not use wildcard with credentials
                assert (getHeader(response.headers, "Access-Control-Allow-Origin") == ?"http://example.com");
                assert (getHeader(response.headers, "Vary") == ?"Origin");
            },
        );

        test(
            "preflight request with invalid method format",
            func() {
                let middleware = Cors.createMiddleware(Cors.defaultOptions);
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Method", "INVALID_METHOD"),
                    ],
                );
                let response = middleware.handle(request);
                assert (response.statusCode == 204);
                assert (getHeader(response.headers, "Access-Control-Allow-Methods") != null);
            },
        );

    },
);
