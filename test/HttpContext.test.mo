import { test } "mo:test";
import HttpContext "../src/HttpContext";
import Runtime "mo:core@1/Runtime";
import Text "mo:core@1/Text";
import Blob "mo:core@1/Blob";
import Liminal "../src/lib";
import Types "../src/Types";

test(
  "HttpContext.getStatusCodeNat - converts status codes to numbers correctly",
  func() : () {
    let testCases = [
      // Success codes
      (#ok : HttpContext.HttpStatusCodeOrCustom, 200, "ok"),
      (#created, 201, "created"),
      (#accepted, 202, "accepted"),
      (#noContent, 204, "noContent"),

      // Redirection codes
      (#movedPermanently, 301, "movedPermanently"),
      (#found, 302, "found"),
      (#seeOther, 303, "seeOther"),
      (#notModified, 304, "notModified"),

      // Client error codes
      (#badRequest, 400, "badRequest"),
      (#unauthorized, 401, "unauthorized"),
      (#forbidden, 403, "forbidden"),
      (#notFound, 404, "notFound"),
      (#methodNotAllowed, 405, "methodNotAllowed"),
      (#conflict, 409, "conflict"),
      (#unprocessableContent, 422, "unprocessableContent"),

      // Server error codes
      (#internalServerError, 500, "internalServerError"),
      (#notImplemented, 501, "notImplemented"),
      (#badGateway, 502, "badGateway"),
      (#serviceUnavailable, 503, "serviceUnavailable"),

      // Custom code
      (#custom(999), 999, "custom 999"),
    ];

    for ((statusCode, expectedNat, description) in testCases.vals()) {
      let actual = HttpContext.getStatusCodeNat(statusCode);
      if (actual != expectedNat) {
        Runtime.trap("getStatusCodeNat failed for " # description # ": expected " # debug_show (expectedNat) # ", got " # debug_show (actual));
      };
    };
  },
);

test(
  "HttpContext.getStatusCodeLabel - converts status code numbers to labels correctly",
  func() : () {
    let testCases = [
      // Success codes (2xx)
      (200, "OK", "200 OK"),
      (201, "Created", "201 Created"),
      (202, "Accepted", "202 Accepted"),
      (204, "No Content", "204 No Content"),

      // Redirection codes (3xx)
      (301, "Moved Permanently", "301 Moved Permanently"),
      (302, "Found", "302 Found"),
      (303, "See Other", "303 See Other"),
      (304, "Not Modified", "304 Not Modified"),

      // Client error codes (4xx)
      (400, "Bad Request", "400 Bad Request"),
      (401, "Unauthorized", "401 Unauthorized"),
      (403, "Forbidden", "403 Forbidden"),
      (404, "Not Found", "404 Not Found"),
      (405, "Method Not Allowed", "405 Method Not Allowed"),
      (409, "Conflict", "409 Conflict"),
      (422, "Unprocessable Entity", "422 Unprocessable Entity"),

      // Server error codes (5xx)
      (500, "Internal Server Error", "500 Internal Server Error"),
      (501, "Not Implemented", "501 Not Implemented"),
      (502, "Bad Gateway", "502 Bad Gateway"),
      (503, "Service Unavailable", "503 Service Unavailable"),

      // Unknown codes should return "Unknown Status Code: X"
      (999, "Unknown Status Code: 999", "999 Unknown Status Code: 999"),
      (123, "Unknown Status Code: 123", "123 Unknown Status Code: 123"),
    ];

    for ((statusCode, expectedLabel, description) in testCases.vals()) {
      let actual = HttpContext.getStatusCodeLabel(statusCode);
      if (actual != expectedLabel) {
        Runtime.trap("getStatusCodeLabel failed for " # description # ": expected '" # expectedLabel # "', got '" # actual # "'");
      };
    };
  },
);

test(
  "HttpContext status code roundtrip - getStatusCodeNat and getStatusCodeLabel",
  func() : () {
    // Test all types of status codes since getStatusCodeLabel now handles all of them
    let statusCodes : [HttpContext.HttpStatusCodeOrCustom] = [
      #ok,
      #created,
      #movedPermanently,
      #found,
      #badRequest,
      #unauthorized,
      #forbidden,
      #notFound,
      #internalServerError,
      #serviceUnavailable,
    ];

    for (statusCode in statusCodes.vals()) {
      let nat = HttpContext.getStatusCodeNat(statusCode);
      let statusLabel = HttpContext.getStatusCodeLabel(nat);

      // The label should not be "Unknown Error" for standard status codes
      if (statusLabel == "Unknown Error") {
        Runtime.trap("Roundtrip failed for " # debug_show (statusCode) # ": got 'Unknown Error' label for standard status code " # debug_show (nat));
      };
    };
  },
);

// Helper function to create a test HttpContext instance
func createTestHttpContext() : HttpContext.HttpContext {
  let testRequest = {
    method = "GET";
    url = "/test";
    headers = [("Accept", "application/json,text/html")];
    body = Blob.fromArray([]);
  };

  let options = {
    errorSerializer = Liminal.defaultJsonErrorSerializer;
    candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
    logger = Liminal.buildDebugLogger(#warning);
  };

  HttpContext.HttpContext(testRequest, null, options);
};

test(
  "HttpContext.buildResponse - comprehensive test for all ResponseKind variants",
  func() : () {
    let httpContext = createTestHttpContext();

    // Define test case type
    type TestCase = {
      name : Text;
      statusCode : HttpContext.HttpStatusCodeOrCustom;
      responseKind : HttpContext.ResponseKind;
      expected : Types.HttpResponse;
    };

    let testCases : [TestCase] = [
      // #empty response
      {
        name = "#empty response";
        statusCode = #ok;
        responseKind = #empty;
        expected = {
          statusCode = 200;
          headers = [];
          body = null;
          streamingStrategy = null;
        };
      },

      // #custom response
      {
        name = "#custom response";
        statusCode = #created;
        responseKind = #custom({
          headers = [("X-Custom-Header", "custom-value"), ("Content-Type", "text/custom")];
          body = "Custom response body";
        });
        expected = {
          statusCode = 201;
          headers = [("X-Custom-Header", "custom-value"), ("Content-Type", "text/custom")];
          body = ?"Custom response body";
          streamingStrategy = null;
        };
      },

      // #text response
      {
        name = "#text response";
        statusCode = #ok;
        responseKind = #text("Hello, world!");
        expected = {
          statusCode = 200;
          headers = [("content-type", "text/plain")];
          body = ?"Hello, world!";
          streamingStrategy = null;
        };
      },

      // #html response
      {
        name = "#html response";
        statusCode = #ok;
        responseKind = #html("<html><body><h1>Hello World</h1></body></html>");
        expected = {
          statusCode = 200;
          headers = [("content-type", "text/html")];
          body = ?"<html><body><h1>Hello World</h1></body></html>";
          streamingStrategy = null;
        };
      },

      // #json response
      {
        name = "#json response";
        statusCode = #ok;
        responseKind = #json(
          #object_([
            ("message", #string("Hello")),
            ("status", #string("success")),
            ("count", #number(#int(42))),
          ])
        );
        expected = {
          statusCode = 200;
          headers = [
            ("content-type", "application/json"),
            ("content-length", "49"),
          ];
          body = ?"{\"message\":\"Hello\",\"status\":\"success\",\"count\":42}";
          streamingStrategy = null;
        };
      },

      // #content response - This will depend on the candidRepresentationNegotiator
      {
        name = "#content response";
        statusCode = #ok;
        responseKind = #content(#Text("Hello from Candid"));
        expected = {
          statusCode = 200;
          headers = [
            ("content-type", "application/json"),
            ("content-length", "19"),
          ];
          body = ?"\"Hello from Candid\"";
          streamingStrategy = null;
        };
      },

      // #error with #none - This will depend on the errorSerializer
      {
        name = "#error with #none";
        statusCode = #badRequest;
        responseKind = #error(#none);
        expected = {
          statusCode = 400;
          headers = [];
          body = null;
          streamingStrategy = null;
        };
      },

      // #error with #message
      {
        name = "#error with #message";
        statusCode = #unprocessableContent;
        responseKind = #error(#message("Invalid request parameters"));
        expected = {
          statusCode = 422;
          headers = [("Content-Type", "application/json"), ("Content-Length", "84")];
          body = ?"{\"status\":422,\"error\":\"Unprocessable Entity\",\"message\":\"Invalid request parameters\"}";
          streamingStrategy = null;
        };
      },

      // #error with #rfc9457
      {
        name = "#error with #rfc9457";
        statusCode = #badRequest;
        responseKind = #error(#rfc9457({ type_ = "https://example.com/problems/validation-error"; title = ?"Validation Error"; detail = ?"The request body contains invalid data"; instance = ?"/users/123"; extensions = [{ name = "invalid_fields"; value = #array([#text("email"), #text("age")]) }] }));
        expected = {
          statusCode = 400;
          headers = [("Content-Type", "application/problem+json"), ("Content-Length", "203")]; // RFC 9457 content type
          body = ?"{\"type\":\"https://example.com/problems/validation-error\",\"status\":400,\"title\":\"Validation Error\",\"detail\":\"The request body contains invalid data\",\"instance\":\"/users/123\",\"invalid_fields\":[\"email\",\"age\"]}";
          streamingStrategy = null;
        };
      },

      // Test different status codes with same response type
      {
        name = "custom status code";
        statusCode = #custom(418);
        responseKind = #text("I'm a teapot");
        expected = {
          statusCode = 418;
          headers = [("content-type", "text/plain")];
          body = ?"I'm a teapot";
          streamingStrategy = null;
        };
      },
    ];

    // Run all test cases
    for (testCase in testCases.vals()) {
      let response = httpContext.buildResponse(testCase.statusCode, testCase.responseKind);

      // Check status code
      if (response != testCase.expected) {
        Runtime.trap(testCase.name # ":\nExpected: " # debug_show ({ body = testCase.expected.body; statusCode = testCase.expected.statusCode; headers = testCase.expected.headers }) # "\nActual:   " # debug_show ({ body = response.body; statusCode = response.statusCode; headers = response.headers }));
      };

    };
  },
);
