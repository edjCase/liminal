import { test } "mo:test";
import MimeType "../src/MimeType";

test(
    "MimeType.toRaw - converts MimeType to RawMimeType correctly",
    func() : () {
        // Test text/html conversion
        let htmlMimeType = #text_html({
            charset = ?"utf-8";
            level = ?"1";
            version = null;
        });
        let htmlRaw = MimeType.toRaw(htmlMimeType);
        assert htmlRaw.type_ == "text";
        assert htmlRaw.subType == "html";
        assert htmlRaw.parameters.size() == 2; // charset and level

        // Test application/json conversion
        let jsonMimeType = #application_json({
            charset = ?"utf-8";
            schema = null;
        });
        let jsonRaw = MimeType.toRaw(jsonMimeType);
        assert jsonRaw.type_ == "application";
        assert jsonRaw.subType == "json";
        assert jsonRaw.parameters.size() == 1; // charset only
    },
);

test(
    "MimeType.fromRaw - converts RawMimeType to MimeType correctly",
    func() : () {
        // Test text/html conversion
        let htmlRaw : MimeType.RawMimeType = {
            type_ = "text";
            subType = "html";
            parameters = [("charset", "utf-8"), ("level", "1")];
        };
        let htmlMimeType = MimeType.fromRaw(htmlRaw);
        switch (htmlMimeType) {
            case (#text_html(params)) {
                assert params.charset == ?"utf-8";
                assert params.level == ?"1";
                assert params.version == null;
            };
            case (_) assert false; // Should be text_html
        };

        // Test unknown type becomes #other
        let unknownRaw : MimeType.RawMimeType = {
            type_ = "unknown";
            subType = "test";
            parameters = [];
        };
        let unknownMimeType = MimeType.fromRaw(unknownRaw);
        switch (unknownMimeType) {
            case (#other(raw)) {
                assert raw.type_ == "unknown";
                assert raw.subType == "test";
            };
            case (_) assert false; // Should be #other
        };
    },
);

test(
    "MimeType.toText - converts MimeType to text string correctly",
    func() : () {
        // Test without parameters
        let jsonMimeType = #application_json({
            charset = null;
            schema = null;
        });
        let jsonText = MimeType.toText(jsonMimeType, false);
        assert jsonText == "application/json";

        // Test with parameters
        let htmlMimeType = #text_html({
            charset = ?"utf-8";
            level = null;
            version = null;
        });
        let htmlTextWithParams = MimeType.toText(htmlMimeType, true);
        assert htmlTextWithParams == "text/html; charset=utf-8";
    },
);

test(
    "MimeType.toTextRaw - converts RawMimeType to text string correctly",
    func() : () {
        let raw : MimeType.RawMimeType = {
            type_ = "application";
            subType = "json";
            parameters = [("charset", "utf-8")];
        };

        // Without parameters
        let textWithoutParams = MimeType.toTextRaw(raw, false);
        assert textWithoutParams == "application/json";

        // With parameters
        let textWithParams = MimeType.toTextRaw(raw, true);
        assert textWithParams == "application/json; charset=utf-8";
    },
);

test(
    "MimeType.fromText - parses text to MimeType correctly",
    func() : () {
        // Test simple mime type
        switch (MimeType.fromText("application/json")) {
            case (?(mimeType, quality)) {
                switch (mimeType) {
                    case (#application_json(_)) assert true;
                    case (_) assert false;
                };
                assert quality == 1000; // Quality factor is Nat 0-1000
            };
            case (null) assert false;
        };

        // Test invalid mime type
        switch (MimeType.fromText("invalid")) {
            case (null) assert true; // Should return null for invalid
            case (_) assert false;
        };
    },
);

test(
    "MimeType.fromTextRaw - parses text to RawMimeType correctly",
    func() : () {
        // Test simple mime type
        switch (MimeType.fromTextRaw("application/json")) {
            case (?(raw, quality)) {
                assert raw.type_ == "application";
                assert raw.subType == "json";
                assert raw.parameters.size() == 0;
                assert quality == 1000; // Quality factor is Nat 0-1000
            };
            case (null) assert false;
        };

        // Test invalid mime type
        switch (MimeType.fromTextRaw("invalid")) {
            case (null) assert true; // Should return null for invalid
            case (_) assert false;
        };
    },
);

test(
    "MimeType roundtrip conversion - toRaw and fromRaw",
    func() : () {
        let originalMimeType = #text_html({
            charset = ?"utf-8";
            level = ?"1";
            version = ?"5";
        });

        let raw = MimeType.toRaw(originalMimeType);
        let convertedBack = MimeType.fromRaw(raw);

        // Verify the roundtrip maintains the same structure
        switch (convertedBack) {
            case (#text_html(params)) {
                assert params.charset == ?"utf-8";
                assert params.level == ?"1";
                assert params.version == ?"5";
            };
            case (_) assert false;
        };
    },
);
