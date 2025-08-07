import { test; suite } "mo:test";
import Text "mo:core/Text";
import ContentNegotiation "../src/ContentNegotiation";
import Array "mo:core/Array";
import Runtime "mo:core/Runtime";
import MimeType "../src/MimeType";

suite(
  "ContentNegotiation Tests",
  func() {

    // === TESTS FOR parseEncodingTypes ===

    test(
      "parseEncodingTypes - single encoding",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("gzip");

        // Should have one requested encoding
        assert (result.requestedEncodings.size() == 1);
        assert (result.disallowedEncodings.size() == 0);

        // Should be gzip
        assert (result.requestedEncodings[0] == #gzip);
      },
    );

    test(
      "parseEncodingTypes - multiple encodings",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("gzip, deflate");

        // Should have two requested encodings
        assert (result.requestedEncodings.size() == 2);

        // Order should be preserved (gzip first, then deflate)
        assert (result.requestedEncodings[0] == #gzip);
        assert (result.requestedEncodings[1] == #deflate);
      },
    );

    test(
      "parseEncodingTypes - with quality values",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("deflate;q=0.5, gzip;q=0.8");

        // Should have encodings ordered by quality (highest first)
        assert (result.requestedEncodings.size() == 2);
        assert (result.requestedEncodings[0] == #gzip);
        assert (result.requestedEncodings[1] == #deflate);
      },
    );

    test(
      "parseEncodingTypes - with wildcard",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("gzip, *");

        // Should have wildcard as second encoding
        assert (result.requestedEncodings.size() == 2);
        assert (result.requestedEncodings[0] == #gzip);
        assert (result.requestedEncodings[1] == #wildcard);
      },
    );

    test(
      "parseEncodingTypes - with identity",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("identity, gzip");

        // Should recognize identity encoding
        assert (result.requestedEncodings.size() == 2);
        assert (result.requestedEncodings[0] == #identity);
        assert (result.requestedEncodings[1] == #gzip);
      },
    );

    test(
      "parseEncodingTypes - with disallowed encodings (q=0)",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("gzip;q=0, deflate, br;q=0");

        // Should separate allowed and disallowed encodings
        assert (result.requestedEncodings.size() == 1);
        assert (result.disallowedEncodings.size() == 2);

        // Check allowed encoding
        assert (result.requestedEncodings[0] == #deflate);

        // Check disallowed encodings
        assert (result.disallowedEncodings[0] == #gzip);
        assert (result.disallowedEncodings[1] == #br);
      },
    );

    test(
      "parseEncodingTypes - mixed case values",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("GzIp, DeFLate");

        // Should handle case insensitivity
        assert (result.requestedEncodings.size() == 2);
        assert (result.requestedEncodings[0] == #gzip);
        assert (result.requestedEncodings[1] == #deflate);
      },
    );

    test(
      "parseEncodingTypes - whitespace handling",
      func() {
        let result = ContentNegotiation.parseEncodingTypes(" gzip , deflate ; q=0.8 ");

        // Should handle whitespace properly
        assert (result.requestedEncodings.size() == 2);
        assert (result.requestedEncodings[0] == #gzip);
        assert (result.requestedEncodings[1] == #deflate);
      },
    );

    test(
      "parseEncodingTypes - invalid/unrecognized encodings",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("gzip, unknown-encoding, deflate");

        // Should ignore unrecognized encoding
        assert (result.requestedEncodings.size() == 2);
        assert (result.requestedEncodings[0] == #gzip);
        assert (result.requestedEncodings[1] == #deflate);
      },
    );

    test(
      "parseEncodingTypes - boundary q-values",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("gzip;q=0.001, deflate;q=0.999");

        // Should order by q-value
        assert (result.requestedEncodings.size() == 2);
        assert (result.requestedEncodings[0] == #deflate);
        assert (result.requestedEncodings[1] == #gzip);
      },
    );

    test(
      "parseEncodingTypes - complex header",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("gzip;q=1.0, identity; q=0.5, *;q=0, deflate");

        // Should parse complex header correctly
        assert (result.requestedEncodings.size() == 3);
        assert (result.disallowedEncodings.size() == 1);

        // Check highest q-values first
        assert (result.requestedEncodings[0] == #gzip);
        assert (result.requestedEncodings[1] == #deflate);
        assert (result.requestedEncodings[2] == #identity);

        // Check disallowed
        assert (result.disallowedEncodings[0] == #wildcard);
      },
    );

    test(
      "parseEncodingTypes - empty string",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("");

        // Should handle empty string
        assert (result.requestedEncodings.size() == 0);
        assert (result.disallowedEncodings.size() == 0);
      },
    );

    test(
      "parseEncodingTypes - malformed values",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("gzip;q=invalid, deflate");

        // Should handle malformed q-value and continue
        assert (result.requestedEncodings.size() > 0);

        // deflate should be included
        var hasDeflate = false;
        for (encoding in result.requestedEncodings.vals()) {
          if (encoding == #deflate) {
            hasDeflate := true;
          };
        };
        assert (hasDeflate);
      },
    );

    test(
      "parseEncodingTypes - all supported encodings",
      func() {
        let result = ContentNegotiation.parseEncodingTypes("gzip, deflate, br, compress, zstd, identity, *");

        // Should parse all supported encodings
        assert (result.requestedEncodings.size() == 7);

        // Verify all encodings are included
        var hasGzip = false;
        var hasDeflate = false;
        var hasBr = false;
        var hasCompress = false;
        var hasZstd = false;
        var hasIdentity = false;
        var hasWildcard = false;

        for (encoding in result.requestedEncodings.vals()) {
          switch (encoding) {
            case (#gzip) hasGzip := true;
            case (#deflate) hasDeflate := true;
            case (#br) hasBr := true;
            case (#compress) hasCompress := true;
            case (#zstd) hasZstd := true;
            case (#identity) hasIdentity := true;
            case (#wildcard) hasWildcard := true;
          };
        };

        assert (hasGzip);
        assert (hasDeflate);
        assert (hasBr);
        assert (hasCompress);
        assert (hasZstd);
        assert (hasIdentity);
        assert (hasWildcard);
      },
    );

    // === TESTS FOR parseContentTypes ===

    test(
      "parseContentTypes - single content type",
      func() {
        let result = ContentNegotiation.parseContentTypes("text/html");

        // Should have one requested content type
        assert (result.requestedTypes.size() == 1);
        assert (result.disallowedTypes.size() == 0);

        // Check content type
        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#text_html(textHtml)) {
            assert (textHtml.level == null);
            assert (textHtml.version == null);
            assert (textHtml.charset == null);
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - multiple content types",
      func() {
        let result = ContentNegotiation.parseContentTypes("text/html, application/json");

        // Should have two requested content types
        assert (result.requestedTypes.size() == 2);

        // Check first content type
        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#text_html(textHtml)) {
            assert (textHtml.level == null);
            assert (textHtml.version == null);
            assert (textHtml.charset == null);
          };
          case (_) assert (false);
        };

        // Check second content type
        switch (MimeType.fromRaw(result.requestedTypes[1])) {
          case (#application_json(appJson)) {
            assert (appJson.charset == null);
            assert (appJson.schema == null);
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - with quality values",
      func() {
        let result = ContentNegotiation.parseContentTypes("text/html;q=0.5, application/json;q=0.8");

        // Should order by quality value
        assert (result.requestedTypes.size() == 2);

        // Check first (highest quality) content type
        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#application_json(appJson)) {
            assert (appJson.charset == null);
            assert (appJson.schema == null);
          };
          case (_) assert (false);
        };

        // Check second content type
        switch (MimeType.fromRaw(result.requestedTypes[1])) {
          case (#text_html(textHtml)) {
            assert (textHtml.level == null);
            assert (textHtml.version == null);
            assert (textHtml.charset == null);
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - with parameters",
      func() {
        let result = ContentNegotiation.parseContentTypes("text/html;charset=utf-8");

        // Should parse parameter
        assert (result.requestedTypes.size() == 1);

        // Check content type and parameters
        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#text_html(textHtml)) {
            assert (textHtml.level == null);
            assert (textHtml.version == null);
            assert (textHtml.charset == ?("utf-8"));
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - with wildcards",
      func() {
        let result = ContentNegotiation.parseContentTypes("text/*, */json, */*");

        // Should parse wildcards in type and subType
        assert (result.requestedTypes.size() == 3);

        // Check first content type (text/*)
        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#other(raw)) {
            assert (raw.type_ == "text");
            assert (raw.subType == "*");
          };
          case (_) assert (false);
        };

        // Check second content type (*/json)
        switch (MimeType.fromRaw(result.requestedTypes[1])) {
          case (#other(raw)) {
            assert (raw.type_ == "*");
            assert (raw.subType == "json");
          };
          case (_) assert (false);
        };

        // Check third content type (*/*)
        switch (MimeType.fromRaw(result.requestedTypes[2])) {
          case (#other(raw)) {
            assert (raw.type_ == "*");
            assert (raw.subType == "*");
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - with disallowed content types (q=0)",
      func() {
        let result = ContentNegotiation.parseContentTypes("text/html;q=0, application/json, text/plain;q=0");

        // Should separate allowed and disallowed content types
        assert (result.requestedTypes.size() == 1);
        assert (result.disallowedTypes.size() == 2);

        // Check allowed content type
        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#application_json(appJson)) {
            assert (appJson.charset == null);
            assert (appJson.schema == null);
          };
          case (_) assert (false);
        };

        // Check disallowed content types
        switch (MimeType.fromRaw(result.disallowedTypes[0])) {
          case (#text_html(textHtml)) {
            assert (textHtml.level == null);
            assert (textHtml.version == null);
            assert (textHtml.charset == null);
          };
          case (_) assert (false);
        };

        switch (MimeType.fromRaw(result.disallowedTypes[1])) {
          case (#text_plain(textPlain)) {
            assert (textPlain.charset == null);
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - mixed case values",
      func() {
        let result = ContentNegotiation.parseContentTypes("TeXt/HtMl, APPLICATION/json");

        // Should handle case sensitivity appropriately
        // (Note: HTTP spec says media types are case-insensitive, but we preserve original case)
        assert (result.requestedTypes.size() == 2);

        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#text_html(textHtml)) {
            assert (textHtml.level == null);
            assert (textHtml.version == null);
            assert (textHtml.charset == null);
          };
          case (other) Runtime.trap("Unexpected content type: " # MimeType.toText(other, false));
        };

        switch (MimeType.fromRaw(result.requestedTypes[1])) {
          case (#application_json(appJson)) {
            assert (appJson.charset == null);
            assert (appJson.schema == null);
          };
          case (other) Runtime.trap("Unexpected content type: " # MimeType.toText(other, false));
        };
      },
    );

    test(
      "parseContentTypes - whitespace handling",
      func() {
        let result = ContentNegotiation.parseContentTypes(" text/html , application/json ; q=0.8 ");

        // Should handle whitespace properly
        assert (result.requestedTypes.size() == 2);

        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#text_html(textHtml)) {
            assert (textHtml.level == null);
            assert (textHtml.version == null);
            assert (textHtml.charset == null);
          };
          case (_) assert (false);
        };

        switch (MimeType.fromRaw(result.requestedTypes[1])) {
          case (#application_json(appJson)) {
            assert (appJson.charset == null);
            assert (appJson.schema == null);
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - multiple parameters",
      func() {
        let result = ContentNegotiation.parseContentTypes("text/html;charset=utf-8;version=1.0");

        // Should parse multiple parameters
        assert (result.requestedTypes.size() == 1);

        // Check content type and multiple parameters
        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#text_html(textHtml)) {
            assert (textHtml.charset == ?("utf-8"));
            assert (textHtml.version == ?("1.0"));
            assert (textHtml.level == null);
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - with quality and other parameters",
      func() {
        let result = ContentNegotiation.parseContentTypes("text/html;charset=utf-8;q=0.8");

        // Should separate q-value from other parameters
        assert (result.requestedTypes.size() == 1);

        // Check content type
        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#text_html(textHtml)) {
            assert (textHtml.charset == ?("utf-8"));
            assert (textHtml.level == null);
            assert (textHtml.version == null);
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - invalid/malformed values",
      func() {
        let result = ContentNegotiation.parseContentTypes("text/html, invalid-content-type, application/json");

        // Should skip invalid content type
        assert (result.requestedTypes.size() == 2);

        let types = Array.map<MimeType.RawMimeType, Text>(
          result.requestedTypes,
          func(mime : MimeType.RawMimeType) : Text {
            MimeType.toTextRaw(mime, false);
          },
        );

        assert (types[0] == "text/html");
        assert (types[1] == "application/json");
      },
    );

    test(
      "parseContentTypes - complex accept header",
      func() {
        let header = "text/html;q=0.8, application/xml;q=0.9, application/json, */*;q=0.1";
        let result = ContentNegotiation.parseContentTypes(header);

        // Should parse complex header correctly
        assert (result.requestedTypes.size() == 4);

        // Check ordering by q-value (highest first)
        switch (MimeType.fromRaw(result.requestedTypes[0])) {
          case (#application_json(appJson)) {
            assert (appJson.charset == null);
            assert (appJson.schema == null);
          };
          case (_) assert (false);
        };

        switch (MimeType.fromRaw(result.requestedTypes[1])) {
          case (#application_xml(appXml)) {
            assert (appXml.charset == null);
            assert (appXml.schema == null);
          };
          case (_) assert (false);
        };

        switch (MimeType.fromRaw(result.requestedTypes[2])) {
          case (#text_html(textHtml)) {
            assert (textHtml.level == null);
            assert (textHtml.version == null);
            assert (textHtml.charset == null);
          };
          case (_) assert (false);
        };

        switch (MimeType.fromRaw(result.requestedTypes[3])) {
          case (#other(raw)) {
            assert (raw.type_ == "*");
            assert (raw.subType == "*");
          };
          case (_) assert (false);
        };
      },
    );

    test(
      "parseContentTypes - empty string",
      func() {
        let result = ContentNegotiation.parseContentTypes("");

        // Should handle empty string
        assert (result.requestedTypes.size() == 0);
        assert (result.disallowedTypes.size() == 0);
      },
    );
  },
);
