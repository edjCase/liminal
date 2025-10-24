import { test } "mo:test/async";
import Text "mo:core@1/Text";
import Blob "mo:core@1/Blob";
import Nat16 "mo:core@1/Nat16";
import Nat "mo:core@1/Nat";
import Runtime "mo:core@1/Runtime";
import Time "mo:core@1/Time";
import Int "mo:core@1/Int";

import Liminal "../src/lib";
import SessionMiddleware "../src/Middleware/Session";
import RouterMiddleware "../src/Middleware/Router";
import Router "../src/Router";
import HttpMethod "../src/HttpMethod";
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

// Helper to extract session ID from Set-Cookie header
func extractSessionId(setCookieHeader : Text, cookieName : Text) : ?Text {
  let prefix = cookieName # "=";
  if (Text.startsWith(setCookieHeader, #text(prefix))) {
    let withoutPrefix = Text.stripStart(setCookieHeader, #text(prefix));
    switch (withoutPrefix) {
      case (?remaining) {
        // Find the end of the session ID (before ';' or end of string)
        let parts = Text.split(remaining, #char(';'));
        switch (parts.next()) {
          case (?sessionId) ?Text.trim(sessionId, #text(" "));
          case (null) null;
        };
      };
      case (null) null;
    };
  } else {
    null;
  };
};

let urlNormalizationOptions = {
  pathIsCaseSensitive = true;
  preserveTrailingSlash = true;
  queryKeysAreCaseSensitive = true;
  removeEmptyPathSegments = false;
  resolvePathDotSegments = false;
  usernameIsCaseSensitive = true;
};

// Test 1: Session creation with default config
await test(
  "should create new session with default config",
  func() : async () {
    let routerConfig : RouterMiddleware.Config = {
      prefix = null;
      identityRequirement = null;
      routes = [
        Router.getQuery(
          "/test",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let session = ctx.httpContext.session;
            switch (session) {
              case (?s) {
                ctx.buildResponse(#ok, #text("Session ID: " # s.id));
              };
              case (null) {
                ctx.buildResponse(#internalServerError, #text("No session found"));
              };
            };
          },
        ),
      ];
    };

    let app = Liminal.App({
      middleware = [
        SessionMiddleware.inMemoryDefault(),
        RouterMiddleware.new(routerConfig),
      ];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
      urlNormalization = urlNormalizationOptions;
    });

    let request = createRequest(
      #get,
      "/test",
      [],
      Blob.fromArray([]),
    );

    let response = await* app.http_request_update(request);

    assertStatusCode(response.status_code, 200);

    // Check that Set-Cookie header is present
    let setCookieHeader = getHeader(response.headers, "Set-Cookie");
    switch (setCookieHeader) {
      case (?cookie) {
        assert (Text.contains(cookie, #text("session=")));
        assert (Text.contains(cookie, #text("Path=/")));
        assert (Text.contains(cookie, #text("HttpOnly")));
        assert (Text.contains(cookie, #text("SameSite=Lax")));
      };
      case (null) Runtime.trap("Expected Set-Cookie header");
    };
  },
);

// Test 2: Session persistence across requests
await test(
  "should persist session data across requests",
  func() : async () {
    let routerConfig : RouterMiddleware.Config = {
      prefix = null;
      identityRequirement = null;
      routes = [
        Router.getQuery(
          "/set",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            session.set("username", "testuser");
            session.set("role", "admin");
            ctx.buildResponse(#ok, #text("Data set"));
          },
        ),
        Router.getQuery(
          "/get",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            let username = switch (session.get("username")) {
              case (?u) u;
              case (null) "none";
            };
            let role = switch (session.get("role")) {
              case (?r) r;
              case (null) "none";
            };
            ctx.buildResponse(#ok, #text("username=" # username # ",role=" # role));
          },
        ),
      ];
    };

    let app = Liminal.App({
      middleware = [
        SessionMiddleware.inMemoryDefault(),
        RouterMiddleware.new(routerConfig),
      ];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
      urlNormalization = urlNormalizationOptions;
    });

    // First request: set session data
    let setRequest = createRequest(
      #get,
      "/set",
      [],
      Blob.fromArray([]),
    );

    let setResponse = await* app.http_request_update(setRequest);
    assertStatusCode(setResponse.status_code, 200);

    // Extract session ID from Set-Cookie header
    let ?setCookieHeader = getHeader(setResponse.headers, "Set-Cookie") else Runtime.trap("Expected Set-Cookie header");
    let ?sessionId = extractSessionId(setCookieHeader, "session") else Runtime.trap("Could not extract session ID");

    // Second request: get session data using the session cookie
    let getRequest = createRequest(
      #get,
      "/get",
      [("Cookie", "session=" # sessionId)],
      Blob.fromArray([]),
    );

    let getResponse = await* app.http_request_update(getRequest);
    assertStatusCode(getResponse.status_code, 200);

    // Verify session data was persisted
    let body = getResponse.body;
    let bodyText = switch (Text.decodeUtf8(body)) {
      case (?text) text;
      case (null) Runtime.trap("Could not decode response body");
    };
    assert (Text.contains(bodyText, #text("username=testuser")));
    assert (Text.contains(bodyText, #text("role=admin")));
  },
);

// Test 3: Session removal and clearing
await test(
  "should support session data removal and clearing",
  func() : async () {
    let routerConfig : RouterMiddleware.Config = {
      prefix = null;
      identityRequirement = null;
      routes = [
        Router.getQuery(
          "/setup",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            session.set("key1", "value1");
            session.set("key2", "value2");
            session.set("key3", "value3");
            ctx.buildResponse(#ok, #text("Setup complete"));
          },
        ),
        Router.getQuery(
          "/remove",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            session.remove("key2");
            ctx.buildResponse(#ok, #text("Key removed"));
          },
        ),
        Router.getQuery(
          "/check",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            let key1 = switch (session.get("key1")) {
              case (?v) v;
              case (null) "missing";
            };
            let key2 = switch (session.get("key2")) {
              case (?v) v;
              case (null) "missing";
            };
            let key3 = switch (session.get("key3")) {
              case (?v) v;
              case (null) "missing";
            };
            ctx.buildResponse(#ok, #text("key1=" # key1 # ",key2=" # key2 # ",key3=" # key3));
          },
        ),
      ];
    };

    let app = Liminal.App({
      middleware = [
        SessionMiddleware.inMemoryDefault(),
        RouterMiddleware.new(routerConfig),
      ];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
      urlNormalization = urlNormalizationOptions;
    });

    // Setup session data
    let setupResponse = await* app.http_request_update(createRequest(#get, "/setup", [], Blob.fromArray([])));
    assertStatusCode(setupResponse.status_code, 200);
    let ?setCookieHeader = getHeader(setupResponse.headers, "Set-Cookie") else Runtime.trap("Expected Set-Cookie header");
    let ?sessionId = extractSessionId(setCookieHeader, "session") else Runtime.trap("Could not extract session ID");

    // Remove one key
    let removeResponse = await* app.http_request_update(createRequest(#get, "/remove", [("Cookie", "session=" # sessionId)], Blob.fromArray([])));
    assertStatusCode(removeResponse.status_code, 200);

    // Check remaining data
    let checkResponse = await* app.http_request_update(createRequest(#get, "/check", [("Cookie", "session=" # sessionId)], Blob.fromArray([])));
    assertStatusCode(checkResponse.status_code, 200);

    let body = checkResponse.body;
    let bodyText = switch (Text.decodeUtf8(body)) {
      case (?text) text;
      case (null) Runtime.trap("Could not decode response body");
    };
    assert (Text.contains(bodyText, #text("key1=value1")));
    assert (Text.contains(bodyText, #text("key2=missing")));
    assert (Text.contains(bodyText, #text("key3=value3")));
  },
);

// Test 4: Custom session configuration
await test(
  "should work with custom session configuration",
  func() : async () {
    let customStore = SessionMiddleware.buildInMemoryStore();
    let customConfig : SessionMiddleware.Config = {
      cookieName = "custom-session";
      idleTimeout = 60; // 1 minute
      cookieOptions = {
        path = "/api";
        secure = false;
        httpOnly = false;
        sameSite = ?#strict;
        maxAge = ?3600;
      };
      store = customStore;
      idGenerator = SessionMiddleware.generateRandomId;
    };

    let routerConfig : RouterMiddleware.Config = {
      prefix = null;
      identityRequirement = null;
      routes = [
        Router.getQuery(
          "/api/test",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            ctx.buildResponse(#ok, #text("Custom session: " # session.id));
          },
        ),
      ];
    };

    let app = Liminal.App({
      middleware = [
        SessionMiddleware.new(customConfig),
        RouterMiddleware.new(routerConfig),
      ];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
      urlNormalization = urlNormalizationOptions;
    });

    let request = createRequest(
      #get,
      "/api/test",
      [],
      Blob.fromArray([]),
    );

    let response = await* app.http_request_update(request);

    assertStatusCode(response.status_code, 200);

    // Check custom cookie settings
    let setCookieHeader = getHeader(response.headers, "Set-Cookie");
    switch (setCookieHeader) {
      case (?cookie) {
        assert (Text.contains(cookie, #text("custom-session=")));
        assert (Text.contains(cookie, #text("Path=/api")));
        assert (Text.contains(cookie, #text("SameSite=Strict")));
        assert (Text.contains(cookie, #text("Max-Age=3600")));
        assert (not Text.contains(cookie, #text("HttpOnly")));
        assert (not Text.contains(cookie, #text("Secure")));
      };
      case (null) Runtime.trap("Expected Set-Cookie header");
    };
  },
);

// Test 5: Session clearing
await test(
  "should support session clearing",
  func() : async () {
    let routerConfig : RouterMiddleware.Config = {
      prefix = null;
      identityRequirement = null;
      routes = [
        Router.getQuery(
          "/setup",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            session.set("data1", "value1");
            session.set("data2", "value2");
            ctx.buildResponse(#ok, #text("Data set"));
          },
        ),
        Router.getQuery(
          "/clear",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            session.clear();
            ctx.buildResponse(#ok, #text("Session cleared"));
          },
        ),
        Router.getQuery(
          "/check-after-clear",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            let data1 = switch (session.get("data1")) {
              case (?v) v;
              case (null) "missing";
            };
            let data2 = switch (session.get("data2")) {
              case (?v) v;
              case (null) "missing";
            };
            ctx.buildResponse(#ok, #text("data1=" # data1 # ",data2=" # data2));
          },
        ),
      ];
    };

    let app = Liminal.App({
      middleware = [
        SessionMiddleware.inMemoryDefault(),
        RouterMiddleware.new(routerConfig),
      ];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
      urlNormalization = urlNormalizationOptions;
    });

    // Setup session data
    let setupResponse = await* app.http_request_update(createRequest(#get, "/setup", [], Blob.fromArray([])));
    assertStatusCode(setupResponse.status_code, 200);
    let ?setCookieHeader = getHeader(setupResponse.headers, "Set-Cookie") else Runtime.trap("Expected Set-Cookie header");
    let ?sessionId = extractSessionId(setCookieHeader, "session") else Runtime.trap("Could not extract session ID");

    // Clear session
    let clearResponse = await* app.http_request_update(createRequest(#get, "/clear", [("Cookie", "session=" # sessionId)], Blob.fromArray([])));
    assertStatusCode(clearResponse.status_code, 200);

    // Check data after clear - session should be gone, so new session will be created
    let checkResponse = await* app.http_request_update(createRequest(#get, "/check-after-clear", [("Cookie", "session=" # sessionId)], Blob.fromArray([])));
    assertStatusCode(checkResponse.status_code, 200);

    let body = checkResponse.body;
    let bodyText = switch (Text.decodeUtf8(body)) {
      case (?text) text;
      case (null) Runtime.trap("Could not decode response body");
    };
    assert (Text.contains(bodyText, #text("data1=missing")));
    assert (Text.contains(bodyText, #text("data2=missing")));
  },
);

// Test 6: Session behavior without existing session (query requests)
await test(
  "should handle query requests without creating session",
  func() : async () {
    let routerConfig : RouterMiddleware.Config = {
      prefix = null;
      identityRequirement = null;
      routes = [
        Router.getQuery(
          "/no-session",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let session = ctx.httpContext.session;
            let hasSession = switch (session) {
              case (?_) "yes";
              case (null) "no";
            };
            ctx.buildResponse(#ok, #text("Has session: " # hasSession));
          },
        ),
      ];
    };

    let app = Liminal.App({
      middleware = [
        SessionMiddleware.inMemoryDefault(),
        RouterMiddleware.new(routerConfig),
      ];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
      urlNormalization = urlNormalizationOptions;
    });

    let request = createRequest(
      #get,
      "/no-session",
      [],
      Blob.fromArray([]),
    );

    let response = app.http_request(request);

    assertStatusCode(response.status_code, 200);

    // Should not have Set-Cookie header for query requests without existing session
    let setCookieHeader = getHeader(response.headers, "Set-Cookie");
    assert (setCookieHeader == null);

    let body = response.body;
    let bodyText = switch (Text.decodeUtf8(body)) {
      case (?text) text;
      case (null) Runtime.trap("Could not decode response body");
    };
    assert (Text.contains(bodyText, #text("Has session: no")));
  },
);

// Test 7: Session creation on update requests
await test(
  "should create session on update requests",
  func() : async () {
    let routerConfig : RouterMiddleware.Config = {
      prefix = null;
      identityRequirement = null;
      routes = [
        Router.postUpdate(
          "/create-session",
          func<system>(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };
            session.set("created", "true");
            ctx.buildResponse(#created, #text("Session created: " # session.id));
          },
        ),
      ];
    };

    let app = Liminal.App({
      middleware = [
        SessionMiddleware.inMemoryDefault(),
        RouterMiddleware.new(routerConfig),
      ];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
      urlNormalization = urlNormalizationOptions;
    });

    let request = createRequest(
      #post,
      "/create-session",
      [("Content-Type", "application/json")],
      Blob.fromArray([]),
    );

    let response = await* app.http_request_update(request);

    assertStatusCode(response.status_code, 201);

    // Should have Set-Cookie header for update requests
    let setCookieHeader = getHeader(response.headers, "Set-Cookie");
    switch (setCookieHeader) {
      case (?cookie) {
        assert (Text.contains(cookie, #text("session=")));
      };
      case (null) Runtime.trap("Expected Set-Cookie header for update request");
    };
  },
);

// Test 8: Session data overwriting
await test(
  "should support overwriting session data",
  func() : async () {
    let routerConfig : RouterMiddleware.Config = {
      prefix = null;
      identityRequirement = null;
      routes = [
        Router.getQuery(
          "/overwrite-test",
          func(ctx : Liminal.RouteContext) : Liminal.HttpResponse {
            let ?session = ctx.httpContext.session else {
              return ctx.buildResponse(#internalServerError, #text("No session found"));
            };

            // Set initial value
            session.set("counter", "1");

            // Overwrite with new value
            session.set("counter", "2");

            // Set another key and overwrite it
            session.set("name", "first");
            session.set("name", "second");

            let counter = switch (session.get("counter")) {
              case (?v) v;
              case (null) "missing";
            };
            let name = switch (session.get("name")) {
              case (?v) v;
              case (null) "missing";
            };

            ctx.buildResponse(#ok, #text("counter=" # counter # ",name=" # name));
          },
        ),
      ];
    };

    let app = Liminal.App({
      middleware = [
        SessionMiddleware.inMemoryDefault(),
        RouterMiddleware.new(routerConfig),
      ];
      errorSerializer = Liminal.defaultJsonErrorSerializer;
      candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
      logger = Liminal.buildDebugLogger(#warning);
      urlNormalization = urlNormalizationOptions;
    });

    let response = await* app.http_request_update(createRequest(#get, "/overwrite-test", [], Blob.fromArray([])));
    assertStatusCode(response.status_code, 200);

    let body = response.body;
    let bodyText = switch (Text.decodeUtf8(body)) {
      case (?text) text;
      case (null) Runtime.trap("Could not decode response body");
    };
    assert (Text.contains(bodyText, #text("counter=2")));
    assert (Text.contains(bodyText, #text("name=second")));
  },
);
