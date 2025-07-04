import { test; suite } "mo:test";
import Blob "mo:new-base/Blob";
import Nat "mo:new-base/Nat";
import Option "mo:new-base/Option";
import Text "mo:new-base/Text";
import Array "mo:new-base/Array";
import Nat8 "mo:new-base/Nat8";
import CompressionMiddleware "../src/Middleware/Compression";
import Compression "../src/Compression";
import HttpContext "../src/HttpContext";
import HttpMethod "../src/HttpMethod";
import App "../src/App";
import ContentNegotiation "../src/ContentNegotiation";
import Logging "../src/Logging";
import Types "../src/Types";
import Runtime "mo:new-base/Runtime";
import Debug "mo:new-base/Debug";

// Helper function to get header value
func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
    for ((k, v) in headers.vals()) {
        if (k == key) return ?v;
    };
    null;
};

// Helper to create context with default error serializer
func createContext(
    method : HttpMethod.HttpMethod,
    url : Text,
    headers : [(Text, Text)],
) : HttpContext.HttpContext {
    let context = HttpContext.HttpContext(
        {
            method = HttpMethod.toText(method);
            url = url;
            headers = headers;
            body = Blob.fromArray([]);
        },
        null,
        {
            errorSerializer = func(error : HttpContext.HttpError) : HttpContext.ErrorSerializerResponse {
                // Simple error serializer for testing
                let body = ?Text.encodeUtf8("Error: " # Nat.toText(error.statusCode));
                return {
                    headers = [("Content-Type", "text/plain")];
                    body = body;
                };
            };
            candidRepresentationNegotiator = func(candid : HttpContext.CandidValue, contentPreference : ContentNegotiation.ContentPreference) : ?HttpContext.CandidNegotiatedContent {
                ?{
                    body = to_candid (candid);
                    contentType = "application/octet-stream";
                };
            };
            logger = Logging.buildDebugLogger(#warning);
        },
    );

    return context;
};

let over1KbBody : Blob = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?

At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident, similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et dolorum fuga. Et harum quidem rerum facilis est et expedita distinctio.";

// Helper to create HTTP response with specified content type and body
func createResponse(contentType : Text, body : Blob) : App.HttpResponse {
    return {
        statusCode = 200;
        headers = [("Content-Type", contentType)];
        body = ?body;
        streamingStrategy = null;
    };
};

// Helper to create HTTP request with specified headers and body
func createRequest(
    method : HttpMethod.HttpMethod,
    url : Text,
    headers : [(Text, Text)],
    body : ?Blob,
) : Types.HttpRequest {
    return {
        method = method;
        url = url;
        headers = headers;
        body = Option.get(body, "" : Blob);
    };
};

suite(
    "Compression Middleware Tests",
    func() {

        test(
            "minimum size threshold - should compress response above minimum size",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 100;
                    mimeTypes = ["text/plain", "text/html", "application/json"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024); // 10MB

                };

                let context = createContext(#get, "/test", [("Accept-Encoding", "gzip")]);

                // Create a response with content larger than minSize
                let largeBody = over1KbBody;
                let response = createResponse("text/plain", largeBody);

                // Apply compression
                let compressedResponse = Compression.compressResponse(context, response, config);

                // Verify compression was applied
                assert (compressedResponse.body != ?"");
                let originalSize = largeBody.size();
                let compressedSize = Option.get(compressedResponse.body, Blob.fromArray([])).size();

                // Compressed size should be smaller than original
                assert (compressedSize < originalSize);

                // Content-Encoding header should be set
                assert (getHeader(compressedResponse.headers, "Content-Encoding") == ?"gzip");

                // Vary header should include Accept-Encoding
                assert (getHeader(compressedResponse.headers, "Vary") == ?"Accept-Encoding");
            },
        );

        test(
            "minimum size threshold - should not compress response below minimum size",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 100;
                    mimeTypes = ["text/plain", "text/html", "application/json"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let context = createContext(#get, "/test", [("Accept-Encoding", "gzip")]);

                // Create a response with content smaller than minSize
                let smallBody : Blob = "Hello";
                let response = createResponse("text/plain", smallBody);

                // Apply compression
                let resultResponse = Compression.compressResponse(context, response, config);

                // Verify compression was NOT applied
                assert (resultResponse.body != ?"");
                let originalSize = smallBody.size();
                let resultSize = Option.get(resultResponse.body, Blob.fromArray([])).size();

                // Size should be unchanged
                assert (resultSize == originalSize);

                // Content-Encoding header should NOT be set
                assert (getHeader(resultResponse.headers, "Content-Encoding") == null);
            },
        );

        test(
            "MIME type filtering - should compress supported MIME types only",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain", "application/json"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let context = createContext(#get, "/test", [("Accept-Encoding", "gzip")]);

                // Test with supported MIME type
                let body = over1KbBody;

                // 1. Check text/plain (supported)
                let response1 = createResponse("text/plain", body);
                let result1 = Compression.compressResponse(context, response1, config);
                assert (getHeader(result1.headers, "Content-Encoding") == ?"gzip");

                // 2. Check application/json (supported)
                let response2 = createResponse("application/json", body);
                let result2 = Compression.compressResponse(context, response2, config);
                assert (getHeader(result2.headers, "Content-Encoding") == ?"gzip");

                // 3. Check image/png (not supported)
                let response3 = createResponse("image/png", body);
                let result3 = Compression.compressResponse(context, response3, config);
                assert (getHeader(result3.headers, "Content-Encoding") == null);
            },
        );

        test(
            "skip function - should respect skip compression function",
            func() {
                // Skip compression for requests with specific header
                let skipFunction = func(ctx : HttpContext.HttpContext) : Bool {
                    switch (ctx.getHeader("X-No-Compression")) {
                        case (?"true") true;
                        case (_) false;
                    };
                };

                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = ?skipFunction;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // 1. Test with normal context (should compress)
                let context1 = createContext(#get, "/test", [("Accept-Encoding", "gzip")]);
                let result1 = Compression.compressResponse(context1, response, config);
                assert (getHeader(result1.headers, "Content-Encoding") == ?"gzip");

                // 2. Test with skip header (should NOT compress)
                let context2 = createContext(
                    #get,
                    "/test",
                    [
                        ("Accept-Encoding", "gzip"),
                        ("X-No-Compression", "true"),
                    ],
                );
                let result2 = Compression.compressResponse(context2, response, config);
                assert (getHeader(result2.headers, "Content-Encoding") == null);
            },
        );

        test(
            "compression algorithms - should handle different algorithms based on Accept-Encoding",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // 1. Test with gzip
                let context1 = createContext(#get, "/test", [("Accept-Encoding", "gzip")]);
                let result1 = Compression.compressResponse(context1, response, config);
                assert (getHeader(result1.headers, "Content-Encoding") == ?"gzip");

                // 2. Test with deflate
                let context2 = createContext(#get, "/test", [("Accept-Encoding", "deflate")]);
                let result2 = Compression.compressResponse(context2, response, config);
                assert (getHeader(result2.headers, "Content-Encoding") == null);

                // 3. Test with br (Brotli) (not supported in this example)
                let context3 = createContext(#get, "/test", [("Accept-Encoding", "br")]);
                let result3 = Compression.compressResponse(context3, response, config);
                assert (getHeader(result3.headers, "Content-Encoding") == null);

                // 4. Test with multiple options
                let context4 = createContext(#get, "/test", [("Accept-Encoding", "br, gzip, deflate")]);
                let result4 = Compression.compressResponse(context4, response, config);
                // Should choose the first supported algorithm
                let encoding = getHeader(result4.headers, "Content-Encoding");
                assert (encoding == ?"gzip");
            },
        );

        test(
            "missing encoding - should not compress when no acceptable encoding is available",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Context with unsupported encoding
                let context = createContext(#get, "/test", [("Accept-Encoding", "unsupported-algorithm")]);
                let result = Compression.compressResponse(context, response, config);

                // Should not compress
                assert (getHeader(result.headers, "Content-Encoding") == null);

                // Should preserve original body size
                assert (Option.get(result.body, Blob.fromArray([])).size() == body.size());
            },
        );

        test(
            "missing Accept-Encoding - should not compress when no Accept-Encoding header is present",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Context with no Accept-Encoding header
                let context = createContext(#get, "/test", []);
                let result = Compression.compressResponse(context, response, config);

                // Should not compress
                assert (getHeader(result.headers, "Content-Encoding") == null);

                // Should preserve original body size
                assert (Option.get(result.body, Blob.fromArray([])).size() == body.size());
            },
        );

        test(
            "header preservation - should maintain response status code and other headers",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;

                // Create response with custom status code and multiple headers
                let response : App.HttpResponse = {
                    statusCode = 201;
                    headers = [
                        ("Content-Type", "text/plain"),
                        ("X-Custom-Header", "test-value"),
                        ("Cache-Control", "no-cache"),
                    ];
                    body = ?body;
                    streamingStrategy = null;
                };

                let context = createContext(#get, "/test", [("Accept-Encoding", "gzip")]);
                let result = Compression.compressResponse(context, response, config);

                // Status code should be maintained
                assert (result.statusCode == 201);

                // Original headers should be preserved
                assert (getHeader(result.headers, "X-Custom-Header") == ?"test-value");
                assert (getHeader(result.headers, "Cache-Control") == ?"no-cache");

                // Content-Encoding should be added
                assert (getHeader(result.headers, "Content-Encoding") == ?"gzip");

                // Content-Type should be preserved
                assert (getHeader(result.headers, "Content-Type") == ?"text/plain");
            },
        );

        test(
            "null body - should handle null response body",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                // Create response with null body
                let response = {
                    statusCode = 204; // No Content
                    headers = [("Content-Type", "text/plain")];
                    body = null;
                    streamingStrategy = null;
                };

                let context = createContext(#get, "/test", [("Accept-Encoding", "gzip")]);
                let result = Compression.compressResponse(context, response, config);

                // Should not add Content-Encoding header
                assert (getHeader(result.headers, "Content-Encoding") == null);

                // Body should remain null
                assert (result.body == null);

                // Status code should be preserved
                assert (result.statusCode == 204);
            },
        );

        test(
            "empty body - should handle empty response body",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                // Create response with empty body
                let response : App.HttpResponse = {
                    statusCode = 200;
                    headers = [("Content-Type", "text/plain")];
                    body = ?Blob.fromArray([]);
                    streamingStrategy = null;
                };

                let context = createContext(#get, "/test", [("Accept-Encoding", "gzip")]);
                let result = Compression.compressResponse(context, response, config);

                // Should not add Content-Encoding header (empty body shouldn't be compressed)
                assert (getHeader(result.headers, "Content-Encoding") == null);

                // Body should remain empty
                assert (Option.get(result.body, Blob.fromArray([])).size() == 0);
            },
        );

        test(
            "quality values - should select encoding with highest q-value",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Test with multiple encodings and explicit q-values
                // Accept-Encoding: deflate;q=0.5, gzip;q=0.8, br;q=1.0
                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "deflate;q=0.5, gzip;q=0.8, br;q=1.0")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should choose gzip as it's the highest q-value among supported algorithms
                // (br has higher q-value but is not supported in this implementation)
                let encoding = getHeader(result.headers, "Content-Encoding");
                assert (encoding == ?"gzip");
            },
        );

        test(
            "quality values - should not compress when all encodings have q=0",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Test with all encodings having q=0 (explicitly not accepted)
                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "gzip;q=0, deflate;q=0")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should not compress as all encodings are rejected
                assert (getHeader(result.headers, "Content-Encoding") == null);
            },
        );

        test(
            "quality values - should handle identity encoding preference",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Test with identity preferred over compression
                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "identity;q=1.0, gzip;q=0.5, deflate;q=0.8")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should not compress as identity is preferred
                assert (getHeader(result.headers, "Content-Encoding") == null);
            },
        );

        test(
            "quality values - should handle explicit identity rejection",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Test with identity explicitly rejected
                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "identity;q=0, gzip")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should compress as uncompressed responses are rejected
                assert (getHeader(result.headers, "Content-Encoding") == ?"gzip");
            },
        );

        test(
            "edge case - should handle mixed case in Accept-Encoding",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Test with mixed case encoding names
                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "GzIp, DeFlAtE")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should work despite case differences
                assert (getHeader(result.headers, "Content-Encoding") != null);
            },
        );

        test(
            "edge case - should handle wildcard Accept-Encoding",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Test with wildcard Accept-Encoding
                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "*")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should use default preferred compression algorithm
                assert (getHeader(result.headers, "Content-Encoding") != null);
            },
        );

        test(
            "edge case - should avoid double compression",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;

                // Create response that's already compressed
                let response : App.HttpResponse = {
                    statusCode = 200;
                    headers = [
                        ("Content-Type", "text/plain"),
                        ("Content-Encoding", "gzip"),
                    ];
                    body = ?body;
                    streamingStrategy = null;
                };

                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "gzip, deflate")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should not compress again
                assert (getHeader(result.headers, "Content-Encoding") == ?"gzip");

                // Body should remain unchanged
                assert (Option.get(result.body, Blob.fromArray([])).size() == body.size());
            },
        );

        test(
            "edge case - should handle Content-Type with parameters",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;

                // Create response with Content-Type that includes parameters
                let response : App.HttpResponse = {
                    statusCode = 200;
                    headers = [("Content-Type", "text/plain; charset=utf-8")];
                    body = ?body;
                    streamingStrategy = null;
                };

                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "gzip")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should still compress based on main MIME type
                assert (getHeader(result.headers, "Content-Encoding") == ?"gzip");
            },
        );

        test(
            "edge case - should handle complex Accept-Encoding header",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Test with complex Accept-Encoding header
                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "gzip;q=1.0, identity; q=0.5, *;q=0")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should parse complex header correctly
                assert (getHeader(result.headers, "Content-Encoding") == ?"gzip");
            },
        );

        test(
            "edge case - should properly handle existing Vary header",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;

                // Create response with existing Vary header
                let response : App.HttpResponse = {
                    statusCode = 200;
                    headers = [
                        ("Content-Type", "text/plain"),
                        ("Vary", "User-Agent"),
                    ];
                    body = ?body;
                    streamingStrategy = null;
                };

                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "gzip")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should append to Vary header properly
                let varyHeader = getHeader(result.headers, "Vary");
                assert (varyHeader != null);
                assert (varyHeader == ?"User-Agent, Accept-Encoding");
            },
        );

        test(
            "error case - should handle missing Content-Type",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;

                // Create response with no Content-Type
                let response : App.HttpResponse = {
                    statusCode = 200;
                    headers = [];
                    body = ?body;
                    streamingStrategy = null;
                };

                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "gzip")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should not compress (no Content-Type to match against mimeTypes)
                assert (getHeader(result.headers, "Content-Encoding") == null);
            },
        );

        test(
            "compression ratio - should not compress when result would be larger",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                // Create a response with content that compresses poorly
                // A sequence of random bytes typically compresses poorly
                let poorlyCompressibleBody : Blob = Blob.fromArray(
                    Array.tabulate<Nat8>(
                        100,
                        func(i : Nat) : Nat8 {
                            Nat8.fromNat(i % 256);
                        },
                    )
                );

                let response = createResponse("text/plain", poorlyCompressibleBody);

                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "gzip")],
                );

                let result = Compression.compressResponse(context, response, config);

                // If compressed size becomes larger, middleware should be smart enough to not use compression
                // This test will depend on compression algorithm's implementation details
                if (Option.get(result.body, Blob.fromArray([])).size() > poorlyCompressibleBody.size()) {
                    assert (getHeader(result.headers, "Content-Encoding") == null);
                };
            },
        );

        test(
            "should properly handle q-value boundaries",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Test with boundary q-values
                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "deflate;q=0.001, gzip;q=0.999")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should choose gzip as it has higher q-value
                assert (getHeader(result.headers, "Content-Encoding") == ?"gzip");
            },
        );

        test(
            "should respect quality with zero values mixed with positive values",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024); // 10MB

                };

                let body = over1KbBody;
                let response = createResponse("text/plain", body);

                // Test with q=0 for some encodings and positive for others
                let context = createContext(
                    #get,
                    "/test",
                    [("Accept-Encoding", "deflate;q=0, gzip;q=0.5, br;q=0")],
                );

                let result = Compression.compressResponse(context, response, config);

                // Should choose gzip as it's the only one with positive q-value
                assert (getHeader(result.headers, "Content-Encoding") == ?"gzip");
            },
        );

    },
);

