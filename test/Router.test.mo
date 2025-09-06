import { test } "mo:test";
import Runtime "mo:core@1/Runtime";
import Router "../src/Router";
import Route "../src/Route";
import Nat "mo:core@1/Nat";

// Test for Router.matchPath function with various path matching scenarios
test(
  "Router.matchPath - successful matches",
  func() {
    type TestCase = {
      name : Text;
      expected : [Route.PathSegment];
      actual : [Text];
      expectedParams : [(Text, Text)];
    };

    let testCases : [TestCase] = [
      // Basic static paths
      {
        name = "Simple static path";
        expected = [#text("users")];
        actual = ["users"];
        expectedParams = [];
      },

      // Parameter matching
      {
        name = "Single parameter";
        expected = [#text("users"), #param("id")];
        actual = ["users", "123"];
        expectedParams = [("id", "123")];
      },
      {
        name = "Multiple parameters";
        expected = [#text("users"), #param("id"), #text("posts"), #param("postId")];
        actual = ["users", "123", "posts", "456"];
        expectedParams = [("id", "123"), ("postId", "456")];
      },

      // Single wildcard tests
      {
        name = "Single wildcard at end";
        expected = [#text("files"), #wildcard(#single)];
        actual = ["files", "document.txt"];
        expectedParams = [];
      },
      {
        name = "Single wildcard in middle";
        expected = [#text("files"), #wildcard(#single), #text("versions")];
        actual = ["files", "document.txt", "versions"];
        expectedParams = [];
      },

      // Multi wildcard tests
      {
        name = "Multi wildcard at end";
        expected = [#text("files"), #wildcard(#multi)];
        actual = ["files", "documents", "text", "readme.txt"];
        expectedParams = [];
      },
      {
        name = "Multi wildcard in middle";
        expected = [#text("api"), #wildcard(#multi), #text("info")];
        actual = ["api", "users", "123", "profile", "info"];
        expectedParams = [];
      },
      {
        name = "Multi wildcard matching zero segments";
        expected = [#text("api"), #wildcard(#multi), #text("info")];
        actual = ["api", "info"];
        expectedParams = [];
      },

      // Combined patterns
      {
        name = "Complex path with params and wildcards";
        expected = [#text("api"), #text("v1"), #param("resource"), #wildcard(#multi), #text("details")];
        actual = ["api", "v1", "users", "123", "profile", "settings", "details"];
        expectedParams = [("resource", "users")];
      },
      {
        name = "Path with multiple wildcards";
        expected = [#text("data"), #wildcard(#single), #param("type"), #wildcard(#multi), #text("download")];
        actual = ["data", "customer", "invoice", "2023", "pdf", "download"];
        expectedParams = [("type", "invoice")];
      },

      // Edge cases
      {
        name = "Empty path";
        expected = [];
        actual = [];
        expectedParams = [];
      },
      {
        name = "Only wildcards";
        expected = [#wildcard(#multi)];
        actual = ["any", "path", "here"];
        expectedParams = [];
      },
      {
        name = "Case insensitive matching";
        expected = [#text("API"), #text("Users")];
        actual = ["api", "users"];
        expectedParams = [];
      },
    ];

    for (testCase in testCases.vals()) {
      let result = Router.matchPath(testCase.expected, testCase.actual);

      switch (result) {
        case (null) {
          Runtime.trap("Failed to match in test case: " # testCase.name);
        };
        case (?res) {
          if (res.params.size() != testCase.expectedParams.size()) {
            Runtime.trap(
              "Parameter count mismatch in test case: " # testCase.name #
              "\nExpected: " # debug_show (testCase.expectedParams) #
              "\nActual: " # debug_show (res.params)
            );
          };

          for (i in Nat.range(0, testCase.expectedParams.size())) {
            if (i >= res.params.size()) {
              Runtime.trap("Missing parameter at index " # debug_show (i) # " in test case: " # testCase.name);
            };

            let (expectedName, expectedValue) = testCase.expectedParams[i];
            let (actualName, actualValue) = res.params[i];

            if (expectedName != actualName or expectedValue != actualValue) {
              Runtime.trap(
                "Parameter mismatch at index " # debug_show (i) # " in test case: " # testCase.name #
                "\nExpected: " # debug_show ((expectedName, expectedValue)) #
                "\nActual: " # debug_show ((actualName, actualValue))
              );
            };
          };
        };
      };
    };
  },
);

test(
  "Router.matchPath - failing matches",
  func() {
    type TestCase = {
      name : Text;
      expected : [Route.PathSegment];
      actual : [Text];
    };

    let testCases : [TestCase] = [
      // Basic mismatches
      {
        name = "Mismatched path segments";
        expected = [#text("users")];
        actual = ["posts"];
      },

      // Length mismatches
      {
        name = "Different length paths";
        expected = [#text("api"), #text("users")];
        actual = ["api", "users", "extra"];
      },
      {
        name = "Too short path";
        expected = [#text("api"), #text("users"), #text("details")];
        actual = ["api", "users"];
      },

      // Single wildcard limitations
      {
        name = "Single wildcard should not match multiple segments";
        expected = [#text("files"), #wildcard(#single), #text("versions")];
        actual = ["files", "documents", "text", "versions"];
      },

      // Parameter requirements
      {
        name = "Parameter with missing segment";
        expected = [#text("users"), #param("id")];
        actual = ["users"];
      },
    ];

    for (testCase in testCases.vals()) {
      let result = Router.matchPath(testCase.expected, testCase.actual);

      if (result != null) {
        Runtime.trap(
          "Expected path to NOT match in test case: " # testCase.name #
          "\nExpected path: " # debug_show (testCase.expected) #
          "\nActual path: " # debug_show (testCase.actual) #
          "\nGot parameters: " # debug_show (result)
        );
      };
    };
  },
);
