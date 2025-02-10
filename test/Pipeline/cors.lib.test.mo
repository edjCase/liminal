import { test; suite } "mo:test";
import Types "../../src/Types";
import Pipeline "../../src/Pipeline";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Middleware "../../src/Middleware";

// Helper function to find header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
};

// Helper to create mock request
func createMockRequest(method : Types.HttpMethod, headers : [(Text, Text)]) : Types.HttpRequest {
    {
        method = method;
        url = "/test";
        headers = headers;
        body = "";
    };
};

suite(
    "CORS Middleware Tests",
    func() {

        test(
            "default CORS settings",
            func() {

                // Add CORS middleware with default options
                let pipeline = Pipeline.empty()
                |> Middleware.useCors(
                    _,
                    {
                        allowOrigins = null;
                        allowMethods = null;
                        allowHeaders = null;
                        maxAge = null;
                        allowCredentials = null;
                        exposeHeaders = null;
                    },
                )
                |> Pipeline.build(_);

                // Test regular request
                let request = createMockRequest(#get, [("Origin", "http://example.com")]);
                let response = pipeline.http_request_update(request);

                assert (getHeader(response.headers, "Access-Control-Allow-Origin") == ?"*");
            },
        );

        test(
            "custom origin handling",
            func() {
                // Add CORS middleware with specific origin
                let pipeline = Pipeline.empty()
                |> Middleware.useCors({
                    allowOrigins = ?["http://allowed-domain.com"];
                    allowMethods = null;
                    allowHeaders = null;
                    maxAge = null;
                    allowCredentials = null;
                    exposeHeaders = null;
                })
                |> Pipeline.build(_);

                // Test with allowed origin
                let request1 = createMockRequest(#get, [("Origin", "http://allowed-domain.com")]);
                let response1 = router.handle(request1);
                assert (getHeader(response1.headers, "Access-Control-Allow-Origin") == ?"http://allowed-domain.com");

                // Test with different origin
                let request2 = createMockRequest(#get, [("Origin", "http://other-domain.com")]);
                let response2 = router.handle(request2);
                assert (getHeader(response2.headers, "Access-Control-Allow-Origin") == ?"http://allowed-domain.com");
            },
        );

        test(
            "preflight request handling",
            func() {

                // Add CORS middleware with custom methods and headers
                let pipeline = Pipeline.empty()
                |> Middleware.useCors({
                    allowOrigins = null;
                    allowMethods = ?[#get, #post, #put];
                    allowHeaders = ?["Content-Type", "X-Custom-Header"];
                    maxAge = ?3600;
                    allowCredentials = null;
                    exposeHeaders = null;
                })
                |> Pipeline.build(_);

                // Test OPTIONS request
                let request = createMockRequest(#options, [("Origin", "http://example.com")]);
                let response = router.handle(request);

                assert (response.status_code == 204);
                assert (getHeader(response.headers, "Access-Control-Allow-Methods") == ?"GET, POST, PUT");
                assert (getHeader(response.headers, "Access-Control-Allow-Headers") == ?"Content-Type, X-Custom-Header");
                assert (getHeader(response.headers, "Access-Control-Max-Age") == ?"3600");
            },
        );

        test(
            "credentials handling",
            func() {

                // Add CORS middleware with credentials enabled
                let pipeline = Pipeline.empty()
                |> Middleware.useCors({
                    allowOrigins = null;
                    allowMethods = null;
                    allowHeaders = null;
                    maxAge = null;
                    allowCredentials = ?true;
                    exposeHeaders = null;
                })
                |> Pipeline.build(_);

                // Test request with credentials
                let request = createMockRequest(#get, [("Origin", "http://example.com")]);
                let response = pipeline.http_request_update(request);

                assert (getHeader(response.headers, "Access-Control-Allow-Credentials") == ?"true");
            },
        );

        test(
            "exposed headers",
            func() {

                // Add CORS middleware with exposed headers
                let pipeline = Pipeline.empty()
                |> Middleware.useCors({
                    allowOrigins = null;
                    allowMethods = null;
                    allowHeaders = null;
                    maxAge = null;
                    allowCredentials = null;
                    exposeHeaders = ?["Content-Length", "X-Custom-Response"];
                })
                |> Pipeline.build(_);

                // Test request
                let request = createMockRequest(#get, [("Origin", "http://example.com")]);
                let response = router.handle(request);

                assert (getHeader(response.headers, "Access-Control-Expose-Headers") == ?"Content-Length, X-Custom-Response");
            },
        );

    },
);
