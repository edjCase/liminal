import { test } "mo:test";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Blob "mo:new-base/Blob";
import Iter "mo:new-base/Iter";
import Liminal "../src/lib";
import CSPMiddleware "../src/Middleware/CSP";
import RouterMiddleware "../src/Middleware/Router";
import Router "../src/Router";
import HttpMethod "../src/HttpMethod";

// Helper function to find header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
};

// Helper to create a basic app with CSP middleware
func createAppWithCSP(cspOptions : ?CSPMiddleware.Options) : Liminal.App {
    let options = switch (cspOptions) {
        case (?opts) opts;
        case (null) CSPMiddleware.defaultOptions;
    };

    let routerConfig : RouterMiddleware.Config = {
        prefix = null;
        identityRequirement = null;
        routes = [
            Router.getQuery(
                "/",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "text/html")];
                        body = ?"<html><body>Hello World</body></html>";
                        streamingStrategy = null;
                    };
                },
            ),
            Router.getQuery(
                "/api/data",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "application/json")];
                        body = ?"{\"data\": \"test\"}";
                        streamingStrategy = null;
                    };
                },
            ),
            Router.postQuery(
                "/submit",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "application/json")];
                        body = ?"{\"success\": true}";
                        streamingStrategy = null;
                    };
                },
            ),
            Router.getQuery(
                "/test",
                func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                    {
                        statusCode = 200;
                        headers = [("Content-Type", "text/html")];
                        body = ?"<html><body>Test</body></html>";
                        streamingStrategy = null;
                    };
                },
            ),
        ];
    };

    Liminal.App({
        middleware = [
            CSPMiddleware.new(options),
            RouterMiddleware.new(routerConfig),
        ];
        errorSerializer = Liminal.defaultJsonErrorSerializer;
        candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
        logger = Liminal.debugLogger;
    });
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

// Test 1: Default CSP headers are added
test(
    "should add default CSP headers",
    func() : () {
        let app = createAppWithCSP(null);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasCorrectStatus = response.status_code == 200;
        let hasCorrectCSP = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("default-src 'self'")) and Text.contains(csp, #text("script-src 'self'")) and Text.contains(csp, #text("object-src 'none'"));
            };
            case (null) false;
        };

        assert (hasCorrectStatus and hasCorrectCSP);
    },
);

