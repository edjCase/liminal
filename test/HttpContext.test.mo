import { test } "mo:test";
import HttpContext "../src/HttpContext";
import Runtime "mo:new-base/Runtime";

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
