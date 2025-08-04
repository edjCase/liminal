import { test } "mo:test";
import HttpMethod "../src/HttpMethod";
import Runtime "mo:new-base/Runtime";

test(
  "HttpMethod.toText - converts all HTTP methods to correct text",
  func() : () {
    let testCases = [
      (#get, "GET"),
      (#post, "POST"),
      (#put, "PUT"),
      (#patch, "PATCH"),
      (#delete, "DELETE"),
      (#head, "HEAD"),
      (#options, "OPTIONS"),
    ];

    for ((method, expected) in testCases.vals()) {
      let actual = HttpMethod.toText(method);
      if (actual != expected) {
        Runtime.trap("toText failed for " # debug_show (method) # ": expected '" # expected # "', got '" # actual # "'");
      };
    };
  },
);

test(
  "HttpMethod.fromText - parses valid HTTP method strings (case insensitive)",
  func() : () {
    let validCases = [
      // (input, expected, description)
      ("get", ?#get, "lowercase get"),
      ("post", ?#post, "lowercase post"),
      ("put", ?#put, "lowercase put"),
      ("patch", ?#patch, "lowercase patch"),
      ("delete", ?#delete, "lowercase delete"),
      ("head", ?#head, "lowercase head"),
      ("options", ?#options, "lowercase options"),
      ("GET", ?#get, "uppercase GET"),
      ("POST", ?#post, "uppercase POST"),
      ("PUT", ?#put, "uppercase PUT"),
      ("PATCH", ?#patch, "uppercase PATCH"),
      ("DELETE", ?#delete, "uppercase DELETE"),
      ("HEAD", ?#head, "uppercase HEAD"),
      ("OPTIONS", ?#options, "uppercase OPTIONS"),
      ("Get", ?#get, "mixed case Get"),
      ("PoSt", ?#post, "mixed case PoSt"),
      ("PuT", ?#put, "mixed case PuT"),
    ];

    for ((input, expected, description) in validCases.vals()) {
      let actual = HttpMethod.fromText(input);
      if (actual != expected) {
        Runtime.trap("fromText failed for " # description # " ('" # input # "'): expected " # debug_show (expected) # ", got " # debug_show (actual));
      };
    };
  },
);

test(
  "HttpMethod.fromText - returns null for invalid methods",
  func() : () {
    let invalidCases = [
      ("INVALID", "invalid method name"),
      ("", "empty string"),
      ("connect", "unsupported connect method"),
      ("trace", "unsupported trace method"),
      ("123", "numeric string"),
      ("get ", "method with trailing space"),
      (" get", "method with leading space"),
      ("get post", "multiple methods"),
    ];

    for ((input, description) in invalidCases.vals()) {
      let actual = HttpMethod.fromText(input);
      if (actual != null) {
        Runtime.trap("fromText should return null for " # description # " ('" # input # "'): got " # debug_show (actual));
      };
    };
  },
);

test(
  "HttpMethod roundtrip conversion - toText and fromText",
  func() : () {
    let methods : [HttpMethod.HttpMethod] = [
      #get,
      #post,
      #put,
      #patch,
      #delete,
      #head,
      #options,
    ];

    for (method in methods.vals()) {
      let text = HttpMethod.toText(method);
      let convertedBack = HttpMethod.fromText(text);
      if (convertedBack != ?method) {
        Runtime.trap("Roundtrip failed for " # debug_show (method) # ": toText gave '" # text # "', fromText gave " # debug_show (convertedBack));
      };
    };
  },
);
