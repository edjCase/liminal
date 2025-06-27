import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Option "mo:new-base/Option";
import Nat "mo:new-base/Nat";
import Buffer "mo:base/Buffer";
import QualityFactor "QualityFactor";

module {

    public type RawMimeType = {
        type_ : Text;
        subType : Text;
        parameters : [(Text, Text)];
    };

    public type MimeType = {
        // Text types
        #text_html : {
            charset : ?Text; // e.g., "utf-8"
            level : ?Text; // e.g., "1"
            version : ?Text; // e.g., "5"
        };
        #text_plain : {
            charset : ?Text; // e.g., "utf-8"
        };
        #text_css : {
            charset : ?Text; // e.g., "utf-8"
        };
        #text_csv : {
            charset : ?Text; // e.g., "utf-8"
            header : ?Bool; // Whether file has header row
        };
        #text_xml : {
            charset : ?Text; // e.g., "utf-8"
        };

        // Application types
        #application_json : {
            charset : ?Text; // e.g., "utf-8"
            schema : ?Text; // Schema identifier
        };
        #application_xml : {
            charset : ?Text; // e.g., "utf-8"
            schema : ?Text; // Schema identifier
        };
        #application_javascript : {
            charset : ?Text; // e.g., "utf-8"
        };
        #application_pdf : {
            version : ?Text; // e.g., "1.7"
        };
        #application_x_www_form_urlencoded : {
            charset : ?Text; // e.g., "utf-8"
        };
        #application_octet_stream : {
            type_ : ?Text; // Optional specific type
        };

        // Image types
        #image_jpeg : {
            quality : ?Nat; // Compression quality (0-100)
        };
        #image_png : {
            compression : ?Nat; // Compression level
        };
        #image_svg_xml : {
            charset : ?Text; // e.g., "utf-8"
        };
        #image_gif : {};
        #image_webp : {
            quality : ?Nat; // Compression quality (0-100)
        };

        // Audio types
        #audio_mpeg : {
            bitrate : ?Nat; // e.g., 128000
        };
        #audio_ogg : {
            codec : ?Text; // e.g., "vorbis"
        };

        // Video types
        #video_mp4 : {
            codec : ?Text; // e.g., "h264"
            bitrate : ?Nat; // e.g., 1000000
        };
        #video_webm : {
            codec : ?Text; // e.g., "vp9"
        };

        // Multipart types
        #multipart_form_data : {
            boundary : Text; // Required boundary parameter
        };
        #multipart_mixed : {
            boundary : Text; // Required boundary parameter
        };

        // Fallback for any other MIME type
        #other : RawMimeType;
    };

    /// Converts a structured MimeType to its raw representation.
    /// The raw representation contains the type, subtype, and parameters as separate fields.
    ///
    /// ```motoko
    /// let mimeType = #text_html({ charset = ?"utf-8"; level = null; version = null });
    /// let raw = MimeType.toRaw(mimeType);
    /// // raw is { type_ = "text"; subType = "html"; parameters = [("charset", "utf-8")] }
    /// ```
    public func toRaw(mimeType : MimeType) : RawMimeType {
        switch (mimeType) {
            case (#text_html(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(3);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };
                switch (params.level) {
                    case (?v) parameters.add(("level", v));
                    case (null) {};
                };
                switch (params.version) {
                    case (?v) parameters.add(("version", v));
                    case (null) {};
                };

                {
                    type_ = "text";
                    subType = "html";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#text_plain(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };

                {
                    type_ = "text";
                    subType = "plain";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#text_css(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };

                {
                    type_ = "text";
                    subType = "css";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#text_csv(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(2);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };
                switch (params.header) {
                    case (?true) parameters.add(("header", "present"));
                    case (?false) parameters.add(("header", "absent"));
                    case (null) {};
                };

                {
                    type_ = "text";
                    subType = "csv";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#text_xml(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };

                {
                    type_ = "text";
                    subType = "xml";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#application_json(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(2);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };
                switch (params.schema) {
                    case (?v) parameters.add(("schema", v));
                    case (null) {};
                };

                {
                    type_ = "application";
                    subType = "json";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#application_xml(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(2);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };
                switch (params.schema) {
                    case (?v) parameters.add(("schema", v));
                    case (null) {};
                };

                {
                    type_ = "application";
                    subType = "xml";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#application_javascript(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };

                {
                    type_ = "application";
                    subType = "javascript";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#application_pdf(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.version) {
                    case (?v) parameters.add(("version", v));
                    case (null) {};
                };

                {
                    type_ = "application";
                    subType = "pdf";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#application_x_www_form_urlencoded(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };

                {
                    type_ = "application";
                    subType = "x-www-form-urlencoded";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#application_octet_stream(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.type_) {
                    case (?v) parameters.add(("type", v));
                    case (null) {};
                };

                {
                    type_ = "application";
                    subType = "octet-stream";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#image_jpeg(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.quality) {
                    case (?v) parameters.add(("quality", Nat.toText(v)));
                    case (null) {};
                };

                {
                    type_ = "image";
                    subType = "jpeg";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#image_png(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.compression) {
                    case (?v) parameters.add(("compression", Nat.toText(v)));
                    case (null) {};
                };

                {
                    type_ = "image";
                    subType = "png";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#image_svg_xml(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.charset) {
                    case (?v) parameters.add(("charset", v));
                    case (null) {};
                };

                {
                    type_ = "image";
                    subType = "svg+xml";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#image_gif(_)) {
                {
                    type_ = "image";
                    subType = "gif";
                    parameters = [];
                };
            };
            case (#image_webp(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.quality) {
                    case (?v) parameters.add(("quality", Nat.toText(v)));
                    case (null) {};
                };

                {
                    type_ = "image";
                    subType = "webp";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#audio_mpeg(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.bitrate) {
                    case (?v) parameters.add(("bitrate", Nat.toText(v)));
                    case (null) {};
                };

                {
                    type_ = "audio";
                    subType = "mpeg";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#audio_ogg(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.codec) {
                    case (?v) parameters.add(("codec", v));
                    case (null) {};
                };

                {
                    type_ = "audio";
                    subType = "ogg";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#video_mp4(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(2);
                switch (params.codec) {
                    case (?v) parameters.add(("codec", v));
                    case (null) {};
                };
                switch (params.bitrate) {
                    case (?v) parameters.add(("bitrate", Nat.toText(v)));
                    case (null) {};
                };

                {
                    type_ = "video";
                    subType = "mp4";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#video_webm(params)) {
                let parameters = Buffer.Buffer<(Text, Text)>(1);
                switch (params.codec) {
                    case (?v) parameters.add(("codec", v));
                    case (null) {};
                };

                {
                    type_ = "video";
                    subType = "webm";
                    parameters = Buffer.toArray(parameters);
                };
            };
            case (#multipart_form_data(params)) {
                {
                    type_ = "multipart";
                    subType = "form-data";
                    parameters = [("boundary", params.boundary)];
                };
            };
            case (#multipart_mixed(params)) {
                {
                    type_ = "multipart";
                    subType = "mixed";
                    parameters = [("boundary", params.boundary)];
                };
            };
            case (#other(raw)) raw;
        };
    };

    /// Converts a raw MIME type representation to a structured MimeType.
    /// Recognizes common MIME types and provides structured access to their parameters.
    /// Falls back to #other for unrecognized types.
    ///
    /// ```motoko
    /// let raw = { type_ = "application"; subType = "json"; parameters = [("charset", "utf-8")] };
    /// let mimeType = MimeType.fromRaw(raw);
    /// // mimeType is #application_json({ charset = ?"utf-8"; schema = null })
    ///
    /// let unknown = { type_ = "custom"; subType = "format"; parameters = [] };
    /// let unknownType = MimeType.fromRaw(unknown);
    /// // unknownType is #other({ type_ = "custom"; subType = "format"; parameters = [] })
    /// ```
    public func fromRaw(raw : RawMimeType) : MimeType {
        // Helper function to find a parameter value
        func getParam(name : Text) : ?Text {
            for ((key, value) in raw.parameters.vals()) {
                if (key == name) {
                    return ?value;
                };
            };
            null;
        };
        let normalizedType = raw.type_ |> Text.trim(_, #char(' ')) |> Text.toLower(_);
        let normalizedSubtype = raw.subType |> Text.trim(_, #char(' ')) |> Text.toLower(_);

        switch (normalizedType, normalizedSubtype) {
            // Text types
            case ("text", "html") {
                #text_html({
                    charset = getParam("charset");
                    level = getParam("level");
                    version = getParam("version");
                });
            };
            case ("text", "plain") {
                #text_plain({
                    charset = getParam("charset");
                });
            };
            case ("text", "css") {
                #text_css({
                    charset = getParam("charset");
                });
            };
            case ("text", "csv") {
                let headerParam = getParam("header");
                let header = switch (headerParam) {
                    case (?v) {
                        if (v == "present") { ?true } else if (v == "absent") {
                            ?false;
                        } else { null };
                    };
                    case (null) { null };
                };

                #text_csv({
                    charset = getParam("charset");
                    header = header;
                });
            };
            case ("text", "xml") {
                #text_xml({
                    charset = getParam("charset");
                });
            };

            // Application types
            case ("application", "json") {
                #application_json({
                    charset = getParam("charset");
                    schema = getParam("schema");
                });
            };
            case ("application", "xml") {
                #application_xml({
                    charset = getParam("charset");
                    schema = getParam("schema");
                });
            };
            case ("application", "javascript") {
                #application_javascript({
                    charset = getParam("charset");
                });
            };
            case ("application", "pdf") {
                #application_pdf({
                    version = getParam("version");
                });
            };
            case ("application", "x-www-form-urlencoded") {
                #application_x_www_form_urlencoded({
                    charset = getParam("charset");
                });
            };
            case ("application", "octet-stream") {
                #application_octet_stream({
                    type_ = getParam("type");
                });
            };

            // Image types
            case ("image", "jpeg") {
                let qualityParam = getParam("quality");
                let quality = switch (qualityParam) {
                    case (?v) {
                        switch (Nat.fromText(v)) {
                            case (?n) { ?n };
                            case (null) { null };
                        };
                    };
                    case (null) { null };
                };

                #image_jpeg({
                    quality = quality;
                });
            };
            case ("image", "png") {
                let compressionParam = getParam("compression");
                let compression = switch (compressionParam) {
                    case (?v) {
                        switch (Nat.fromText(v)) {
                            case (?n) { ?n };
                            case (null) { null };
                        };
                    };
                    case (null) { null };
                };

                #image_png({
                    compression = compression;
                });
            };
            case ("image", "svg+xml") {
                #image_svg_xml({
                    charset = getParam("charset");
                });
            };
            case ("image", "gif") {
                #image_gif({});
            };
            case ("image", "webp") {
                let qualityParam = getParam("quality");
                let quality = switch (qualityParam) {
                    case (?v) {
                        switch (Nat.fromText(v)) {
                            case (?n) { ?n };
                            case (null) { null };
                        };
                    };
                    case (null) { null };
                };

                #image_webp({
                    quality = quality;
                });
            };

            // Audio types
            case ("audio", "mpeg") {
                let bitrateParam = getParam("bitrate");
                let bitrate = switch (bitrateParam) {
                    case (?v) {
                        switch (Nat.fromText(v)) {
                            case (?n) { ?n };
                            case (null) { null };
                        };
                    };
                    case (null) { null };
                };

                #audio_mpeg({
                    bitrate = bitrate;
                });
            };
            case ("audio", "ogg") {
                #audio_ogg({
                    codec = getParam("codec");
                });
            };

            // Video types
            case ("video", "mp4") {
                let bitrateParam = getParam("bitrate");
                let bitrate = switch (bitrateParam) {
                    case (?v) {
                        switch (Nat.fromText(v)) {
                            case (?n) { ?n };
                            case (null) { null };
                        };
                    };
                    case (null) { null };
                };

                #video_mp4({
                    codec = getParam("codec");
                    bitrate = bitrate;
                });
            };
            case ("video", "webm") {
                #video_webm({
                    codec = getParam("codec");
                });
            };

            // Multipart types
            case ("multipart", "form-data") {
                let boundary = Option.get(getParam("boundary"), "");
                #multipart_form_data({
                    boundary = boundary;
                });
            };
            case ("multipart", "mixed") {
                let boundary = Option.get(getParam("boundary"), "");
                #multipart_mixed({
                    boundary = boundary;
                });
            };

            // Default case: anything not recognized
            case (_, _) {
                #other(raw);
            };
        };
    };

    /// Converts a structured MimeType to its string representation.
    /// Optionally includes parameters in the output string.
    ///
    /// ```motoko
    /// let mimeType = #application_json({ charset = ?"utf-8"; schema = null });
    /// let basic = MimeType.toText(mimeType, false);
    /// // basic is "application/json"
    ///
    /// let withParams = MimeType.toText(mimeType, true);
    /// // withParams is "application/json; charset=utf-8"
    /// ```
    public func toText(mimeType : MimeType, includeParameters : Bool) : Text {
        toRaw(mimeType) |> toTextRaw(_, includeParameters);
    };

    /// Converts a raw MIME type to its string representation.
    /// Optionally includes parameters in the output string.
    ///
    /// ```motoko
    /// let raw = { type_ = "text"; subType = "html"; parameters = [("charset", "utf-8")] };
    /// let basic = MimeType.toTextRaw(raw, false);
    /// // basic is "text/html"
    ///
    /// let withParams = MimeType.toTextRaw(raw, true);
    /// // withParams is "text/html; charset=utf-8"
    /// ```
    public func toTextRaw(mimeType : RawMimeType, includeParameters : Bool) : Text {
        let type_ = mimeType.type_ # "/" # mimeType.subType;
        if (not includeParameters) {
            return type_;
        };
        let paramsText = Array.foldLeft(
            mimeType.parameters,
            "",
            func(acc : Text, (key, value) : (Text, Text)) : Text {
                acc # "; " # key # "=" # value;
            },
        );

        return type_ # paramsText;
    };

    /// Parses a MIME type string into a structured MimeType and quality factor.
    /// Supports quality factors (q-values) in Accept headers.
    ///
    /// ```motoko
    /// let result = MimeType.fromText("application/json; charset=utf-8");
    /// // result is ?(#application_json({ charset = ?"utf-8"; schema = null }), 1.0)
    ///
    /// let withQuality = MimeType.fromText("text/html; q=0.8");
    /// // withQuality is ?(#text_html({ charset = null; level = null; version = null }), 0.8)
    ///
    /// let invalid = MimeType.fromText("invalid");
    /// // invalid is null
    /// ```
    public func fromText(text : Text) : ?(MimeType, QualityFactor.QualityFactor) {
        let ?(raw, qualityFactor) = fromTextRaw(text) else return null;
        let mimeType = fromRaw(raw);
        ?(mimeType, qualityFactor);
    };

    /// Parses a MIME type string into a raw MIME type representation and quality factor.
    /// This provides access to the unstructured MIME type data.
    ///
    /// ```motoko
    /// let result = MimeType.fromTextRaw("custom/type; param=value; q=0.5");
    /// // result is ?({ type_ = "custom"; subType = "type"; parameters = [("param", "value")] }, 0.5)
    ///
    /// let invalid = MimeType.fromTextRaw("malformed");
    /// // invalid is null
    /// ```
    public func fromTextRaw(text : Text) : ?(RawMimeType, QualityFactor.QualityFactor) {
        let parts = Text.split(text, #char(';'));
        let ?mediaTypeText = parts.next() else return null;

        let mediaTypeTrimmed = Text.trim(mediaTypeText, #char(' '));
        let mediaTypeParts = Text.split(mediaTypeTrimmed, #char('/'));

        let ?type_ = mediaTypeParts.next() else return null;
        let ?subType = mediaTypeParts.next() else return null;
        let trimmedType = Text.trim(type_, #char(' '));
        let trimmedSubType = Text.trim(subType, #char(' '));

        if (trimmedType == "" or trimmedSubType == "") {
            return null;
        };

        // Parse parameters
        let parameters = Buffer.Buffer<(Text, Text)>(4);
        var qualityFactor : QualityFactor.QualityFactor = 1000; // Default

        label paramLoop for (param in parts) {
            let paramParts = Text.split(param, #char('='));
            let ?paramName = paramParts.next() else return null;
            let ?paramValue = paramParts.next() else return null;

            let trimmedName = Text.trim(paramName, #char(' '));
            let trimmedValue = Text.trim(paramValue, #char(' '));

            if (trimmedName == "q") {
                qualityFactor := Option.get(QualityFactor.fromText(trimmedValue), 1000);
            } else {
                parameters.add((trimmedName, trimmedValue));
            };
        };

        ?(
            {
                type_ = trimmedType;
                subType = trimmedSubType;
                parameters = Buffer.toArray(parameters);
            },
            qualityFactor,
        );
    };
};
