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
import Identity "Identity";
import Types "./Types";

module {
    public type ErrorStatusCode = {
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

        // Custom/Additional
        #custom : Nat; // For any non-standard error code
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
        #message : Text;
        #rfc9457 : ProblemDetail;
    };

    public type HttpError = {
        statusCode : ErrorStatusCode;
        data : HttpErrorDataKind;
    };

    public type ErrorSerializerResponse = {
        headers : [(Text, Text)];
        body : ?Blob;
    };

    public type Options = {
        errorSerializer : HttpError -> ErrorSerializerResponse;
    };

    public class HttpContext(r : HttpTypes.UpdateRequest, options : Options) = self {
        public let request : HttpTypes.UpdateRequest = r;

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

        public func buildErrorResponse(error : HttpError) : Types.HttpResponse {
            let { headers; body } = options.errorSerializer(error);
            let statusCode = getStatusCodeNat(error.statusCode);
            {
                statusCode = statusCode;
                headers = headers;
                body = body;
            };
        };
    };

    public func getStatusCodeNat(code : ErrorStatusCode) : Nat {
        switch (code) {
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
    };

};
