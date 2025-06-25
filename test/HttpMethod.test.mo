import { test } "mo:test";
import HttpMethod "../src/HttpMethod";

test(
    "HttpMethod.toText - converts all HTTP methods to correct text",
    func() : () {
        assert HttpMethod.toText(#get) == "GET";
        assert HttpMethod.toText(#post) == "POST";
        assert HttpMethod.toText(#put) == "PUT";
        assert HttpMethod.toText(#patch) == "PATCH";
        assert HttpMethod.toText(#delete) == "DELETE";
        assert HttpMethod.toText(#head) == "HEAD";
        assert HttpMethod.toText(#options) == "OPTIONS";
    },
);

test(
    "HttpMethod.fromText - parses valid HTTP method strings (case insensitive)",
    func() : () {
        // Test lowercase
        assert HttpMethod.fromText("get") == ?#get;
        assert HttpMethod.fromText("post") == ?#post;
        assert HttpMethod.fromText("put") == ?#put;
        assert HttpMethod.fromText("patch") == ?#patch;
        assert HttpMethod.fromText("delete") == ?#delete;
        assert HttpMethod.fromText("head") == ?#head;
        assert HttpMethod.fromText("options") == ?#options;

        // Test uppercase
        assert HttpMethod.fromText("GET") == ?#get;
        assert HttpMethod.fromText("POST") == ?#post;
        assert HttpMethod.fromText("PUT") == ?#put;
        assert HttpMethod.fromText("PATCH") == ?#patch;
        assert HttpMethod.fromText("DELETE") == ?#delete;
        assert HttpMethod.fromText("HEAD") == ?#head;
        assert HttpMethod.fromText("OPTIONS") == ?#options;

        // Test mixed case
        assert HttpMethod.fromText("Get") == ?#get;
        assert HttpMethod.fromText("PoSt") == ?#post;
        assert HttpMethod.fromText("PuT") == ?#put;
    },
);

test(
    "HttpMethod.fromText - returns null for invalid methods",
    func() : () {
        assert HttpMethod.fromText("INVALID") == null;
        assert HttpMethod.fromText("") == null;
        assert HttpMethod.fromText("connect") == null;
        assert HttpMethod.fromText("trace") == null;
        assert HttpMethod.fromText("123") == null;
        assert HttpMethod.fromText("get ") == null; // with space
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
            assert convertedBack == ?method;
        };
    },
);
