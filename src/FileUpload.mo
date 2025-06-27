import HttpContext "HttpContext";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Blob "mo:new-base/Blob";
import Nat "mo:new-base/Nat";
import TextX "mo:xtended-text/TextX";
import Buffer "mo:base/Buffer";

module {

    public type UploadedFile = {
        /// Name of the form field that contained the file
        fieldName : Text;
        /// Original filename from the client
        filename : Text;
        /// MIME type of the file
        contentType : Text;
        /// Size of the file in bytes
        size : Nat;
        /// The file content as a Blob
        content : Blob;
    };

    /// Parses multipart/form-data content from an HTTP request.
    /// Extracts uploaded files and their metadata from form submissions.
    /// Returns an empty array if the request is not multipart/form-data.
    ///
    /// ```motoko
    /// import FileUpload "mo:liminal/FileUpload";
    ///
    /// let files = FileUpload.parseMultipartFormData(httpContext);
    /// for (file in files.vals()) {
    ///     let name = file.fieldName;
    ///     let filename = file.filename;
    ///     let size = file.size;
    ///     let content = file.content;
    ///     // Process uploaded file
    /// };
    /// ```
    public func parseMultipartFormData(context : HttpContext.HttpContext) : [UploadedFile] {
        // Check if content type is multipart/form-data
        let ?contentType = context.getHeader("Content-Type") else return [];
        if (not Text.startsWith(contentType, #text("multipart/form-data"))) {
            return [];
        };

        // Extract boundary from content type using our helper
        let ?boundary = getFormValue(contentType, "boundary=") else return [];

        // Parse the multipart content using the boundary
        return parseMultipartContent(boundary, context);
    };

    /// Extract a value after a key in a string (e.g., "boundary=" from Content-Type header)
    /// Returns the trimmed value or null if key not found
    private func getFormValue(source : Text, key : Text) : ?Text {
        // Use Text.contains to check if the key exists in the source
        if (not Text.contains(source, #text(key))) {
            return null;
        };

        // Split the source on the key
        let parts = Iter.toArray(Text.split(source, #text(key)));

        // The value will be in the second part of the split
        if (parts.size() < 2) {
            return null;
        };

        let value = parts[1];
        // Trim quotes if present
        let trimmed = Text.trim(value, #text("\""));

        // If there are other parameters or end of string, cut at that point
        let valueParts = Iter.toArray(Text.split(trimmed, #text(";")));
        if (valueParts.size() > 0) {
            return ?valueParts[0];
        } else {
            return ?trimmed;
        };
    };

    private func parseMultipartContent(boundary : Text, context : HttpContext.HttpContext) : [UploadedFile] {
        let requestBody = context.request.body;

        // Convert boundary markers to their byte representation
        let boundaryBytes = Blob.toArray(Text.encodeUtf8("--" # boundary));
        let crlfBoundaryBytes = Blob.toArray(Text.encodeUtf8("\r\n--" # boundary));
        let headerSeparatorBytes = Blob.toArray(Text.encodeUtf8("\r\n\r\n"));

        // Convert blob to array for easier manipulation
        let bodyBytes = Blob.toArray(requestBody);

        let files = Buffer.Buffer<UploadedFile>(4);

        // Find parts by locating boundaries
        let parts = findParts(bodyBytes, boundaryBytes, crlfBoundaryBytes);

        label f for (part in parts.vals()) {
            // Find header/content separator in this part
            let separatorPos = findSubArray(part, headerSeparatorBytes);

            switch (separatorPos) {
                case (null) ();
                case (?pos) {
                    // Extract header bytes (always text/UTF-8)
                    let headerBytes = subArray(part, 0, pos);

                    // Extract content bytes (might be binary)
                    let contentBytes = subArray(part, pos + headerSeparatorBytes.size(), part.size() - pos - headerSeparatorBytes.size());

                    // Headers are always UTF-8/ASCII
                    let ?headersText = Text.decodeUtf8(Blob.fromArray(headerBytes)) else continue f;
                    let headers = parsePartHeaders(headersText);

                    // Check if this is a file upload
                    if (isFileUpload(headers)) {
                        let fieldName = getFieldName(headers);
                        let filename = getFilename(headers);
                        let contentType = getContentType(headers);

                        files.add({
                            fieldName = fieldName;
                            filename = filename;
                            contentType = contentType;
                            size = contentBytes.size();
                            content = Blob.fromArray(contentBytes);
                        });
                    };
                };
            };
        };

        return Buffer.toArray(files);
    };

    /// Check if a part represents a file upload
    private func isFileUpload(headers : [(Text, Text)]) : Bool {
        let contentDisposition = getHeaderValue(headers, "Content-Disposition");
        switch (contentDisposition) {
            case (null) return false;
            case (?cd) {
                return Text.contains(cd, #text("filename="));
            };
        };
    };

    /// Get the content type from the headers
    private func getContentType(headers : [(Text, Text)]) : Text {
        let contentType = getHeaderValue(headers, "Content-Type");
        switch (contentType) {
            case (null) return "application/octet-stream"; // Default content type
            case (?ct) return ct;
        };
    };

    /// Get the filename from the headers
    private func getFilename(headers : [(Text, Text)]) : Text {
        let contentDisposition = getHeaderValue(headers, "Content-Disposition");
        switch (contentDisposition) {
            case (null) return "";
            case (?cd) {
                let ?filename = getFormValue(cd, "filename=") else return "";
                // Remove trailing quote if present
                return Text.trim(filename, #text("\""));
            };
        };
    };

    /// Get the field name from the headers
    private func getFieldName(headers : [(Text, Text)]) : Text {
        let contentDisposition = getHeaderValue(headers, "Content-Disposition");
        switch (contentDisposition) {
            case (null) return "";
            case (?cd) {
                let ?name = getFormValue(cd, "name=") else return "";
                // Remove trailing quote if present
                return Text.trim(name, #text("\""));
            };
        };
    };

    /// Helper to get a header value by name (case-insensitive)
    private func getHeaderValue(headers : [(Text, Text)], name : Text) : ?Text {
        for ((headerName, headerValue) in headers.vals()) {
            if (TextX.equalIgnoreCase(headerName, name)) {
                return ?headerValue;
            };
        };
        return null;
    };

    /// Parse headers from a multipart part
    private func parsePartHeaders(headersText : Text) : [(Text, Text)] {
        let headerLines = Text.split(headersText, #text("\r\n"));
        let headers = Buffer.Buffer<(Text, Text)>(4);

        for (line in headerLines) {
            let colonParts = Iter.toArray(Text.split(line, #text(":")));
            if (colonParts.size() >= 2) {
                let name = Text.trim(colonParts[0], #char(' '));
                // Combine all parts after the first colon
                var value = "";
                var i = 1;
                while (i < colonParts.size()) {
                    if (i > 1) {
                        value #= ":"; // Re-add colons for values that contained them
                    };
                    value #= colonParts[i];
                    i += 1;
                };
                headers.add((name, Text.trim(value, #char(' '))));
            };
        };

        return Buffer.toArray(headers);
    };

    private func subArray(array : [Nat8], start : Nat, length : Nat) : [Nat8] {
        let size = array.size();

        // Handle out of bounds
        let startIdx = if (start >= size) { size } else { start };
        let endIdx = if (startIdx + length > size) { size } else {
            startIdx + length;
        };

        // Create new array with elements from startIdx to endIdx
        Array.tabulate<Nat8>(endIdx - startIdx, func i = array[startIdx + i]);
    };

    // Helper function to find all parts between boundaries
    private func findParts(data : [Nat8], firstBoundary : [Nat8], otherBoundaries : [Nat8]) : [[Nat8]] {
        let parts = Buffer.Buffer<[Nat8]>(8);

        // Find first boundary
        let ?startPos = findSubArray(data, firstBoundary) else return [];
        var pos = startPos + firstBoundary.size();

        // Find subsequent boundaries
        label w while (pos < data.size()) {
            let nextBoundaryPos = findSubArrayFrom(data, otherBoundaries, pos);

            switch (nextBoundaryPos) {
                case (null) {
                    // Last part - goes to the end
                    let lastPart = subArray(data, pos, data.size() - pos);
                    if (lastPart.size() > 0) {
                        parts.add(lastPart);
                    };
                    break w;
                };
                case (?nextPos) {
                    // Add this part
                    let partData = subArray(data, pos, nextPos - pos);
                    if (partData.size() > 0) {
                        parts.add(partData);
                    };
                    pos := nextPos + otherBoundaries.size();

                    // Check if this is the end boundary (has "--" suffix)
                    if (pos + 2 <= data.size() and data[pos] == 45 and data[pos + 1] == 45) {
                        // End of multipart data
                        break w;
                    };
                };
            };
        };

        return Buffer.toArray(parts);
    };

    // Find first occurrence of a subarray in an array
    private func findSubArray(haystack : [Nat8], needle : [Nat8]) : ?Nat {
        findSubArrayFrom(haystack, needle, 0);
    };

    // Find first occurrence of a subarray in an array starting from a position
    private func findSubArrayFrom(haystack : [Nat8], needle : [Nat8], startPos : Nat) : ?Nat {
        if (needle.size() == 0) return ?startPos;
        if (needle.size() > haystack.size()) return null;

        let end : Nat = haystack.size() - needle.size() + 1;
        for (i in Nat.range(startPos, end - 1)) {
            var found = true;
            label fInner for (j in Nat.range(0, needle.size())) {
                if (haystack[i + j] != needle[j]) {
                    found := false;
                    break fInner;
                };
            };
            if (found) return ?i;
        };

        return null;
    };
};
