import HttpContext "./HttpContext";
import Gzip "mo:compression/Gzip";
import Lzss "mo:compression/LZSS";
import Blob "mo:new-base/Blob";
import Text "mo:new-base/Text";
import Array "mo:new-base/Array";
import Buffer "mo:base/Buffer";
import List "mo:new-base/List";
import TextX "mo:xtended-text/TextX";
import Nat "mo:new-base/Nat";
import Iter "mo:new-base/Iter";
import App "./App";
import ContentNegotiation "./ContentNegotiation";
import Types "./Types";
import Result "mo:new-base/Result";

module {

    // Configuration for compression middleware
    public type Config = {
        // Minimum size in bytes before compression is applied
        minSize : Nat;

        // Mime types that should be compressed
        mimeTypes : [Text];

        // Whether to skip compression for certain requests
        skipCompressionIf : ?SkipFunction;

        // Maximum size in bytes for request decompression (security limit)
        maxDecompressedSize : ?Nat;
    };

    // Skip function determines if a request should skip compression
    public type SkipFunction = HttpContext.HttpContext -> Bool;

    public type Encoding = {
        #gzip;
        // #deflate; TODO there is a bug in the Deflate library
    };

    public type DecompressionResult = {
        #success : Types.HttpRequest;
        #error : Text;
        #unsupportedEncoding : Text;
        #sizeLimitExceeded;
    };

    /// Compresses raw byte data using the specified encoding algorithm.
    /// Currently supports gzip compression with more encodings planned for future releases.
    /// Returns the compressed data as a byte array.
    ///
    /// ```motoko
    /// let originalData = [72, 101, 108, 108, 111]; // "Hello" as bytes
    /// let compressed = Compression.compress(#gzip, originalData);
    /// // compressed contains the gzip-compressed version of the input
    /// ```
    public func compress(encoding : Encoding, data : [Nat8]) : [Nat8] {
        switch (encoding) {
            case (#gzip) {
                let encoder = Gzip.EncoderBuilder().build();
                encoder.encode(data);
                let encoded = encoder.finish();
                compressedBlobFromChunks(encoded.chunks);
            };
            // case (#deflate) {
            //     let encoder = Deflate.buildEncoder({
            //         block_size = 1048576; // 1MB
            //         dynamic_huffman = true; // Better compression
            //         lzss = ?Lzss.Encoder(null);
            //     });
            //     encoder.encode(data);
            //     let encoded = encoder.finish();
            //     Iter.toArray(encoded.bytes());
            // };
        };
    };

    /// Decompresses raw byte data using the specified encoding algorithm.
    /// Currently supports gzip decompression with more encodings planned for future releases.
    /// Returns either the decompressed data or an error message.
    ///
    /// ```motoko
    /// let compressedData = [/* gzip compressed bytes */];
    /// switch (Compression.decompress(#gzip, compressedData)) {
    ///     case (#ok(decompressed)) {
    ///         // Successfully decompressed data
    ///     };
    ///     case (#err(errorMessage)) {
    ///         // Handle decompression error
    ///     };
    /// };
    /// ```
    public func decompress(encoding : Encoding, data : [Nat8]) : Result.Result<[Nat8], Text> {
        switch (encoding) {
            case (#gzip) {
                let decoder = Gzip.Decoder();
                decoder.decode(data);
                let response = decoder.finish();
                #ok(Buffer.toArray(response.buffer));
            };
            // case (#deflate) {
            //     let buffer = Buffer.fromArray<Nat8>(data);
            //     let decoder = Deflate.buildDecoder(?buffer);
            //     switch (decoder.decode()) {
            //         case (#ok) ();
            //         case (#err(e)) return #err("Decompression failed: " # e);
            //     };
            //     switch (decoder.finish()) {
            //         case (#ok) ();
            //         case (#err(e)) return #err("Decompression failed: " # e);
            //     };
            //     #ok(Buffer.toArray(buffer));
            // };
        };
    };

    /// Compresses an HTTP response based on client preferences and configuration.
    /// Automatically selects the best compression encoding supported by both client and server.
    /// Skips compression for small responses, incompressible content types, or when custom skip conditions are met.
    ///
    /// ```motoko
    /// import Compression "mo:liminal/Compression";
    ///
    /// let config = {
    ///     minSize = 1024;
    ///     mimeTypes = ["text/html", "application/json"];
    ///     skipCompressionIf = null;
    ///     maxDecompressedSize = ?(10 * 1024 * 1024); // 10MB
    /// };
    /// let compressedResponse = Compression.compressResponse(httpContext, response, config);
    /// ```
    public func compressResponse(
        context : HttpContext.HttpContext,
        response : App.HttpResponse,
        config : Config,
    ) : App.HttpResponse {
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

        // Get client's accepted encodings in order of preference
        let ?encodingsHeader = context.getHeader("accept-encoding") else {
            // No Accept-Encoding header, so return the original response
            return response;
        };
        let acceptedEncodings = ContentNegotiation.parseEncodingTypes(encodingsHeader);

        // Skip if custom skip function is provided and returns true
        switch (config.skipCompressionIf) {
            case (?skipFn) {
                if (skipFn(context)) {
                    return response;
                };
            };
            case (null) {};
        };

        // Try to compress with the first compatible encoding
        label f for (requestedEncoding in acceptedEncodings.requestedEncodings.vals()) {
            let encoding : Encoding = switch (requestedEncoding) {
                case (#identity) return response;
                case (#gzip) #gzip;
                case (#deflate) continue f; // Deflate is not supported yet
                case (#br) continue f; // Brotli is not supported yet
                case (#compress) continue f; // Compress is not supported
                case (#zstd) continue f; // Zstandard is not supported
                case (#wildcard) {
                    let supportedEncodings = [
                        #gzip,
                    ]; // TODO make this dynamic
                    label f for (encoding in supportedEncodings.vals()) {
                        for (disallowedEncoding in acceptedEncodings.disallowedEncodings.vals()) {
                            if (encoding == disallowedEncoding) {
                                continue f; // Skip if encoding is disallowed
                            };
                        };
                        // Try to compress with the first compatible encoding
                        let ?compressedResponse = tryCompress(
                            response,
                            body,
                            encoding,
                        ) else continue f;
                        return compressedResponse;
                    };
                    continue f;
                };
            };
            let ?compressedResponse = tryCompress(
                response,
                body,
                encoding,
            ) else continue f;
            return compressedResponse;
        };

        for (disallowedEncoding in acceptedEncodings.disallowedEncodings.vals()) {
            if (disallowedEncoding == #identity) {
                // If identity encoding is not allowed, return an error
                return context.buildResponse(
                    #notAcceptable,
                    #error(#message("No suitable encoding found for " # encodingsHeader # " in Accept-Encoding header")),
                );
            };
        };

        // Identity encoding, don't compress
        return response;
    };

    /// Decompresses an HTTP request if it has a Content-Encoding header.
    /// Handles encodings automatically.
    /// Returns a result indicating success, error, or unsupported encoding.
    ///
    /// ```motoko
    /// import Compression "mo:liminal/Compression";
    ///
    /// let config = {
    ///     minSize = 1024;
    ///     mimeTypes = ["text/html", "application/json"];
    ///     skipCompressionIf = null;
    ///     maxDecompressedSize = ?(10 * 1024 * 1024); // 10MB
    /// };
    ///
    /// switch (Compression.decompressRequest(request, config)) {
    ///     case (#success(decompressedRequest)) {
    ///         // Process decompressed request
    ///     };
    ///     case (#error(message)) {
    ///         // Handle decompression error
    ///     };
    ///     case (#unsupportedEncoding(encoding)) {
    ///         // Handle unsupported encoding
    ///     };
    ///     case (#sizeLimitExceeded) {
    ///         // Handle size limit exceeded
    ///     };
    /// };
    /// ```
    public func decompressRequest(
        request : Types.HttpRequest,
        config : Config,
    ) : DecompressionResult {
        if (request.body.size() == 0) {
            // No body to decompress, return original request
            return #success(request);
        };

        // Check for Content-Encoding header
        let ?encodingHeader = getContentEncoding(request.headers) else {
            // No Content-Encoding header, return original request
            return #success(request);
        };

        // Skip if already identity encoding
        if (TextX.equalIgnoreCase(encodingHeader, "identity")) {
            return #success(request);
        };

        // Parse the encoding
        let encoding : Encoding = switch (Text.toLower(encodingHeader)) {
            case ("gzip") #gzip;
            // case ("deflate") #deflate;
            case (_) return #unsupportedEncoding(encodingHeader);
        };

        // Try to decompress
        switch (tryDecompress(request.body, encoding, config.maxDecompressedSize)) {
            case (#success(decompressedBody)) {
                // Update headers - remove Content-Encoding and update Content-Length
                let headers = request.headers
                |> removeHeader(_, "content-encoding")
                |> removeHeader(_, "content-length")
                |> List.fromArray<(Text, Text)>(_);

                List.add(headers, ("Content-Length", Nat.toText(decompressedBody.size())));

                // Return decompressed request
                return #success({
                    request with
                    headers = List.toArray(headers);
                    body = decompressedBody;
                });
            };
            case (#error(message)) return #error(message);
            case (#sizeLimitExceeded) return #sizeLimitExceeded;
            case (#unsupportedEncoding) return #unsupportedEncoding(encodingHeader);
        };
    };

    private func tryCompress(
        response : App.HttpResponse,
        body : Blob,
        encoding : Encoding,
    ) : ?App.HttpResponse {
        let bytes = Blob.toArray(body);
        let compressedBody = compress(encoding, bytes);
        // Skip if compression didn't reduce size
        if (compressedBody.size() >= body.size()) {
            return null;
        };

        // Update headers
        let headers = response.headers
        |> removeHeader(_, "content-length")
        |> List.fromArray<(Text, Text)>(_);
        let encodingName = encodingToText(encoding);
        List.add(headers, ("Content-Encoding", encodingName));

        switch (getHeader(headers, "Vary")) {
            case (null) {
                List.add(headers, ("Vary", "Accept-Encoding"));
            };
            case (?(existing, i)) {
                List.put(headers, i, ("Vary", existing # ", Accept-Encoding"));
            };
        };
        List.add(headers, ("Content-Length", Nat.toText(compressedBody.size())));

        // Return compressed response
        return ?{
            response with
            headers = List.toArray(headers);
            body = ?Blob.fromArray(compressedBody);
        };
    };

    private type DecompressResult = {
        #success : Blob;
        #error : Text;
        #sizeLimitExceeded;
        #unsupportedEncoding;
    };

    private func tryDecompress(
        body : Blob,
        encoding : Encoding,
        maxSize : ?Nat,
    ) : DecompressResult {
        let bytes = Blob.toArray(body);

        switch (decompress(encoding, bytes)) {
            case (#ok(decompressedBytes)) {
                let decompressed = Blob.fromArray(decompressedBytes);

                // Check size limit if specified
                switch (maxSize) {
                    case (?limit) {
                        if (decompressed.size() > limit) {
                            return #sizeLimitExceeded;
                        };
                    };
                    case (null) {};
                };

                return #success(decompressed);
            };
            case (#err(e)) return #error("Decompression failed for encoding '" # encodingToText(encoding) # "': " # e);
        };
    };

    // Convert encoding enum to text
    private func encodingToText(encoding : Encoding) : Text {
        switch (encoding) {
            case (#gzip) "gzip";
            // case (#deflate) "deflate";
        };
    };

    // Helper to convert encoder output chunks to blob
    private func compressedBlobFromChunks(chunks : [[Nat8]]) : [Nat8] {
        var totalSize = 0;
        for (chunk in chunks.vals()) {
            totalSize += chunk.size();
        };

        let buffer = Buffer.Buffer<Nat8>(totalSize);
        for (chunk in chunks.vals()) {
            for (byte in chunk.vals()) {
                buffer.add(byte);
            };
        };

        return Buffer.toArray(buffer);
    };

    // Check if a response already has compression
    private func isAlreadyCompressed(headers : [(Text, Text)]) : Bool {
        for ((key, value) in headers.vals()) {
            if (TextX.equalIgnoreCase(key, "content-encoding") and not TextX.equalIgnoreCase(value, "identity")) {
                return true;
            };
            if (TextX.equalIgnoreCase(key, "ic-certificate")) {
                // If the response is certified, we don't want to compress it or it will invalidate the certificate
                // TODO is this the best place to check for this?
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

    // Get the content encoding from request headers
    private func getContentEncoding(headers : [(Text, Text)]) : ?Text {
        for ((key, value) in headers.vals()) {
            if (TextX.equalIgnoreCase(key, "content-encoding")) {
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

    func getHeader(headers : List.List<(Text, Text)>, key : Text) : ?(Text, Nat) {
        var i = 0;
        for (((k, v), i) in List.entries(headers)) {
            if (k == key) return ?(v, i);
        };
        null;
    };
};
