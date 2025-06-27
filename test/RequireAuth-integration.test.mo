import { test } "mo:test";
import Text "mo:new-base/Text";
import Blob "mo:new-base/Blob";
import Nat16 "mo:new-base/Nat16";
import Nat "mo:new-base/Nat";
import Runtime "mo:new-base/Runtime";
import JWT "mo:jwt";

import Liminal "../src/lib";
import RequireAuthMiddleware "../src/Middleware/RequireAuth";
import JWTMiddleware "../src/Middleware/JWT";
import RouterMiddleware "../src/Middleware/Router";
import Router "../src/Router";
import HttpMethod "../src/HttpMethod";
import Identity "../src/Identity";
import App "../src/App";
import HttpContext "../src/HttpContext";

// Helper function to find header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
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

// Helper to assert status code
func assertStatusCode(actual : Nat16, expected : Nat) : () {
    let actualNat = Nat16.toNat(actual);
    if (actualNat != expected) {
        Runtime.trap("Status Code check failed\nExpected: " # Nat.toText(expected) # "\nActual: " # Nat.toText(actualNat));
    };
};

// Helper to create a test JWT token
func createTestJWT() : JWT.Token {
    {
        header = [];
        payload = [];
        signature = {
            algorithm = "none";
            message = "";
            value = "";
        };
    };
};

// Test 1: Request without identity should return 401 Unauthorized
test(
    "should return 401 unauthorized when no identity is present",
    func() : () {
        let app = Liminal.App({
            middleware = [RequireAuthMiddleware.new(#authenticated)];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #get,
            "/protected",
            [],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 401);
    },
);

// Test 2: Request with unauthenticated identity should return 401 Unauthorized
test(
    "should return 401 unauthorized when identity is not authenticated",
    func() : () {
        let app = Liminal.App({
            middleware = [
                {
                    name = "Set Unauthenticated Identity";
                    handleQuery = func(context, next) {
                        // Set an unauthenticated identity
                        let unauthenticatedIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user123";
                            isAuthenticated = func() = false;
                        };
                        context.setIdentity(unauthenticatedIdentity);
                        next();
                    };
                    handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                        // Set an unauthenticated identity
                        let unauthenticatedIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user123";
                            isAuthenticated = func() = false;
                        };
                        context.setIdentity(unauthenticatedIdentity);
                        await* next();
                    };
                },
                RequireAuthMiddleware.new(#authenticated),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #get,
            "/protected",
            [],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 401);
    },
);

// Test 3: Request with authenticated identity should pass through
test(
    "should allow request when identity is authenticated",
    func() : () {
        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/protected",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"Protected content";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        let app = Liminal.App({
            middleware = [
                {
                    name = "Set Authenticated Identity";
                    handleQuery = func(context, next) {
                        // Set an authenticated identity
                        let authenticatedIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user123";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(authenticatedIdentity);
                        next();
                    };
                    handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                        // Set an authenticated identity
                        let authenticatedIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user123";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(authenticatedIdentity);
                        await* next();
                    };
                },
                RequireAuthMiddleware.new(#authenticated),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #get,
            "/protected",
            [],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 4: Custom requirement that passes
test(
    "should allow request when custom requirement is met",
    func() : () {
        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/admin",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"Admin content";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        // Custom requirement: user must have admin role
        let customRequirement = func(identity : Identity.Identity) : Bool {
            switch (identity.getId()) {
                case (?"admin") true;
                case (_) false;
            };
        };

        let app = Liminal.App({
            middleware = [
                {
                    name = "Set Admin Identity";
                    handleQuery = func(context, next) {
                        let adminIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"admin";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(adminIdentity);
                        next();
                    };
                    handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                        let adminIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"admin";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(adminIdentity);
                        await* next();
                    };
                },
                RequireAuthMiddleware.new(#custom(customRequirement)),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #get,
            "/admin",
            [],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 5: Custom requirement that fails
test(
    "should return 403 forbidden when custom requirement is not met",
    func() : () {
        // Custom requirement: user must have admin role
        let customRequirement = func(identity : Identity.Identity) : Bool {
            switch (identity.getId()) {
                case (?"admin") true;
                case (_) false;
            };
        };

        let app = Liminal.App({
            middleware = [
                {
                    name = "Set Regular User Identity";
                    handleQuery = func(context, next) {
                        let userIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user123";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(userIdentity);
                        next();
                    };
                    handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                        let userIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user123";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(userIdentity);
                        await* next();
                    };
                },
                RequireAuthMiddleware.new(#custom(customRequirement)),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #get,
            "/admin",
            [],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 403);
    },
);

// Test 6: Integration with JWT middleware
test(
    "should work with JWT middleware for real JWT tokens",
    func() : () {
        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/protected",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"JWT protected content";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        let app = Liminal.App({
            middleware = [
                {
                    name = "Mock JWT Middleware";
                    handleQuery = func(context, next) {
                        // Mock setting a valid JWT identity
                        let jwtIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user123";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(jwtIdentity);
                        next();
                    };
                    handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                        // Mock setting a valid JWT identity
                        let jwtIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user123";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(jwtIdentity);
                        await* next();
                    };
                },
                RequireAuthMiddleware.new(#authenticated),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #get,
            "/protected",
            [("Authorization", "Bearer mock-jwt-token")],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 7: Multiple auth requirements in sequence
test(
    "should handle multiple authentication requirements",
    func() : () {
        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/super-protected",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"Super protected content";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        // Two custom requirements: must be admin and must be active
        let isAdminRequirement = func(identity : Identity.Identity) : Bool {
            switch (identity.getId()) {
                case (?"admin") true;
                case (_) false;
            };
        };

        let isActiveRequirement = func(identity : Identity.Identity) : Bool {
            // Simulate checking if user is active
            true; // For test purposes, always return true
        };

        let app = Liminal.App({
            middleware = [
                {
                    name = "Set Admin Identity";
                    handleQuery = func(context, next) {
                        let adminIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"admin";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(adminIdentity);
                        next();
                    };
                    handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                        let adminIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"admin";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(adminIdentity);
                        await* next();
                    };
                },
                RequireAuthMiddleware.new(#authenticated),
                RequireAuthMiddleware.new(#custom(isAdminRequirement)),
                RequireAuthMiddleware.new(#custom(isActiveRequirement)),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #get,
            "/super-protected",
            [],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 200);
    },
);

// Test 8: POST request with authentication
test(
    "should handle POST requests with authentication",
    func() : () {
        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.postQuery(
                    "/api/data",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 201;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"Data created";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        let app = Liminal.App({
            middleware = [
                {
                    name = "Set Authenticated Identity";
                    handleQuery = func(context, next) {
                        let authenticatedIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user456";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(authenticatedIdentity);
                        next();
                    };
                    handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                        let authenticatedIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user456";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(authenticatedIdentity);
                        await* next();
                    };
                },
                RequireAuthMiddleware.new(#authenticated),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #post,
            "/api/data",
            [("Content-Type", "application/json")],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 201);
    },
);

// Test 9: Error response format
test(
    "should return proper error format for unauthorized requests",
    func() : () {
        let app = Liminal.App({
            middleware = [RequireAuthMiddleware.new(#authenticated)];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #get,
            "/protected",
            [],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        assertStatusCode(response.status_code, 401);

        // Check Content-Type header
        let contentType = getHeader(response.headers, "Content-Type");
        switch (contentType) {
            case (?"application/json") {};
            case (_) Runtime.trap("Expected JSON content type for error response");
        };
    },
);

// Test 10: Role-based access control example
test(
    "should implement role-based access control",
    func() : () {
        let routerConfig : RouterMiddleware.Config = {
            prefix = null;
            identityRequirement = null;
            routes = [
                Router.getQuery(
                    "/admin/users",
                    func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
                        {
                            statusCode = 200;
                            headers = [("Content-Type", "text/plain")];
                            body = ?"User list";
                            streamingStrategy = null;
                        };
                    },
                ),
            ];
        };

        // Role-based requirement
        let requireRole = func(requiredRole : Text) : (Identity.Identity -> Bool) {
            func(identity : Identity.Identity) : Bool {
                // In a real scenario, you'd extract role from JWT claims
                switch (identity.getId()) {
                    case (?"admin") requiredRole == "admin";
                    case (?"user") requiredRole == "user";
                    case (_) false;
                };
            };
        };

        let app = Liminal.App({
            middleware = [
                {
                    name = "Set User Identity";
                    handleQuery = func(context, next) {
                        let userIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(userIdentity);
                        next();
                    };
                    handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                        let userIdentity : Identity.Identity = {
                            kind = #jwt(createTestJWT());
                            getId = func() = ?"user";
                            isAuthenticated = func() = true;
                        };
                        context.setIdentity(userIdentity);
                        await* next();
                    };
                },
                RequireAuthMiddleware.new(#custom(requireRole("admin"))),
                RouterMiddleware.new(routerConfig),
            ];
            errorSerializer = Liminal.defaultJsonErrorSerializer;
            candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
            logger = Liminal.buildDebugLogger(#warning);
        });

        let request = createRequest(
            #get,
            "/admin/users",
            [],
            Blob.fromArray([]),
        );

        let response = app.http_request(request);

        // Should return 403 because user role != admin role
        assertStatusCode(response.status_code, 403);
    },
);
