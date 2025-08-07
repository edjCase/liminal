import { test } "mo:test";
import QualityFactor "../src/QualityFactor";
import Runtime "mo:core/Runtime";

test(
  "QualityFactor.fromText - all test cases",
  func() : () {
    type TestCase = {
      input : Text;
      expected : ?Nat;
      description : Text;
    };

    let testCases : [TestCase] = [
      // Valid quality values
      { input = "1"; expected = ?1000; description = "integer 1" },
      { input = "1.0"; expected = ?1000; description = "1.0" },
      { input = "1.00"; expected = ?1000; description = "1.00" },
      { input = "1.000"; expected = ?1000; description = "1.000" },
      { input = "0"; expected = ?0; description = "integer 0" },
      { input = "0.0"; expected = ?0; description = "0.0" },
      { input = "0.00"; expected = ?0; description = "0.00" },
      { input = "0.000"; expected = ?0; description = "0.000" },
      { input = "0.5"; expected = ?500; description = "0.5" },
      { input = "0.8"; expected = ?800; description = "0.8" },
      { input = "0.75"; expected = ?750; description = "0.75" },
      { input = "0.123"; expected = ?123; description = "0.123" },
      { input = "0.001"; expected = ?1; description = "0.001" },

      // Whitespace handling
      {
        input = " 0.5 ";
        expected = ?500;
        description = "spaces around 0.5";
      },
      {
        input = "  1  ";
        expected = ?1000;
        description = "spaces around 1";
      },

      // Precision handling
      { input = "0.1"; expected = ?100; description = "1 decimal place" },
      {
        input = "0.12";
        expected = ?120;
        description = "2 decimal places";
      },
      {
        input = "0.1234";
        expected = ?123;
        description = "4 decimal places (truncated)";
      },
      {
        input = "0.12345";
        expected = ?123;
        description = "5 decimal places (truncated)";
      },
      { input = "0.999"; expected = ?999; description = "close to 1" },
      {
        input = "0.999999";
        expected = ?999;
        description = "truncated to 3 decimal places";
      },

      // Edge cases that should be valid
      { input = "0."; expected = ?0; description = "0. should be valid" },
      {
        input = ".5";
        expected = ?500;
        description = ".5 should be treated as 0.5";
      },

      // Invalid inputs that should return null
      { input = ""; expected = null; description = "empty string" },
      { input = "   "; expected = null; description = "whitespace only" },
      { input = "2"; expected = null; description = "greater than 1" },
      {
        input = "1.1";
        expected = null;
        description = "1.1 greater than 1";
      },
      {
        input = "10";
        expected = null;
        description = "much greater than 1";
      },
      { input = "-1"; expected = null; description = "negative value" },
      {
        input = "-0.5";
        expected = null;
        description = "negative decimal";
      },
      { input = "abc"; expected = null; description = "invalid text" },
      {
        input = "0.5.0";
        expected = null;
        description = "multiple decimal points";
      },
      {
        input = "1.0.0";
        expected = null;
        description = "multiple decimal points";
      },
      { input = "0.5a"; expected = null; description = "invalid suffix" },
      { input = "a0.5"; expected = null; description = "invalid prefix" },
      {
        input = "\t0.8\t";
        expected = null;
        description = "tab characters";
      },
    ];

    for (testCase in testCases.vals()) {
      let actual = QualityFactor.fromText(testCase.input);
      if (actual != testCase.expected) {
        Runtime.trap("Test failed for '" # testCase.description # "' (input: '" # testCase.input # "'). Expected: " # debug_show (testCase.expected) # ", Actual: " # debug_show (actual));
      };
    };
  },
);
