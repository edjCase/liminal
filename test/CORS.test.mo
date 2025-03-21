import { test = testAsync; suite = suiteAsync } "mo:test/async";
import Types "../src/Types";
import Pipeline "../src/Pipeline";
import Blob "mo:new-base/Blob";
import Debug "mo:new-base/Debug";
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

// Helper to create mock request
func createMockRequest(method : HttpMethod.HttpMethod, headers : [(Text, Text)]) : (HttpContext.HttpContext, Pipeline.NextAsync) {
    let httpContext = HttpContext.HttpContext({
        method = HttpMethod.toText(method);
        url = "/test";
        headers = headers;
        body = Blob.fromArray([]);
    });
    (
        httpContext,
        func() : async* ?Types.HttpResponse {
            ?{
                statusCode = 201;
                headers = [];
                body = null;
            };
        },
    );
};

await suiteAsync(
    "CORS Middleware Tests",
    func() : async () {

        await testAsync(
            "custom origin handling",
            func() : async () {
                let middleware = CORS.createMiddleware({
                    CORS.defaultOptions with allowOrigins = ["http://allowed-domain.com"]
                });

                // Test with allowed origin
                let request1 = createMockRequest(#get, [("Origin", "http://allowed-domain.com")]);
                let ?response1 = await* middleware.handleUpdate(request1) else Runtime.trap("Response is null");
                assert (getHeader(response1.headers, "Access-Control-Allow-Origin") == ?"http://allowed-domain.com");
                assert (getHeader(response1.headers, "Vary") == ?"Origin");

                // Test with different origin
                let request2 = createMockRequest(#get, [("Origin", "http://other-domain.com")]);
                let ?response2 = await* middleware.handleUpdate(request2) else Runtime.trap("Response is null");
                assert (getHeader(response2.headers, "Access-Control-Allow-Origin") == null);
                assert (getHeader(response2.headers, "Vary") == null);
            },
        );

        await testAsync(
            "preflight request handling",
            func() : async () {

                let middleware = CORS.createMiddleware({
                    CORS.defaultOptions with
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
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Response is null");

                assert (response.statusCode == 204);
                assert (getHeader(response.headers, "Access-Control-Allow-Methods") == ?"GET, POST, PUT");
                assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type, X-Custom-Header");
                assert (getHeader(response.headers, "Access-Control-Max-Age") == ?"3600");
            },
        );

        await testAsync(
            "credentials handling",
            func() : async () {

                let middleware = CORS.createMiddleware({
                    CORS.defaultOptions with
                    allowCredentials = true;
                });

                // Test request with credentials
                let request = createMockRequest(#get, [("Origin", "http://example.com")]);
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Request is null");

                assert (getHeader(response.headers, "Access-Control-Allow-Credentials") == ?"true");
            },
        );

        await testAsync(
            "exposed headers",
            func() : async () {

                let middleware = CORS.createMiddleware({
                    CORS.defaultOptions with
                    exposeHeaders = ["Content-Length", "X-Custom-Response"];
                });

                // Test request
                let request = createMockRequest(#get, [("Origin", "http://example.com")]);
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Request is null");

                assert (getHeader(response.headers, "Access-Control-Expose-Headers") == ?"Content-Length, X-Custom-Response");
            },
        );

        await testAsync(
            "no origin header",
            func() : async () {
                let middleware = CORS.createMiddleware(CORS.defaultOptions);
                let (httpContext, next) = createMockRequest(#get, []); // No Origin header
                let ?response = await* middleware.handleUpdate(httpContext, next) else Runtime.trap("Request is null");
                assert (getHeader(response.headers, "Access-Control-Allow-Origin") == null);
            },
        );

        await testAsync(
            "preflight request disallowed method",
            func() : async () {
                let middleware = CORS.createMiddleware({
                    CORS.defaultOptions with allowMethods = [#get, #post] // #put is not allowed

                });
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Method", "PUT") // Requesting PUT method
                    ],
                );
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Request is null");
                assert (getHeader(response.headers, "Access-Control-Allow-Methods") == ?"GET, POST");
            },
        );

        await testAsync(
            "preflight request disallowed header",
            func() : async () {
                let middleware = CORS.createMiddleware({
                    CORS.defaultOptions with allowHeaders = ["Content-Type"] // "X-Custom-Header" is not allowed

                });
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Headers", "X-Custom-Header") // Requesting X-Custom-Header
                    ],
                );
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Request is null");
                assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type"); // Should not set allow headers
            },
        );
        await testAsync(
            "preflight request with multiple request headers",
            func() : async () {
                let middleware = CORS.createMiddleware({
                    CORS.defaultOptions with allowHeaders = ["Content-Type", "Authorization"]
                });
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Headers", "Content-Type, Authorization"),
                    ],
                );
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Request is null");
                assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type, Authorization");
            },
        );

        await testAsync(
            "preflight request with case-insensitive header matching",
            func() : async () {
                let middleware = CORS.createMiddleware({
                    CORS.defaultOptions with allowHeaders = ["Content-Type"]
                });
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Headers", "content-type") // lowercase
                    ],
                );
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Request is null");
                assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type");
            },
        );

        await testAsync(
            "preflight request with no request method",
            func() : async () {
                let middleware = CORS.createMiddleware(CORS.defaultOptions);
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com")
                        // No Access-Control-Request-Method header
                    ],
                );
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Request is null");
                assert (response.statusCode == 204);
                assert (getHeader(response.headers, "Access-Control-Allow-Methods") == null);
            },
        );

        await testAsync(
            "wildcard origin with credentials",
            func() : async () {
                let middleware = CORS.createMiddleware({
                    CORS.defaultOptions with
                    allowCredentials = true;
                    allowOrigins = [];
                });
                let request = createMockRequest(
                    #get,
                    [("Origin", "http://example.com")],
                );
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Request is null");
                // Should not use wildcard with credentials
                assert (getHeader(response.headers, "Access-Control-Allow-Origin") == ?"http://example.com");
                assert (getHeader(response.headers, "Vary") == ?"Origin");
            },
        );

        await testAsync(
            "preflight request with invalid method format",
            func() : async () {
                let middleware = CORS.createMiddleware(CORS.defaultOptions);
                let request = createMockRequest(
                    #options,
                    [
                        ("Origin", "http://example.com"),
                        ("Access-Control-Request-Method", "INVALID_METHOD"),
                    ],
                );
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Request is null");
                assert (response.statusCode == 204);
                assert (getHeader(response.headers, "Access-Control-Allow-Methods") != null);
            },
        );

    },
);
