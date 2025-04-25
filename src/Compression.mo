import HttpContext "./HttpContext";
import Types "./Types";
import Gzip "mo:compression/Gzip";
import Blob "mo:new-base/Blob";
import Text "mo:new-base/Text";
import Array "mo:new-base/Array";
import Buffer "mo:base/Buffer";
import List "mo:new-base/List";
import TextX "mo:xtended-text/TextX";
import Nat "mo:new-base/Nat";

module {

    // Configuration for compression middleware
    public type Config = {
        // Minimum size in bytes before compression is applied
        minSize : Nat;

        // Mime types that should be compressed
        mimeTypes : [Text];

        // Whether to skip compression for certain requests
        skipCompressionIf : ?SkipFunction;
    };

    // Skip function determines if a request should skip compression
    public type SkipFunction = HttpContext.HttpContext -> Bool;

    public func compressResponse(
        context : HttpContext.HttpContext,
        response : Types.HttpResponse,
        config : Config,
    ) : Types.HttpResponse {
        // Skip if there's no body to compress
        let ?body = response.body else return response;
        // Skip if body is too small
        if (body.size() < config.minSize) {
            return response;
        };

        // Skip if response is already compressed
        if (isAlreadyCompressed(response.headers)) {
            return response;
        };

        // Skip if content type is not compressible
        let contentType = getContentType(response.headers);
        if (not isCompressibleContentType(contentType, config.mimeTypes)) {
            return response;
        };

        // Skip if client doesn't accept gzip encoding
        let acceptsGzip = clientAcceptsGzip(context);
        if (not acceptsGzip) {
            return response;
        };

        // Skip if custom skip function is provided and returns true
        switch (config.skipCompressionIf) {
            case (?skipFn) {
                if (skipFn(context)) {
                    return response;
                };
            };
            case (null) {};
        };

        // Create a fresh encoder for each compression
        let gzipEncoder = Gzip.EncoderBuilder().build();

        // Compress the body
        let bytes = Blob.toArray(body);
        gzipEncoder.encode(bytes);
        let encoded = gzipEncoder.finish();

        // Prepare the compressed body
        var totalSize = 0;
        for (chunk in encoded.chunks.vals()) {
            totalSize += chunk.size();
        };

        let compressedBuffer = Buffer.Buffer<Nat8>(totalSize);
        for (chunk in encoded.chunks.vals()) {
            for (byte in chunk.vals()) {
                compressedBuffer.add(byte);
            };
        };
        let compressedBody = Blob.fromArray(Buffer.toArray(compressedBuffer));

        // Only compress if it actually reduces the size
        if (compressedBody.size() >= body.size()) {
            return response;
        };

        // Update headers
        let headers = removeHeader(response.headers, "content-length");
        let headersWithEncoding = List.fromArray<(Text, Text)>(headers);
        List.add(headersWithEncoding, ("Content-Encoding", "gzip"));
        List.add(headersWithEncoding, ("Vary", "Accept-Encoding"));
        List.add(headersWithEncoding, ("Content-Length", Nat.toText(compressedBody.size())));

        // Return compressed response
        return {
            response with
            headers = List.toArray(headersWithEncoding);
            body = ?compressedBody;
        };
    };

    // Check if the client accepts gzip encoding
    private func clientAcceptsGzip(context : HttpContext.HttpContext) : Bool {
        switch (context.getHeader("Accept-Encoding")) {
            case (null) return false;
            case (?acceptEncoding) {
                let encodings = Text.split(acceptEncoding, #char(','));
                for (encoding in encodings) {
                    let trimmed = Text.trim(encoding, #char(' '));
                    if (Text.startsWith(trimmed, #text("gzip")) or trimmed == "*") {
                        return true;
                    };
                };
                return false;
            };
        };
    };

    // Check if a response already has compression
    private func isAlreadyCompressed(headers : [(Text, Text)]) : Bool {
        for ((key, value) in headers.vals()) {
            if (TextX.equalIgnoreCase(key, "content-encoding")) {
                return true;
            };
        };
        return false;
    };

    // Get the content type from response headers
    private func getContentType(headers : [(Text, Text)]) : ?Text {
        for ((key, value) in headers.vals()) {
            if (TextX.equalIgnoreCase(key, "content-type")) {
                return ?value;
            };
        };
        return null;
    };

    // Check if a content type is compressible
    private func isCompressibleContentType(contentType : ?Text, compressibleTypes : [Text]) : Bool {
        switch (contentType) {
            case (null) return false;
            case (?ct) {
                let ctLower = Text.toLower(ct);
                for (prefix in compressibleTypes.vals()) {
                    if (Text.startsWith(ctLower, #text(Text.toLower(prefix)))) {
                        return true;
                    };
                };
                return false;
            };
        };
    };

    // Remove a header from the headers list
    private func removeHeader(headers : [(Text, Text)], nameToRemove : Text) : [(Text, Text)] {
        Array.filter(
            headers,
            func((key, _) : (Text, Text)) : Bool {
                not TextX.equalIgnoreCase(key, nameToRemove);
            },
        );
    };
};