// Test 2: Custom script-src policy
test(
    "should handle custom script-src policy",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            scriptSrc = ["'self'", "https://cdn.example.com", "'unsafe-inline'"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);
        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("script-src 'self' https://cdn.example.com 'unsafe-inline'"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 3: Custom img-src policy
test(
    "should handle custom img-src policy",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            imgSrc = ["'self'", "data:", "https://*.example.com"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("img-src 'self' data: https://*.example.com"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 4: Frame ancestors policy
test(
    "should handle frame-ancestors policy",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            frameAncestors = ["'self'", "https://trusted-parent.com"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("frame-ancestors 'self' https://trusted-parent.com"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 5: Connect-src policy for API endpoints
test(
    "should handle connect-src policy",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            connectSrc = ["'self'", "https://api.example.com", "wss://websocket.example.com"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/api/data",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("connect-src 'self' https://api.example.com wss://websocket.example.com"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 6: Style-src policy
test(
    "should handle style-src policy",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            styleSrc = ["'self'", "https://fonts.googleapis.com"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("style-src 'self' https://fonts.googleapis.com"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 7: Font-src policy
test(
    "should handle font-src policy",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            fontSrc = ["'self'", "https://fonts.gstatic.com", "data:"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("font-src 'self' https://fonts.gstatic.com data:"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 8: Object-src none policy
test(
    "should handle object-src none policy",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            objectSrc = ["'none'"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("object-src 'none'"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 9: Base-uri policy
test(
    "should handle base-uri policy",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            baseUri = ["'self'"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("base-uri 'self'"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 10: Form-action policy
test(
    "should handle form-action policy",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            formAction = ["'self'", "https://forms.example.com"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("form-action 'self' https://forms.example.com"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 11: Upgrade insecure requests
test(
    "should handle upgrade-insecure-requests",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            upgradeInsecureRequests = true;
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("upgrade-insecure-requests"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 12: Disable upgrade insecure requests
test(
    "should not include upgrade-insecure-requests when disabled",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            upgradeInsecureRequests = false;
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                not Text.contains(csp, #text("upgrade-insecure-requests"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 13: Empty directives are omitted
test(
    "should omit empty directives",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            scriptSrc = []; // Empty directive
            styleSrc = ["'self'"]; // Non-empty directive
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                not Text.contains(csp, #text("script-src")) and Text.contains(csp, #text("style-src 'self'"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 14: Style-src-elem directive
test(
    "should handle style-src-elem directive",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            styleSrcElem = ["'self'", "'unsafe-inline'"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("style-src-elem 'self' 'unsafe-inline'"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 15: Restrictive policy for sensitive content
test(
    "should handle restrictive policy for sensitive content",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            defaultSrc = ["'none'"];
            scriptSrc = ["'self'"];
            styleSrc = ["'self'"];
            imgSrc = ["'self'"];
            connectSrc = ["'self'"];
            fontSrc = ["'none'"];
            objectSrc = ["'none'"];
            frameAncestors = ["'none'"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("default-src 'none'")) and Text.contains(csp, #text("script-src 'self'")) and Text.contains(csp, #text("frame-ancestors 'none'"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 16: CSP headers are preserved with other headers
test(
    "should preserve existing headers while adding CSP",
    func() : () {

        let app = createAppWithCSP(null);

        let request = createRequest(
            #get,
            "/test",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasCSP = Array.any<(Text, Text)>(
            response.headers,
            func((name, value)) {
                name == "Content-Security-Policy";
            },
        );
        let hasContentType = Array.any<(Text, Text)>(
            response.headers,
            func((name, value)) {
                name == "Content-Type" and value == "text/html"
            },
        );
        let hasCacheControl = Array.any<(Text, Text)>(
            response.headers,
            func((name, value)) {
                name == "Cache-Control" and value == "no-cache"
            },
        );
        let hasCustomHeader = Array.any<(Text, Text)>(
            response.headers,
            func((name, value)) {
                name == "X-Custom-Header" and value == "custom-value"
            },
        );

        assert (response.status_code == 200 and hasCSP and hasContentType and hasCacheControl and hasCustomHeader);
    },
);

// Test 17: CSP with nonce for inline scripts
test(
    "should support nonce-based CSP for inline scripts",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            scriptSrc = ["'self'", "'nonce-abc123'"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("script-src 'self' 'nonce-abc123'"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 18: CSP with hash-based inline content
test(
    "should support hash-based CSP for inline content",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            styleSrc = ["'self'", "'sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU='"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("style-src 'self' 'sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU='"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 19: CSP works on different HTTP methods
test(
    "should apply CSP headers to POST requests",
    func() : () {
        let app = createAppWithCSP(null);

        let request = createRequest(
            #post,
            "/submit",
            [("Content-Type", "application/json")],
            "{\"data\": \"test\"}",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                Text.contains(csp, #text("default-src 'self'"));
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);

// Test 20: CSP header format validation
test(
    "should generate properly formatted CSP header",
    func() : () {
        let cspOptions = {
            CSPMiddleware.defaultOptions with
            defaultSrc = ["'self'"];
            scriptSrc = ["'self'", "https://cdn.example.com"];
            styleSrc = ["'self'", "'unsafe-inline'"];
        };
        let app = createAppWithCSP(?cspOptions);

        let request = createRequest(
            #get,
            "/",
            [],
            "",
        );

        let response = app.http_request(request);

        let hasHeader = switch (getHeader(response.headers, "Content-Security-Policy")) {
            case (?csp) {
                // Check that directives are separated by semicolons
                let parts = Text.split(csp, #char ';');
                Array.size(Iter.toArray(parts)) >= 3; // Should have multiple directives
            };
            case (null) false;
        };

        assert (response.status_code == 200 and hasHeader);
    },
);
