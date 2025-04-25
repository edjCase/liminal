import { test; suite } "mo:test";
import CSP "../src/CSP";

suite(
    "CSP Middleware Tests",
    func() : () {
        test(
            "default options",
            func() : () {
                let cspHeader = CSP.buildHeaderValue(CSP.defaultOptions);

                assert (cspHeader == "default-src 'self';script-src 'self';connect-src 'self' http://localhost:* https://icp0.io https://*.icp0.io https://icp-api.io;img-src 'self' data:;style-src * 'unsafe-inline';style-src-elem * 'unsafe-inline';font-src *;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        test(
            "custom script-src directive",
            func() : () {
                let cspHeader = CSP.buildHeaderValue({
                    CSP.defaultOptions with
                    scriptSrc = ["'self'", "'unsafe-inline'", "https://trusted-scripts.com"];
                });

                assert (cspHeader == "default-src 'self';script-src 'self' 'unsafe-inline' https://trusted-scripts.com;connect-src 'self' http://localhost:* https://icp0.io https://*.icp0.io https://icp-api.io;img-src 'self' data:;style-src * 'unsafe-inline';style-src-elem * 'unsafe-inline';font-src *;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        test(
            "empty directives",
            func() : () {
                let cspHeader = CSP.buildHeaderValue({
                    CSP.defaultOptions with
                    scriptSrc = [];
                    imgSrc = [];
                });

                assert (cspHeader == "default-src 'self';connect-src 'self' http://localhost:* https://icp0.io https://*.icp0.io https://icp-api.io;style-src * 'unsafe-inline';style-src-elem * 'unsafe-inline';font-src *;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        test(
            "multiple content sources",
            func() : () {
                let cspHeader = CSP.buildHeaderValue({
                    CSP.defaultOptions with
                    connectSrc = ["'self'", "https://api1.example.com", "https://api2.example.com"];
                    imgSrc = ["'self'", "data:", "https://images.example.com"];
                });

                assert (cspHeader == "default-src 'self';script-src 'self';connect-src 'self' https://api1.example.com https://api2.example.com;img-src 'self' data: https://images.example.com;style-src * 'unsafe-inline';style-src-elem * 'unsafe-inline';font-src *;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );

        test(
            "all directives test",
            func() : () {
                let cspHeader = CSP.buildHeaderValue({
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

                assert (cspHeader == "default-src 'self';script-src 'self';connect-src 'self' https://api.example.com;img-src 'self' data:;style-src 'self' 'unsafe-inline';style-src-elem 'self';font-src 'self' https://fonts.example.com;object-src 'none';base-uri 'self';frame-ancestors 'none';form-action 'self';upgrade-insecure-requests");
            },
        );
    },
);
