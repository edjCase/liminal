import { test } "mo:test";
import MimeType "../src/MimeType";
import Runtime "mo:core@1/Runtime";

test(
  "MimeType.toRaw - converts MimeType to RawMimeType correctly",
  func() : () {
    // Test basic conversion for different mime types
    let testCases = [
      (
        #text_html({
          charset = ?"utf-8";
          level = ?"1";
          version = null;
        }),
        "text",
        "html",
        2, // expected parameter count
        "text/html with charset and level",
      ),
      (
        #application_json({
          charset = ?"utf-8";
          schema = null;
        }),
        "application",
        "json",
        1, // expected parameter count
        "application/json with charset",
      ),
      (
        #text_plain({
          charset = ?"iso-8859-1";
          format = null;
        }),
        "text",
        "plain",
        1, // expected parameter count
        "text/plain with charset",
      ),
    ];

    for ((mimeType, expectedType, expectedSubType, expectedParamCount, description) in testCases.vals()) {
      let raw = MimeType.toRaw(mimeType);
      if (raw.type_ != expectedType) {
        Runtime.trap("toRaw type failed for " # description # ": expected '" # expectedType # "', got '" # raw.type_ # "'");
      };
      if (raw.subType != expectedSubType) {
        Runtime.trap("toRaw subType failed for " # description # ": expected '" # expectedSubType # "', got '" # raw.subType # "'");
      };
      if (raw.parameters.size() != expectedParamCount) {
        Runtime.trap("toRaw parameter count failed for " # description # ": expected " # debug_show (expectedParamCount) # ", got " # debug_show (raw.parameters.size()));
      };
    };
  },
);

test(
  "MimeType.toTextRaw - converts RawMimeType to text correctly",
  func() : () {
    let testCases = [
      (
        {
          type_ = "application";
          subType = "json";
          parameters = [];
        } : MimeType.RawMimeType,
        false,
        "application/json",
        "simple application/json without parameters",
      ),
      (
        {
          type_ = "application";
          subType = "json";
          parameters = [("charset", "utf-8")];
        } : MimeType.RawMimeType,
        true,
        "application/json; charset=utf-8",
        "application/json with parameters",
      ),
      (
        {
          type_ = "text";
          subType = "html";
          parameters = [("charset", "utf-8"), ("level", "1")];
        } : MimeType.RawMimeType,
        true,
        "text/html; charset=utf-8; level=1",
        "text/html with multiple parameters",
      ),
    ];

    for ((raw, includeParameters, expected, description) in testCases.vals()) {
      let actual = MimeType.toTextRaw(raw, includeParameters);
      if (actual != expected) {
        Runtime.trap("toTextRaw failed for " # description # ": expected '" # expected # "', got '" # actual # "'");
      };
    };
  },
);

test(
  "MimeType.fromText - parses text to MimeType correctly",
  func() : () {
    let validCases = [
      ("application/json", "application/json"),
      ("text/html", "text/html"),
      ("text/plain", "text/plain"),
      ("image/png", "image/png"),
      ("application/xml", "application/xml"),
    ];

    for ((input, description) in validCases.vals()) {
      switch (MimeType.fromText(input)) {
        case (?(mimeType, quality)) {
          if (quality != 1000) {
            Runtime.trap("fromText quality failed for " # description # ": expected 1000, got " # debug_show (quality));
          };
          // Successfully parsed, verify it's a valid mime type (not null)
        };
        case (null) {
          Runtime.trap("fromText failed to parse valid " # description);
        };
      };
    };

    let invalidCases = [
      ("invalid", "invalid format"),
      ("", "empty string"),
      ("text", "missing subtype"),
      ("text/", "empty subtype"),
      ("/html", "missing type"),
    ];

    for ((input, description) in invalidCases.vals()) {
      switch (MimeType.fromText(input)) {
        case (null) {
          // Expected null for invalid input
        };
        case (?result) {
          Runtime.trap("fromText should return null for " # description # " ('" # input # "'), got " # debug_show (result));
        };
      };
    };
  },
);

test(
  "MimeType.fromTextRaw - parses text to RawMimeType correctly",
  func() : () {
    let testCases = [
      (
        "application/json",
        "application",
        "json",
        0,
        1000,
        "simple application/json",
      ),
      (
        "text/html; charset=utf-8",
        "text",
        "html",
        1,
        1000,
        "text/html with charset parameter",
      ),
    ];

    for ((input, expectedType, expectedSubType, expectedParamCount, expectedQuality, description) in testCases.vals()) {
      switch (MimeType.fromTextRaw(input)) {
        case (?(raw, quality)) {
          if (raw.type_ != expectedType) {
            Runtime.trap("fromTextRaw type failed for " # description # ": expected '" # expectedType # "', got '" # raw.type_ # "'");
          };
          if (raw.subType != expectedSubType) {
            Runtime.trap("fromTextRaw subType failed for " # description # ": expected '" # expectedSubType # "', got '" # raw.subType # "'");
          };
          if (raw.parameters.size() != expectedParamCount) {
            Runtime.trap("fromTextRaw parameter count failed for " # description # ": expected " # debug_show (expectedParamCount) # ", got " # debug_show (raw.parameters.size()));
          };
          if (quality != expectedQuality) {
            Runtime.trap("fromTextRaw quality failed for " # description # ": expected " # debug_show (expectedQuality) # ", got " # debug_show (quality));
          };
        };
        case (null) {
          Runtime.trap("fromTextRaw failed to parse valid " # description # " ('" # input # "')");
        };
      };
    };
  },
);
