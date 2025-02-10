import { test; suite } "mo:test";
import Types "../src/Types";
import Pipeline "../src/Pipeline";
import Blob "mo:base/Blob";
import HttpMethod "../src/HttpMethod";
import Cors "../src/Middleware/Cors";
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
            "default CORS settings",
            func() {
                let middleware = Cors.createMiddleware(Cors.defaultOptions);

                let (httpContext, next) = createMockRequest(#get, [("Origin", "http://example.com")]);
                let response = middleware.handle(httpContext, next);

                assert (getHeader(response.headers, "Access-Control-Allow-Origin") == ?"*");
            },
        );

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

                // Test with different origin
                let request2 = createMockRequest(#get, [("Origin", "http://other-domain.com")]);
                let response2 = middleware.handle(request2);
                assert (getHeader(response2.headers, "Access-Control-Allow-Origin") == null);
            },
        );

        test(
            "preflight request handling",
            func() {

                let middleware = Cors.createMiddleware({
                    Cors.defaultOptions with
                    allowMethods = [#get, #post, #put];
                    allowHeaders = ["Content-Type", "X-Custom-Header"];
                    maxAge = 3600;
                });

                // Test OPTIONS request
                let request = createMockRequest(#options, [("Origin", "http://example.com")]);
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

    },
);