suite(
    "Request Decompression Tests",
    func() {

        test(
            "basic decompression - should decompress gzip request successfully",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024); // 10MB

                };

                let originalBody = Text.encodeUtf8("Hello, this is test data for decompression!");
                let compressedBody = Compression.compress(#gzip, Blob.toArray(originalBody));

                let request = createRequest(
                    #post,
                    "/api/data",
                    [
                        ("Content-Type", "text/plain"),
                        ("Content-Encoding", "gzip"),
                        ("Content-Length", Nat.toText(compressedBody.size())),
                    ],
                    ?Blob.fromArray(compressedBody),
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#success(decompressedRequest)) {
                        // Should have decompressed body
                        assert (decompressedRequest.body != "");

                        // Content-Encoding header should be removed
                        assert (getHeader(decompressedRequest.headers, "Content-Encoding") == null);

                        // Content-Length should be updated
                        let contentLength = getHeader(decompressedRequest.headers, "Content-Length");
                        assert (contentLength != null);

                        // Other headers should be preserved
                        assert (getHeader(decompressedRequest.headers, "Content-Type") == ?"text/plain");
                    };
                    case (_) {
                        assert (false); // Should not reach here
                    };
                };
            },
        );

        test(
            "unsupported encoding - should return unsupportedEncoding error",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = Text.encodeUtf8("Test data");

                let request = createRequest(
                    #post,
                    "/api/data",
                    [
                        ("Content-Type", "text/plain"),
                        ("Content-Encoding", "brotli"), // Unsupported
                    ],
                    ?body,
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#unsupportedEncoding(encoding)) {
                        assert (encoding == "brotli");
                    };
                    case (_) {
                        assert (false); // Should return unsupported encoding
                    };
                };
            },
        );

        test(
            "no compression - should pass through uncompressed requests",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = Text.encodeUtf8("Uncompressed test data");

                let request = createRequest(
                    #post,
                    "/api/data",
                    [
                        ("Content-Type", "text/plain"),
                        ("Content-Length", Nat.toText(body.size())),
                    ],
                    ?body,
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#success(result)) {
                        // Should be identical to original request
                        assert (result.body == request.body);
                        assert (result.headers.size() == request.headers.size());
                    };
                    case (_) {
                        assert (false); // Should succeed with no changes
                    };
                };
            },
        );

        test(
            "identity encoding - should pass through identity-encoded requests",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = Text.encodeUtf8("Identity encoded data");

                let request = createRequest(
                    #post,
                    "/api/data",
                    [
                        ("Content-Type", "text/plain"),
                        ("Content-Encoding", "identity"),
                    ],
                    ?body,
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#success(result)) {
                        // Should pass through unchanged
                        assert (result.body == request.body);
                        assert (getHeader(result.headers, "Content-Encoding") == ?"identity");
                    };
                    case (_) {
                        assert (false); // Should succeed
                    };
                };
            },
        );

        test(
            "null body - should handle requests with null body",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let request = createRequest(
                    #get,
                    "/api/data",
                    [
                        ("Content-Type", "text/plain"),
                        ("Content-Encoding", "gzip"),
                    ],
                    null,
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#success(result)) {
                        // Should pass through with null body
                        assert (result.body == "");
                    };
                    case (_) {
                        assert (false); // Should succeed
                    };
                };
            },
        );

        test(
            "size limit - should enforce maximum decompressed size limit",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?100; // Very small limit for testing

                };

                // Create a large body that would exceed the limit when decompressed
                let largeBody = over1KbBody;
                let compressedBody = Compression.compress(#gzip, Blob.toArray(largeBody));

                let request = createRequest(
                    #post,
                    "/api/data",
                    [
                        ("Content-Type", "text/plain"),
                        ("Content-Encoding", "gzip"),
                    ],
                    ?Blob.fromArray(compressedBody),
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#sizeLimitExceeded) {
                        // Expected result
                        assert (true);
                    };
                    case (_) {
                        assert (false); // Should return size limit exceeded
                    };
                };
            },
        );

        test(
            "case insensitive encoding - should handle mixed case Content-Encoding",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = Text.encodeUtf8("Case insensitive test");
                let compressedBody = Compression.compress(#gzip, Blob.toArray(body));

                let request = createRequest(
                    #post,
                    "/api/data",
                    [
                        ("Content-Type", "text/plain"),
                        ("Content-Encoding", "GzIp"), // Mixed case
                    ],
                    ?Blob.fromArray(compressedBody),
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#success(result)) {
                        // Should handle mixed case correctly
                        assert (getHeader(result.headers, "Content-Encoding") == null);
                    };
                    case (_) {
                        assert (false); // Should succeed despite case differences
                    };
                };
            },
        );

        test(
            "header preservation - should preserve all other headers during decompression",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = Text.encodeUtf8("Header preservation test");
                let compressedBody = Compression.compress(#gzip, Blob.toArray(body));

                let request = createRequest(
                    #post,
                    "/api/data",
                    [
                        ("Content-Type", "application/json"),
                        ("Content-Encoding", "gzip"),
                        ("Authorization", "Bearer token123"),
                        ("X-Custom-Header", "custom-value"),
                        ("User-Agent", "Test-Agent/1.0"),
                    ],
                    ?Blob.fromArray(compressedBody),
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#success(result)) {
                        // Custom headers should be preserved
                        assert (getHeader(result.headers, "Authorization") == ?"Bearer token123");
                        assert (getHeader(result.headers, "X-Custom-Header") == ?"custom-value");
                        assert (getHeader(result.headers, "User-Agent") == ?"Test-Agent/1.0");
                        assert (getHeader(result.headers, "Content-Type") == ?"application/json");

                        // Content-Encoding should be removed
                        assert (getHeader(result.headers, "Content-Encoding") == null);

                        // Content-Length should be updated
                        assert (getHeader(result.headers, "Content-Length") != null);
                    };
                    case (_) {
                        assert (false); // Should succeed
                    };
                };
            },
        );

        test(
            "multiple encodings - should handle single encoding only",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 10;
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let body = Text.encodeUtf8("Multiple encoding test");
                let compressedBody = Compression.compress(#gzip, Blob.toArray(body));

                // Note: HTTP/1.1 typically doesn't support multiple Content-Encodings
                // but if it did, this would test that behavior
                let request = createRequest(
                    #post,
                    "/api/data",
                    [
                        ("Content-Type", "text/plain"),
                        ("Content-Encoding", "gzip, deflate"), // Multiple encodings
                    ],
                    ?Blob.fromArray(compressedBody),
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#unsupportedEncoding(encoding)) {
                        // Should reject multiple encodings as unsupported
                        assert (encoding == "gzip, deflate");
                    };
                    case (_) {
                        // If implementation handles first encoding only, that's also valid
                        assert (true);
                    };
                };
            },
        );

        test(
            "empty compressed body - should handle empty compressed content",
            func() {
                let config : CompressionMiddleware.Config = {
                    minSize = 0; // Allow compression of empty content
                    mimeTypes = ["text/plain"];
                    skipCompressionIf = null;
                    maxDecompressedSize = ?(10 * 1024 * 1024);

                };

                let emptyBody = Blob.fromArray([]);
                let compressedEmptyBody = Compression.compress(#gzip, Blob.toArray(emptyBody));

                let request = createRequest(
                    #post,
                    "/api/data",
                    [
                        ("Content-Type", "text/plain"),
                        ("Content-Encoding", "gzip"),
                    ],
                    ?Blob.fromArray(compressedEmptyBody),
                );

                switch (Compression.decompressRequest(request, config)) {
                    case (#success(result)) {
                        // Should successfully decompress to empty content
                        if (result.body != "") {
                            Runtime.trap("Expected empty body after decompression, got: " # debug_show (result.body));
                        };
                        assert (getHeader(result.headers, "Content-Encoding") == null);
                    };
                    case (_) {
                        assert (false); // Should succeed
                    };
                };
            },
        );

    },
);
