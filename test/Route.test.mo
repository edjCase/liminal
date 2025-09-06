import { test } "mo:test";
import Runtime "mo:core@1/Runtime";
import Nat "mo:core@1/Nat";
import Route "../src/Route";
// Test for parsePathSegments function
test(
  "Path.parsePathSegments - successful parsing",
  func() {
    type TestCase = {
      name : Text;
      input : Text;
      expected : [Route.PathSegment];
    };

    let testCases : [TestCase] = [
      // Static paths
      {
        name = "Simple static path";
        input = "/users";
        expected = [#text("users")];
      },
      {
        name = "Multiple static segments";
        input = "/api/v1/resources";
        expected = [#text("api"), #text("v1"), #text("resources")];
      },

      // Parameter paths
      {
        name = "Path with parameter";
        input = "/users/{id}";
        expected = [#text("users"), #param("id")];
      },
      {
        name = "Path with multiple parameters";
        input = "/users/{userId}/posts/{postId}";
        expected = [#text("users"), #param("userId"), #text("posts"), #param("postId")];
      },

      // Single wildcard
      {
        name = "Single wildcard at end";
        input = "/files/*";
        expected = [#text("files"), #wildcard(#single)];
      },
      {
        name = "Single wildcard in middle";
        input = "/files/*/versions";
        expected = [#text("files"), #wildcard(#single), #text("versions")];
      },

      // Multi wildcard
      {
        name = "Multi wildcard at end";
        input = "/api/**";
        expected = [#text("api"), #wildcard(#multi)];
      },
      {
        name = "Multi wildcard in middle";
        input = "/api/**/info";
        expected = [#text("api"), #wildcard(#multi), #text("info")];
      },

      // Combined patterns
      {
        name = "Complex path pattern";
        input = "/api/v1/{resource}/**/details";
        expected = [#text("api"), #text("v1"), #param("resource"), #wildcard(#multi), #text("details")];
      },
      {
        name = "Path with all segment types";
        input = "/data/*/{type}/**/download";
        expected = [#text("data"), #wildcard(#single), #param("type"), #wildcard(#multi), #text("download")];
      },

      // Edge cases
      {
        name = "Root path";
        input = "/";
        expected = [];
      },
      {
        name = "Empty path";
        input = "";
        expected = [];
      },
      {
        name = "Path with trailing slash";
        input = "/users/";
        expected = [#text("users")];
      },
    ];

    for (testCase in testCases.vals()) {
      let result = Route.parsePathSegments(testCase.input);

      switch (result) {
        case (#err(errorMsg)) {
          Runtime.trap("Failed to parse path in test case: " # testCase.name # " with error: " # errorMsg);
        };
        case (#ok(segments)) {
          if (segments.size() != testCase.expected.size()) {
            Runtime.trap(
              "Segment count mismatch in test case: " # testCase.name #
              "\nExpected: " # debug_show (testCase.expected) #
              "\nActual: " # debug_show (segments) #
              "\nInput: " # testCase.input
            );
          };

          for (i in Nat.range(0, segments.size())) {
            if (segments[i] != testCase.expected[i]) {
              Runtime.trap(
                "Segment mismatch at index " # debug_show (i) # " in test case: " # testCase.name #
                "\nExpected: " # debug_show (testCase.expected[i]) #
                "\nActual: " # debug_show (segments[i]) #
                "\nInput: " # testCase.input
              );
            };
          };
        };
      };
    };
  },
);

test(
  "Path.parsePathSegments - parsing failures",
  func() {
    type TestCase = {
      name : Text;
      input : Text;
    };

    let testCases : [TestCase] = [
      // Malformed parameters
      {
        name = "Unclosed parameter";
        input = "/users/{id";
      },
      {
        name = "Empty parameter";
        input = "/users/{}";
      },

      // Invalid wildcard formats
      {
        name = "Invalid wildcard format";
        input = "/files/***";
      },
      // Other invalid patterns
      {
        name = "Consecutive parameters";
        input = "/users/{first}{last}";
      },
    ];

    for (testCase in testCases.vals()) {
      let result = Route.parsePathSegments(testCase.input);

      switch (result) {
        case (#ok(segments)) {
          Runtime.trap(
            "Expected parsing to fail in test case: " # testCase.name #
            "\nInput: " # testCase.input #
            "\nGot segments: " # debug_show (segments)
          );
        };
        case (#err(_)) {
          // Success - we expected an error
        };
      };
    };
  },
);
