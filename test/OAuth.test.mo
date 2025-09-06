import { test } "mo:test";
import OAuth "../src/Middleware/OAuth";
import Runtime "mo:core@1/Runtime";
import Text "mo:core@1/Text";
import Blob "mo:core@1/Blob";
import Nat16 "mo:core@1/Nat16";
import Liminal "../src/lib";

test(
  "OAuth middleware - integrated with Liminal app",
  func() : () {
    // Setup OAuth configuration
    let oauthStore = OAuth.inMemoryStore();
    let oauthConfig : OAuth.Config = {
      providers = [{
        name = "GitHub";
        clientId = "test-client-id";
        authorizationEndpoint = "https://github.com/login/oauth/authorize";
        tokenEndpoint = "https://github.com/login/oauth/access_token";
        scopes = ["user:email", "read:user"];
      }];
      siteUrl = "https://example.com";
      store = oauthStore;
      onLogin = func(context : Liminal.HttpContext, loginData : OAuth.LoginData) : async* Liminal.HttpResponse {
        context.buildResponse(#ok, #content(#Text("Login successful for " # loginData.providerConfig.name)));
      };
      onLogout = func(context : Liminal.HttpContext, logoutData : OAuth.LogoutData) : async* Liminal.HttpResponse {
        context.buildResponse(#ok, #content(#Text("Logout successful for " # logoutData.providerConfig.name)));
      };
    };

    // Create Liminal app with OAuth middleware
    let app = Liminal.App({
      middleware = [OAuth.new(oauthConfig)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    // Helper to create HTTP requests
    func createRequest(method : Text, url : Text) : Liminal.RawQueryHttpRequest {
      {
        method = method;
        url = url;
        headers = [];
        body = Blob.fromArray([]);
        certificate_version = null;
      };
    };

    // Test cases with expected responses
    let testCases = [
      (
        "GET",
        "https://example.com/auth/github/login",
        #upgrade, // Should trigger upgrade (redirect to OAuth provider)
        "GitHub login request",
      ),
      (
        "POST",
        "https://example.com/auth/github/login",
        #error_response(405), // Method not allowed
        "GitHub login with wrong method",
      ),
      (
        "GET",
        "https://example.com/auth/github/callback?code=test123&state=test-state",
        #upgrade, // Should trigger upgrade (process callback)
        "GitHub callback request",
      ),
      (
        "POST",
        "https://example.com/auth/github/logout",
        #upgrade, // Should trigger upgrade (process logout)
        "GitHub logout request",
      ),
      (
        "GET",
        "https://example.com/auth/github/logout",
        #error_response(405), // Method not allowed
        "GitHub logout with wrong method",
      ),
      (
        "GET",
        "https://example.com/auth/unknown/login",
        #error_response(404), // Provider not found
        "Unknown provider request",
      ),
      (
        "GET",
        "https://example.com/auth/github/invalid",
        #error_response(404), // Invalid route
        "Invalid OAuth route",
      ),
      (
        "GET",
        "https://example.com/other/path",
        #error_response(404), // No route handler, fallback to 404
        "Non-OAuth path",
      ),
    ];

    for ((method, url, expectedResult, description) in testCases.vals()) {
      let request = createRequest(method, url);
      let response = app.http_request(request);

      // Check the response matches expectations
      switch (expectedResult) {
        case (#upgrade) {
          // For OAuth flows that require async processing, we expect upgrade=true
          switch (response.upgrade) {
            case (?true) {
              // Success - app wants to upgrade to async
            };
            case (_) {
              Runtime.trap("Expected upgrade for " # description # ", got upgrade=" # debug_show (response.upgrade));
            };
          };
        };
        case (#error_response(expectedStatus)) {
          // For errors, we expect a specific status code and no upgrade
          let actualStatus = Nat16.toNat(response.status_code);
          if (actualStatus != expectedStatus) {
            Runtime.trap("Wrong status for " # description # ": expected " # debug_show (expectedStatus) # ", got " # debug_show (actualStatus));
          };
          switch (response.upgrade) {
            case (?true) {
              Runtime.trap("Should not upgrade for error response: " # description);
            };
            case (_) {
              // Correct - no upgrade for error responses
            };
          };
        };
      };
    };
  },
);

test(
  "OAuth middleware - multiple providers in app",
  func() : () {
    let oauthStore = OAuth.inMemoryStore();
    let oauthConfig : OAuth.Config = {
      providers = [
        {
          name = "GitHub";
          clientId = "github-client-id";
          authorizationEndpoint = "https://github.com/login/oauth/authorize";
          tokenEndpoint = "https://github.com/login/oauth/access_token";
          scopes = ["user:email"];
        },
        {
          name = "Google";
          clientId = "google-client-id";
          authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth";
          tokenEndpoint = "https://oauth2.googleapis.com/token";
          scopes = ["openid", "email", "profile"];
        },
      ];
      siteUrl = "https://myapp.com";
      store = oauthStore;
      onLogin = func(context : Liminal.HttpContext, loginData : OAuth.LoginData) : async* Liminal.HttpResponse {
        context.buildResponse(#ok, #content(#Text("Login: " # loginData.providerConfig.name)));
      };
      onLogout = func(context : Liminal.HttpContext, logoutData : OAuth.LogoutData) : async* Liminal.HttpResponse {
        context.buildResponse(#ok, #content(#Text("Logout: " # logoutData.providerConfig.name)));
      };
    };

    let app = Liminal.App({
      middleware = [OAuth.new(oauthConfig)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    func createRequest(method : Text, url : Text) : Liminal.RawQueryHttpRequest {
      {
        method = method;
        url = url;
        headers = [];
        body = Blob.fromArray([]);
        certificate_version = null;
      };
    };

    // Test both providers work with case insensitive matching
    let providerTests = [
      ("github", "GitHub provider"),
      ("google", "Google provider"),
      ("GITHUB", "GitHub provider (uppercase)"),
      ("Google", "Google provider (mixed case)"),
    ];

    for ((providerName, description) in providerTests.vals()) {
      let request = createRequest("GET", "https://myapp.com/auth/" # providerName # "/login");
      let response = app.http_request(request);

      // All valid providers should trigger upgrade
      switch (response.upgrade) {
        case (?true) {
          // Success - valid provider should upgrade
        };
        case (_) {
          if (Nat16.toNat(response.status_code) == 404) {
            Runtime.trap("Provider not found for " # description # ": " # providerName);
          } else {
            Runtime.trap("Expected upgrade for valid provider " # description # ", got status " # debug_show (Nat16.toNat(response.status_code)));
          };
        };
      };
    };
  },
);

test(
  "OAuth middleware - callback handling via app.http_request",
  func() : () {
    let oauthStore = OAuth.inMemoryStore();
    let oauthConfig : OAuth.Config = {
      providers = [{
        name = "GitHub";
        clientId = "test-client-id";
        authorizationEndpoint = "https://github.com/login/oauth/authorize";
        tokenEndpoint = "https://github.com/login/oauth/access_token";
        scopes = ["user:email"];
      }];
      siteUrl = "https://example.com";
      store = oauthStore;
      onLogin = func(context : Liminal.HttpContext, _ : OAuth.LoginData) : async* Liminal.HttpResponse {
        context.buildResponse(#ok, #content(#Text("OAuth login completed")));
      };
      onLogout = func(context : Liminal.HttpContext, _ : OAuth.LogoutData) : async* Liminal.HttpResponse {
        context.buildResponse(#ok, #content(#Text("OAuth logout completed")));
      };
    };

    let app = Liminal.App({
      middleware = [OAuth.new(oauthConfig)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    // Test callback scenarios
    let callbackTests = [
      (
        "https://example.com/auth/github/callback?code=auth123&state=valid-state",
        "Valid callback with code and state",
      ),
      (
        "https://example.com/auth/github/callback?error=access_denied&error_description=User%20denied%20access",
        "Callback with OAuth error",
      ),
      (
        "https://example.com/auth/github/callback",
        "Callback without required parameters",
      ),
    ];

    for ((url, description) in callbackTests.vals()) {
      let request : Liminal.RawQueryHttpRequest = {
        method = "GET";
        url = url;
        headers = [];
        body = Blob.fromArray([]);
        certificate_version = null;
      };
      let response = app.http_request(request);

      // All callback requests should trigger upgrade for async processing
      switch (response.upgrade) {
        case (?true) {
          // Success - callback processing requires async upgrade
        };
        case (_) {
          let status = Nat16.toNat(response.status_code);
          if (status >= 400) {
            // Error responses don't upgrade, that's fine
          } else {
            Runtime.trap("Expected upgrade for " # description # ", got status " # debug_show (status));
          };
        };
      };
    };
  },
);

test(
  "OAuth middleware - error handling via app.http_request",
  func() : () {
    let oauthStore = OAuth.inMemoryStore();
    let oauthConfig : OAuth.Config = {
      providers = [{
        name = "GitHub";
        clientId = "test-client-id";
        authorizationEndpoint = "https://github.com/login/oauth/authorize";
        tokenEndpoint = "https://github.com/login/oauth/access_token";
        scopes = ["user:email"];
      }];
      siteUrl = "https://example.com";
      store = oauthStore;
      onLogin = func(context : Liminal.HttpContext, _ : OAuth.LoginData) : async* Liminal.HttpResponse {
        context.buildResponse(#ok, #content(#Text("Login success")));
      };
      onLogout = func(context : Liminal.HttpContext, _ : OAuth.LogoutData) : async* Liminal.HttpResponse {
        context.buildResponse(#ok, #content(#Text("Logout success")));
      };
    };

    let app = Liminal.App({
      middleware = [OAuth.new(oauthConfig)];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
    });

    // Test various error scenarios
    let errorTests = [
      (
        "POST",
        "https://example.com/auth/github/login",
        405,
        "Method not allowed for login",
      ),
      (
        "GET",
        "https://example.com/auth/github/logout",
        405,
        "Method not allowed for logout",
      ),
      (
        "GET",
        "https://example.com/auth/nonexistent/login",
        404,
        "Unknown OAuth provider",
      ),
      (
        "GET",
        "https://example.com/auth/github/unknown-action",
        404,
        "Unknown OAuth action",
      ),
      (
        "PUT",
        "https://example.com/auth/github/callback",
        405,
        "Wrong method for callback",
      ),
    ];

    for ((method, url, expectedStatus, description) in errorTests.vals()) {
      let request : Liminal.RawQueryHttpRequest = {
        method = method;
        url = url;
        headers = [];
        body = Blob.fromArray([]);
        certificate_version = null;
      };
      let response = app.http_request(request);

      let actualStatus = Nat16.toNat(response.status_code);
      if (actualStatus != expectedStatus) {
        Runtime.trap("Wrong status for " # description # ": expected " # debug_show (expectedStatus) # ", got " # debug_show (actualStatus));
      };

      // Error responses should not trigger upgrade
      switch (response.upgrade) {
        case (?true) {
          Runtime.trap("Error response should not upgrade: " # description);
        };
        case (_) {
          // Correct - no upgrade for error responses
        };
      };
    };
  },
);
