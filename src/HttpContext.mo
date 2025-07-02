import HttpTypes "./HttpTypes";
import Text "mo:new-base/Text";
import TextX "mo:xtended-text/TextX";
import Array "mo:new-base/Array";
import Result "mo:new-base/Result";
import Runtime "mo:new-base/Runtime";
import Iter "mo:new-base/Iter";
import Blob "mo:new-base/Blob";
import IterTools "mo:itertools/Iter";
import HttpMethod "./HttpMethod";
import Json "mo:json";
import JWT "mo:jwt";
import Nat "mo:base/Nat";
import Identity "./Identity";
import Types "./Types";
import ContentNegotiation "./ContentNegotiation";
import Serde "mo:serde";
import Logging "./Logging";
import Session "./Session";
import Path "mo:url-kit/Path";
import UrlKit "mo:url-kit";

module {
    public type SuccessHttpStatusCode = {
        #ok; // 200
        #created; // 201
        #accepted; // 202
        #nonAuthoritativeInformation; // 203
        #noContent; // 204
        #resetContent; // 205
        #partialContent; // 206
        #multiStatus; // 207
        #alreadyReported; // 208
        #imUsed; // 226
    };

    public type SuccessHttpStatusCodeOrCustom = SuccessHttpStatusCode or {
        #custom : Nat;
    };

    public type RedirectionHttpStatusCode = {
        #multipleChoices; // 300
        #movedPermanently; // 301
        #found; // 302
        #seeOther; // 303
        #notModified; // 304
        #useProxy; // 305
        #temporaryRedirect; // 307
        #permanentRedirect; // 308
    };

    public type RedirectionHttpStatusCodeOrCustom = RedirectionHttpStatusCode or {
        #custom : Nat;
    };

    public type ErrorHttpStatusCode = {
        // 4xx Client Errors
        #badRequest; // 400
        #unauthorized; // 401
        #paymentRequired; // 402
        #forbidden; // 403
        #notFound; // 404
        #methodNotAllowed; // 405
        #notAcceptable; // 406
        #proxyAuthenticationRequired; // 407
        #requestTimeout; // 408
        #conflict; // 409
        #gone; // 410
        #lengthRequired; // 411
        #preconditionFailed; // 412
        #payloadTooLarge; // 413
        #uriTooLong; // 414
        #unsupportedMediaType; // 415
        #rangeNotSatisfiable; // 416
        #expectationFailed; // 417
        #imATeapot; // 418
        #misdirectedRequest; // 421
        #unprocessableContent; // 422
        #locked; // 423
        #failedDependency; // 424
        #tooEarly; // 425
        #upgradeRequired; // 426
        #preconditionRequired; // 428
        #tooManyRequests; // 429
        #requestHeaderFieldsTooLarge; // 431
        #unavailableForLegalReasons; // 451

        // 5xx Server Errors
        #internalServerError; // 500
        #notImplemented; // 501
        #badGateway; // 502
        #serviceUnavailable; // 503
        #gatewayTimeout; // 504
        #httpVersionNotSupported; // 505
        #variantAlsoNegotiates; // 506
        #insufficientStorage; // 507
        #loopDetected; // 508
        #notExtended; // 510
        #networkAuthenticationRequired; // 511
    };

    public type ErrorHttpStatusCodeOrCustom = ErrorHttpStatusCode or {
        #custom : Nat;
    };

    public type HttpStatusCode = SuccessHttpStatusCode or RedirectionHttpStatusCode or ErrorHttpStatusCode;

    public type HttpStatusCodeOrCustom = HttpStatusCode or {
        #custom : Nat;
    };

    public type ProblemDetail = {
        // Required fields from RFC 9457
        type_ : Text; // URI reference that identifies the problem type (default "about:blank")

        // Optional standard fields
        title : ?Text; // Short, human-readable summary of the problem type
        detail : ?Text; // Human-readable explanation specific to this occurrence
        instance : ?Text; // URI reference identifying the specific occurrence

        // Extension members - allows for additional problem-type specific fields
        // The RFC allows for extension members specific to the problem type
        // In Motoko we can use a variant type to handle arbitrary extensions
        extensions : [Extension];
    };

    // Type for extension members, which can be of different types
    public type Extension = {
        name : Text;
        value : ExtensionValue;
    };

    public type ExtensionValue = {
        #text : Text;
        #number : Int;
        #boolean : Bool;
        #array : [ExtensionValue];
        #object_ : [(Text, ExtensionValue)];
    };

    public type HttpErrorDataKind = {
        #none;
        #message : Text;
        #rfc9457 : ProblemDetail;
    };

    public type ErrorSerializerResponse = {
        headers : [(Text, Text)];
        body : ?Blob;
    };

    public type ResponseKind = {
        #empty;
        #custom : {
            headers : [(Text, Text)];
            body : Blob;
        };
        #content : CandidValue;
        #text : Text;
        #html : Text;
        #json : Json.Json;
        #error : HttpErrorDataKind;
    };

    public type HttpError = {
        statusCode : Nat;
        data : HttpErrorDataKind;
    };

    public type ErrorSerializer = HttpError -> ErrorSerializerResponse;

    public type CandidNegotiatedContent = {
        body : Blob;
        contentType : Text;
    };

    public type CandidValue = Serde.Candid;

    public type CandidRepresentationNegotiator = (CandidValue, ContentNegotiation.ContentPreference) -> ?CandidNegotiatedContent;

    public type Options = {
        errorSerializer : ErrorSerializer;
        candidRepresentationNegotiator : CandidRepresentationNegotiator;
        logger : Logging.Logger;
    };

    /// HTTP context class that provides access to request data and response building utilities.
    /// This is the main interface for handling HTTP requests in the Liminal framework.
    /// Contains the parsed request, utilities for extracting data, and methods for building responses.
    ///
    /// ```motoko
    /// let context = HttpContext.HttpContext(request, certificateVersion, {
    ///     errorSerializer = App.defaultJsonErrorSerializer;
    ///     candidRepresentationNegotiator = App.defaultCandidRepresentationNegotiator;
    ///     logger = Logging.buildDebugLogger(#info);
    /// });
    ///
    /// // Access request data
    /// let method = context.method;
    /// let path = context.getPath();
    /// let headers = context.getHeader("Content-Type");
    ///
    /// // Build responses
    /// let response = context.buildResponse(#ok, #content(#text("Hello")));
    /// ```
    public class HttpContext(
        r : HttpTypes.UpdateRequest,
        certificateVersion_ : ?Nat16,
        options : Options,
    ) = self {
        public let request : HttpTypes.UpdateRequest = r;
        public let certificateVersion : ?Nat16 = certificateVersion_;
        public let errorSerializer : ErrorSerializer = options.errorSerializer;
        public let candidRepresentationNegotiator : CandidRepresentationNegotiator = options.candidRepresentationNegotiator;
        public var logger = options.logger;
        public var session : ?Session.Session = null;

        var urlCache : ?UrlKit.Url = null;

        public let ?method : ?HttpMethod.HttpMethod = HttpMethod.fromText(request.method) else Runtime.trap("Unsupported HTTP method: " # request.method);

        private var identity : ?Identity.Identity = null;

        /// Logs a message at the specified log level using the context's logger.
        /// Messages are automatically scoped to the current middleware context.
        ///
        /// ```motoko
        /// httpContext.log(#info, "Processing user request");
        /// httpContext.log(#error, "Authentication failed");
        /// ```
        public func log(level : Logging.LogLevel, message : Text) : () {
            logger.log(level, message);
        };

        /// Sets the user identity using a JWT token and validation status.
        /// The identity is extracted from the JWT payload's "sub" field.
        ///
        /// ```motoko
        /// let jwt = JWT.decode(tokenString);
        /// httpContext.setIdentityJWT(jwt, true); // Valid token
        /// ```
        public func setIdentityJWT(jwt : JWT.Token, isValid : Bool) {
            let id = switch (JWT.getPayloadValue(jwt, "sub")) {
                case (?#string(sub)) ?sub;
                case (_) null;
            };
            identity := ?{
                kind = #jwt(jwt);
                getId = func() : ?Text = id;
                isAuthenticated = func() : Bool = isValid;
            };
        };

        /// Sets the user identity directly with a custom Identity object.
        /// Use this when authentication is handled outside of JWT tokens.
        ///
        /// ```motoko
        /// let customIdentity = {
        ///     kind = #custom("session");
        ///     getId = func() : ?Text = ?"user123";
        ///     isAuthenticated = func() : Bool = true;
        /// };
        /// httpContext.setIdentity(customIdentity);
        /// ```
        public func setIdentity(identity_ : Identity.Identity) {
            identity := ?identity_;
        };

        /// Returns the current user identity if set, null otherwise.
        /// Check the identity's isAuthenticated() method to verify authentication status.
        ///
        /// ```motoko
        /// switch (httpContext.getIdentity()) {
        ///     case (?identity) {
        ///         if (identity.isAuthenticated()) {
        ///             // User is authenticated
        ///         };
        ///     };
        ///     case (null) {
        ///         // No identity set
        ///     };
        /// };
        /// ```
        public func getIdentity() : ?Identity.Identity {
            return identity;
        };

        /// Returns the parsed URL data including path, query parameters, and fragments.
        /// The URL is parsed and cached on first access for performance.
        ///
        /// ```motoko
        /// let url = httpContext.getUrlData();
        /// let path = url.path;
        /// let params = url.queryParams;
        /// ```
        public func getUrlData() : UrlKit.Url {
            switch (urlCache) {
                case (?v) v;
                case (null) {
                    // TODO is there a better way to handle this than trap?
                    let parsedUrl = switch (UrlKit.fromText(request.url)) {
                        case (#ok(v)) v;
                        case (#err(err)) Runtime.trap("Invalid URL '" # request.url # "'. Error: " # err);
                    };
                    urlCache := ?UrlKit.normalize(parsedUrl);
                    parsedUrl;
                };
            };
        };

        /// Returns the parsed path component of the request URL.
        /// Provides structured access to the URL path for routing and navigation.
        ///
        /// ```motoko
        /// let path = httpContext.getPath();
        /// // For URL "/users/123", path contains parsed segments
        /// ```
        public func getPath() : Path.Path {
            let url = getUrlData();
            url.path;
        };

        /// Returns all query parameters as key-value pairs.
        /// Extracts parameters from the URL query string for processing.
        ///
        /// ```motoko
        /// let params = httpContext.getQueryParams();
        /// // For URL "/search?q=motoko&sort=date", returns [("q", "motoko"), ("sort", "date")]
        /// ```
        public func getQueryParams() : [(Text, Text)] {
            let url = getUrlData();
            url.queryParams;
        };

        /// Returns the value of a specific query parameter, or null if not found.
        /// Parameter lookup is case-insensitive.
        ///
        /// ```motoko
        /// let searchQuery = httpContext.getQueryParam("q");
        /// // For URL "/search?q=motoko", returns ?"motoko"
        /// ```
        public func getQueryParam(key : Text) : ?Text {
            let url = getUrlData();

            // TODO optimize this
            let ?queryKeyValue = url.queryParams.vals()
            |> IterTools.find(
                _,
                func((k, _) : (Text, Text)) : Bool = TextX.equalIgnoreCase(k, key),
            ) else return null;
            ?queryKeyValue.1;
        };

        /// Returns the value of a specific HTTP header, or null if not found.
        /// Header lookup is case-insensitive following HTTP standards.
        ///
        /// ```motoko
        /// let contentType = httpContext.getHeader("Content-Type");
        /// let userAgent = httpContext.getHeader("User-Agent");
        /// ```
        public func getHeader(key : Text) : ?Text {
            let ?kv = Array.find(
                request.headers,
                func(kv : (Text, Text)) : Bool = TextX.equalIgnoreCase(kv.0, key),
            ) else return null;
            ?kv.1;
        };

        /// Returns the value of a specific cookie, or null if not found.
        /// Parses the Cookie header and extracts individual cookie values.
        ///
        /// ```motoko
        /// let sessionId = httpContext.getCookie("session_id");
        /// let preferences = httpContext.getCookie("user_prefs");
        /// ```
        public func getCookie(key : Text) : ?Text {
            // Get the Cookie header
            let ?cookieHeader = getHeader("Cookie") else return null;

            // Split the cookie string by semicolons
            let cookies = Text.split(cookieHeader, #text(";"));

            // Find the matching cookie
            label f for (cookie in cookies) {
                let cookieTrimmed = Text.trim(cookie, #text(" "));
                let parts = Text.split(cookieTrimmed, #text("=")) |> Iter.toArray(_);

                if (parts.size() >= 2) {
                    let cookieKey = parts[0];

                    if (not TextX.equalIgnoreCase(cookieKey, key)) {
                        continue f;
                    };
                    let partsIter = parts.vals();
                    // Skip the first part (the key)
                    ignore partsIter.next();

                    // Handle values that might contain "=" by rejoining the remaining parts
                    return ?Text.join("=", partsIter);

                };
            };

            return null;
        };

        /// Returns the client's content type preferences based on the Accept header.
        /// Used for content negotiation to determine response format.
        ///
        /// ```motoko
        /// let preference = httpContext.getContentPreference();
        /// // Check if client accepts JSON: preference.requestedTypes
        /// ```
        public func getContentPreference() : ContentNegotiation.ContentPreference {
            let ?acceptHeader = getHeader("Accept") else return {
                requestedTypes = [];
                disallowedTypes = [];
            };
            ContentNegotiation.parseContentTypes(acceptHeader);
        };

        /// Parses the request body as JSON and returns the parsed JSON object.
        /// Returns an error if the body is not valid UTF-8 or valid JSON.
        ///
        /// ```motoko
        /// switch (httpContext.parseRawJsonBody()) {
        ///     case (#ok(json)) {
        ///         // Process JSON object
        ///     };
        ///     case (#err(error)) {
        ///         // Handle parsing error
        ///     };
        /// };
        /// ```
        public func parseRawJsonBody() : Result.Result<Json.Json, Text> {
            let ?jsonText = Text.decodeUtf8(request.body) else return #err("Body is not valid UTF-8");
            switch (Json.parse(jsonText)) {
                case (#ok(json)) #ok(json);
                case (#err(e)) #err("Failed to parse JSON: " # debug_show (e));
            };
        };

        /// Parses the request body as JSON and applies a transformation function.
        /// Combines JSON parsing with custom deserialization in one step.
        ///
        /// ```motoko
        /// let parseUser = func(json : Json.Json) : Result.Result<User, Text> {
        ///     // Custom parsing logic
        /// };
        /// switch (httpContext.parseJsonBody(parseUser)) {
        ///     case (#ok(user)) {
        ///         // Use parsed user object
        ///     };
        ///     case (#err(error)) {
        ///         // Handle parsing/transformation error
        ///     };
        /// };
        /// ```
        public func parseJsonBody<T>(f : Json.Json -> Result.Result<T, Text>) : Result.Result<T, Text> {
            switch (parseRawJsonBody()) {
                case (#ok(json)) f(json);
                case (#err(e)) #err(e);
            };
        };

        /// Builds an HTTP response with the specified status code and content.
        /// Handles content negotiation and serialization automatically.
        ///
        /// ```motoko
        /// // Return JSON response
        /// let response = httpContext.buildResponse(#ok, #content(#json(userJson)));
        ///
        /// // Return custom response
        /// let customResponse = httpContext.buildResponse(#created, #custom({
        ///     headers = [("Location", "/users/123")];
        ///     body = Text.encodeUtf8("User created");
        /// }));
        /// ```
        public func buildResponse(statusCode : HttpStatusCodeOrCustom, value : ResponseKind) : Types.HttpResponse {
            let statusCodeNat = getStatusCodeNat(statusCode);
            switch (value) {
                case (#custom(custom)) ({
                    statusCode = statusCodeNat;
                    headers = custom.headers;
                    body = ?custom.body;
                    streamingStrategy = null;
                });
                case (#content(candid)) {
                    let contentPreference = getContentPreference();
                    let ?{ body; contentType } = candidRepresentationNegotiator(candid, contentPreference) else {
                        return buildResponse(
                            #unsupportedMediaType,
                            #error(#message("Unsupported content types: " # debug_show getHeader("Accept"))),
                        );
                    };
                    {
                        statusCode = statusCodeNat;
                        headers = [
                            ("content-type", contentType),
                            ("content-length", Nat.toText(Blob.size(body))),
                        ];
                        body = ?body;
                        streamingStrategy = null;
                    };
                };
                case (#text(text)) ({
                    statusCode = statusCodeNat;
                    headers = [("content-type", "text/plain")];
                    body = ?Text.encodeUtf8(text);
                    streamingStrategy = null;
                });
                case (#json(json)) {
                    let jsonText = Json.stringify(json, null);
                    let jsonBytes = Text.encodeUtf8(jsonText);
                    let contentLength = Nat.toText(Blob.size(jsonBytes));
                    {
                        statusCode = statusCodeNat;
                        headers = [
                            ("content-type", "application/json"),
                            ("content-length", contentLength),
                        ];
                        body = ?jsonBytes;
                        streamingStrategy = null;
                    };
                };
                case (#html(text)) ({
                    statusCode = statusCodeNat;
                    headers = [("content-type", "text/html")];
                    body = ?Text.encodeUtf8(text);
                    streamingStrategy = null;
                });
                case (#empty) ({
                    statusCode = statusCodeNat;
                    headers = [];
                    body = null;
                    streamingStrategy = null;
                });
                case (#error(error)) {
                    let { headers; body } = options.errorSerializer({
                        statusCode = statusCodeNat;
                        data = error;
                    });
                    {
                        statusCode = statusCodeNat;
                        headers = headers;
                        body = body;
                        streamingStrategy = null;
                    };
                };
            };
        };

        /// Builds an HTTP redirect response to the specified URL.
        /// Supports both temporary (307) and permanent (308) redirects.
        ///
        /// ```motoko
        /// // Temporary redirect
        /// let response = httpContext.buildRedirectResponse("/login", false);
        ///
        /// // Permanent redirect
        /// let response = httpContext.buildRedirectResponse("/new-path", true);
        /// ```
        public func buildRedirectResponse(url : Text, permanent : Bool) : Types.HttpResponse {
            {
                statusCode = if (permanent) 308 else 307;
                headers = [
                    ("location", url),
                ];
                body = null; // No body for redirects
                streamingStrategy = null;
            };
        };

    };

    /// Converts an HTTP status code enum to its numeric representation.
    /// Supports both standard status codes and custom numeric codes.
    ///
    /// ```motoko
    /// let code = HttpContext.getStatusCodeNat(#ok); // Returns 200
    /// let customCode = HttpContext.getStatusCodeNat(#custom(418)); // Returns 418
    /// ```
    public func getStatusCodeNat(code : HttpStatusCodeOrCustom) : Nat = switch (code) {
        case (#ok) 200;
        case (#created) 201;
        case (#accepted) 202;
        case (#nonAuthoritativeInformation) 203;
        case (#noContent) 204;
        case (#resetContent) 205;
        case (#partialContent) 206;
        case (#multiStatus) 207;
        case (#alreadyReported) 208;
        case (#imUsed) 226;

        case (#multipleChoices) 300;
        case (#movedPermanently) 301;
        case (#found) 302;
        case (#seeOther) 303;
        case (#notModified) 304;
        case (#useProxy) 305;
        case (#temporaryRedirect) 307;
        case (#permanentRedirect) 308;

        case (#badRequest) 400;
        case (#unauthorized) 401;
        case (#paymentRequired) 402;
        case (#forbidden) 403;
        case (#notFound) 404;
        case (#methodNotAllowed) 405;
        case (#notAcceptable) 406;
        case (#proxyAuthenticationRequired) 407;
        case (#requestTimeout) 408;
        case (#conflict) 409;
        case (#gone) 410;
        case (#lengthRequired) 411;
        case (#preconditionFailed) 412;
        case (#payloadTooLarge) 413;
        case (#uriTooLong) 414;
        case (#unsupportedMediaType) 415;
        case (#rangeNotSatisfiable) 416;
        case (#expectationFailed) 417;
        case (#imATeapot) 418;
        case (#misdirectedRequest) 421;
        case (#unprocessableContent) 422;
        case (#locked) 423;
        case (#failedDependency) 424;
        case (#tooEarly) 425;
        case (#upgradeRequired) 426;
        case (#preconditionRequired) 428;
        case (#tooManyRequests) 429;
        case (#requestHeaderFieldsTooLarge) 431;
        case (#unavailableForLegalReasons) 451;

        case (#internalServerError) 500;
        case (#notImplemented) 501;
        case (#badGateway) 502;
        case (#serviceUnavailable) 503;
        case (#gatewayTimeout) 504;
        case (#httpVersionNotSupported) 505;
        case (#variantAlsoNegotiates) 506;
        case (#insufficientStorage) 507;
        case (#loopDetected) 508;
        case (#notExtended) 510;
        case (#networkAuthenticationRequired) 511;

        case (#custom(code)) code;
    };

    /// Returns the human-readable label for an HTTP status code.
    /// Provides standard descriptions for common HTTP status codes.
    ///
    /// ```motoko
    /// let label = HttpContext.getStatusCodeLabel(404); // Returns "Not Found"
    /// let successLabel = HttpContext.getStatusCodeLabel(200); // Returns "OK"
    /// ```
    public func getStatusCodeLabel(code : Nat) : Text = switch (code) {
        // 2xx Success
        case (200) "OK";
        case (201) "Created";
        case (202) "Accepted";
        case (203) "Non-Authoritative Information";
        case (204) "No Content";
        case (205) "Reset Content";
        case (206) "Partial Content";
        case (207) "Multi-Status";
        case (208) "Already Reported";
        case (226) "IM Used";

        // 3xx Redirection
        case (300) "Multiple Choices";
        case (301) "Moved Permanently";
        case (302) "Found";
        case (303) "See Other";
        case (304) "Not Modified";
        case (305) "Use Proxy";
        case (307) "Temporary Redirect";
        case (308) "Permanent Redirect";

        // 4xx Client Errors
        case (400) "Bad Request";
        case (401) "Unauthorized";
        case (402) "Payment Required";
        case (403) "Forbidden";
        case (404) "Not Found";
        case (405) "Method Not Allowed";
        case (406) "Not Acceptable";
        case (407) "Proxy Authentication Required";
        case (408) "Request Timeout";
        case (409) "Conflict";
        case (410) "Gone";
        case (411) "Length Required";
        case (412) "Precondition Failed";
        case (413) "Payload Too Large";
        case (414) "URI Too Long";
        case (415) "Unsupported Media Type";
        case (416) "Range Not Satisfiable";
        case (417) "Expectation Failed";
        case (418) "I'm a teapot";
        case (421) "Misdirected Request";
        case (422) "Unprocessable Entity";
        case (423) "Locked";
        case (424) "Failed Dependency";
        case (425) "Too Early";
        case (426) "Upgrade Required";
        case (428) "Precondition Required";
        case (429) "Too Many Requests";
        case (431) "Request Header Fields Too Large";
        case (451) "Unavailable For Legal Reasons";

        // 5xx Server Errors
        case (500) "Internal Server Error";
        case (501) "Not Implemented";
        case (502) "Bad Gateway";
        case (503) "Service Unavailable";
        case (504) "Gateway Timeout";
        case (505) "HTTP Version Not Supported";
        case (506) "Variant Also Negotiates";
        case (507) "Insufficient Storage";
        case (508) "Loop Detected";
        case (510) "Not Extended";
        case (511) "Network Authentication Required";

        case (_) "Unknown Status Code: " # Nat.toText(code); // Default case for unknown status codes
    };

};
