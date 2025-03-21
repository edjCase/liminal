import { test = testAsync; suite = suiteAsync } "mo:test/async";
import Types "../src/Types";
import Pipeline "../src/Pipeline";
import Blob "mo:new-base/Blob";
import Debug "mo:new-base/Debug";
import CSP "../src/CSP";
import HttpContext "../src/HttpContext";

func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
};

func createMockRequest() : (HttpContext.HttpContext, Pipeline.NextAsync) {
    let httpContext = HttpContext.HttpContext({
        method = "GET";
        url = "/test";
        headers = [];
        body = Blob.fromArray([]);
    });
    (
        httpContext,
        func() : async* ?Types.HttpResponse {
            ?{
                statusCode = 200;
                headers = [];
                body = null;
            };
        },
    );
};

await suiteAsync(
    "CSP Middleware Tests",
    func() : async () {
        await testAsync(
            "default options",
            func() : async () {
                let middleware = CSP.createMiddleware(CSP.defaultOptions);
                let request = createMockRequest();
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Response is null");
                let ?cspHeader = getHeader(response.headers, "Content-Security-Policy") else Runtime.trap("CSP header missing");

                assert (cspHeader == "default-src 'self';script-src 'self';connect-src 'self' http://localhost:* https://icp0.io https://*.icp0.io https://icp-api.io;img-src 'self' data:;style-src * 'unsafe-inline';style-src-elem * 'unsafe-inline';font-src *;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        await testAsync(
            "custom script-src directive",
            func() : async () {
                let middleware = CSP.createMiddleware({
                    CSP.defaultOptions with
                    scriptSrc = ["'self'", "'unsafe-inline'", "https://trusted-scripts.com"];
                });

                let request = createMockRequest();
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Response is null");
                let ?cspHeader = getHeader(response.headers, "Content-Security-Policy") else Runtime.trap("CSP header missing");

                assert (cspHeader == "default-src 'self';script-src 'self' 'unsafe-inline' https://trusted-scripts.com;connect-src 'self' http://localhost:* https://icp0.io https://*.icp0.io https://icp-api.io;img-src 'self' data:;style-src * 'unsafe-inline';style-src-elem * 'unsafe-inline';font-src *;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        await testAsync(
            "empty directives",
            func() : async () {
                let middleware = CSP.createMiddleware({
                    CSP.defaultOptions with
                    scriptSrc = [];
                    imgSrc = [];
                });

                let request = createMockRequest();
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Response is null");
                let ?cspHeader = getHeader(response.headers, "Content-Security-Policy") else Runtime.trap("CSP header missing");

                assert (cspHeader == "default-src 'self';connect-src 'self' http://localhost:* https://icp0.io https://*.icp0.io https://icp-api.io;style-src * 'unsafe-inline';style-src-elem * 'unsafe-inline';font-src *;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        await testAsync(
            "multiple content sources",
            func() : async () {
                let middleware = CSP.createMiddleware({
                    CSP.defaultOptions with
                    connectSrc = ["'self'", "https://api1.example.com", "https://api2.example.com"];
                    imgSrc = ["'self'", "data:", "https://images.example.com"];
                });

                let request = createMockRequest();
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Response is null");
                let ?cspHeader = getHeader(response.headers, "Content-Security-Policy") else Runtime.trap("CSP header missing");

                assert (cspHeader == "default-src 'self';script-src 'self';connect-src 'self' https://api1.example.com https://api2.example.com;img-src 'self' data: https://images.example.com;style-src * 'unsafe-inline';style-src-elem * 'unsafe-inline';font-src *;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        await testAsync(
            "preserves existing headers",
            func() : async () {
                let middleware = CSP.createMiddleware(CSP.defaultOptions);
                let httpContext = HttpContext.HttpContext({
                    method = "GET";
                    url = "/test";
                    headers = [];
                    body = Blob.fromArray([]);
                });

                let next = func() : async* ?Types.HttpResponse {
                    ?{
                        statusCode = 200;
                        headers = [("X-Custom-Header", "test-value")];
                        body = null;
                    };
                };

                let ?response = await* middleware.handleUpdate(httpContext, next) else Runtime.trap("Response is null");
                assert (getHeader(response.headers, "X-Custom-Header") == ?"test-value");
                let ?cspHeader = getHeader(response.headers, "Content-Security-Policy") else Runtime.trap("CSP header missing");
                assert (cspHeader == "default-src 'self';script-src 'self';connect-src 'self' http://localhost:* https://icp0.io https://*.icp0.io https://icp-api.io;img-src 'self' data:;style-src * 'unsafe-inline';style-src-elem * 'unsafe-inline';font-src *;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        await testAsync(
            "all directives test",
            func() : async () {
                let middleware = CSP.createMiddleware({
                    defaultSrc = ["'self'"];
                    scriptSrc = ["'self'"];
                    connectSrc = ["'self'", "https://api.example.com"];
                    imgSrc = ["'self'", "data:"];
                    styleSrc = ["'self'", "'unsafe-inline'"];
                    styleSrcElem = ["'self'"];
                    fontSrc = ["'self'", "https://fonts.example.com"];
                    objectSrc = ["'none'"];
                    baseUri = ["'self'"];
                    frameAncestors = ["'none'"];
                    formAction = ["'self'"];
                    upgradeInsecureRequests = true;
                });

                let request = createMockRequest();
                let ?response = await* middleware.handleUpdate(request) else Runtime.trap("Response is null");
                let ?cspHeader = getHeader(response.headers, "Content-Security-Policy") else Runtime.trap("CSP header missing");

                assert (cspHeader == "default-src 'self';script-src 'self';connect-src 'self' https://api.example.com;img-src 'self' data:;style-src 'self' 'unsafe-inline';style-src-elem 'self';font-src 'self' https://fonts.example.com;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        await testAsync(
            "handles null response from next",
            func() : async () {
                let middleware = CSP.createMiddleware(CSP.defaultOptions);
                let httpContext = HttpContext.HttpContext({
                    method = "GET";
                    url = "/test";
                    headers = [];
                    body = Blob.fromArray([]);
                });

                let next = func() : async* ?Types.HttpResponse {
                    null;
                };

                let response = await* middleware.handleUpdate(httpContext, next);
                assert (response == null);
            },
        );
    },
);
