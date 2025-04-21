import HttpTypes "./HttpTypes";
import Text "mo:new-base/Text";
import TextX "mo:xtended-text/TextX";
import Array "mo:new-base/Array";
import Result "mo:new-base/Result";
import Runtime "mo:new-base/Runtime";
import Iter "mo:new-base/Iter";
import Blob "mo:new-base/Blob";
import IterTools "mo:itertools/Iter";
import Parser "./Parser";
import HttpMethod "./HttpMethod";
import Json "mo:json";
import Path "Path";
import JWT "mo:jwt";
import Nat "mo:base/Nat";
import Identity "Identity";
import Types "./Types";

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

    public type ResponseBody = {
        #empty;
        #custom : {
            headers : [(Text, Text)];
            body : Blob;
        };
        #json : Json.Json;
        #text : Text;
    };

    public type HttpError = {
        statusCode : Nat;
        data : HttpErrorDataKind;
    };

    public type Options = {
        errorSerializer : HttpError -> ErrorSerializerResponse;
    };

    public class HttpContext(
        r : HttpTypes.UpdateRequest,
        certificate_version : ?Nat16,
        options : Options,
    ) = self {
        public let request : HttpTypes.UpdateRequest = r;
        public let certificateVersion : ?Nat16 = certificate_version;

        var pathQueryCache : ?(Text, [(Text, Text)]) = null;

        public let ?method : ?HttpMethod.HttpMethod = HttpMethod.fromText(request.method) else Runtime.trap("Unsupported HTTP method: " # request.method);

        private var identity : ?Identity.Identity = null;

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

        public func getIdentity() : ?Identity.Identity {
            return identity;
        };

        public func getPath() : Path.Path {
            Path.parse(getPathQueryInternal().0); // TODO cache or not?
        };

        public func getQueryParams() : [(Text, Text)] {
            getPathQueryInternal().1;
        };

        private func getPathQueryInternal() : (Text, [(Text, Text)]) {
            switch (pathQueryCache) {
                case (?v) v;
                case (null) {
                    let v = Parser.parseUrl(request.url);
                    pathQueryCache := ?v;
                    v;
                };
            };
        };

        public func getQueryParam(key : Text) : ?Text {
            // TODO optimize this
            let ?queryKeyValue = getQueryParams().vals()
            |> IterTools.find(
                _,
                func((k, _) : (Text, Text)) : Bool = TextX.equalIgnoreCase(k, key),
            ) else return null;
            ?queryKeyValue.1;
        };

        public func getHeader(key : Text) : ?Text {
            let ?kv = Array.find(
                request.headers,
                func(kv : (Text, Text)) : Bool = TextX.equalIgnoreCase(kv.0, key),
            ) else return null;
            ?kv.1;
        };

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

        public func parseRawJsonBody() : Result.Result<Json.Json, Text> {
            let ?jsonText = Text.decodeUtf8(request.body) else return #err("Body is not valid UTF-8");
            switch (Json.parse(jsonText)) {
                case (#ok(json)) #ok(json);
                case (#err(e)) #err("Failed to parse JSON: " # debug_show (e));
            };
        };

        public func parseJsonBody<T>(f : Json.Json -> Result.Result<T, Text>) : Result.Result<T, Text> {
            switch (parseRawJsonBody()) {
                case (#ok(json)) f(json);
                case (#err(e)) #err(e);
            };
        };

        public func buildResponse<T>(statusCode : HttpStatusCodeOrCustom, value : ResponseBody) : Types.HttpResponse {
            let statusCodeNat = getStatusCodeNat(statusCode);
            serializeReponseBody(statusCodeNat, value);
        };

        public func buildErrorResponse(statusCode : ErrorHttpStatusCodeOrCustom, data : HttpErrorDataKind) : Types.HttpResponse {
            let statusCodeNat = getStatusCodeNat(statusCode);
            let { headers; body } = options.errorSerializer({
                statusCode = statusCodeNat;
                data = data;
            });
            {
                statusCode = statusCodeNat;
                headers = headers;
                body = body;
            };
        };
    };

    private func serializeReponseBody(statusCode : Nat, body : ResponseBody) : Types.HttpResponse {
        switch (body) {
            case (#custom(custom)) ({
                statusCode = statusCode;
                headers = custom.headers;
                body = ?custom.body;
            });
            case (#json(json)) ({
                statusCode = statusCode;
                headers = [("content-type", "application/json")];
                body = Json.stringify(json, null) |> ?Text.encodeUtf8(_);
            });
            case (#text(text)) ({
                statusCode = statusCode;
                headers = [("content-type", "text/plain")];
                body = ?Text.encodeUtf8(text);
            });
            case (#empty) ({
                statusCode = statusCode;
                headers = [];
                body = null;
            });
        };
    };

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

    public func getStatusCodeLabel(code : Nat) : Text = switch (code) {
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

        case (_) "Unknown Error"; // Default case for unknown status codes
    };

};
