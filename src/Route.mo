import HttpContext "./HttpContext";
import Types "./Types";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Result "mo:new-base/Result";
import Runtime "mo:new-base/Runtime";
import List "mo:new-base/List";
import TextX "mo:xtended-text/TextX";
import Json "mo:json";
import Identity "./Identity";

module {

    public type HttpResponse = Types.HttpResponse;

    public type HttpErrorDataKind = HttpContext.HttpErrorDataKind;

    public type HttpStatusCode = HttpContext.HttpStatusCode;
    public type HttpStatusCodeOrCustom = HttpContext.HttpStatusCodeOrCustom;
    public type SuccessHttpStatusCode = HttpContext.SuccessHttpStatusCode;
    public type SuccessHttpStatusCodeOrCustom = HttpContext.SuccessHttpStatusCodeOrCustom;
    public type ErrorHttpStatusCode = HttpContext.ErrorHttpStatusCode;
    public type ErrorHttpStatusCodeOrCustom = HttpContext.ErrorHttpStatusCodeOrCustom;
    public type RedirectionHttpStatusCode = HttpContext.RedirectionHttpStatusCode;
    public type RedirectionHttpStatusCodeOrCustom = HttpContext.RedirectionHttpStatusCodeOrCustom;

    public type Route = {
        pathSegments : [PathSegment];
        method : RouteMethod;
        handler : RouteHandler;
        identityRequirement : ?Identity.IdentityRequirement;
    };

    public class RouteContext(
        httpContext_ : HttpContext.HttpContext,
        handler_ : RouteHandler,
        params_ : [(Text, Text)],
    ) = self {
        public let httpContext : HttpContext.HttpContext = httpContext_;
        public let handler : RouteHandler = handler_;
        public let params : [(Text, Text)] = params_;

        public func getIdentity() : ?Identity.Identity = httpContext.getIdentity();

        public func getRouteParam(key : Text) : Text {
            let ?param = getRouteParamOrNull(key) else {
                Runtime.trap("Parameter '" # key # "' for route was not parsed");
            };
            param;
        };

        public func getRouteParamOrNull(key : Text) : ?Text {
            let ?kv = Array.find(
                params,
                func(kv : (Text, Text)) : Bool = TextX.equalIgnoreCase(kv.0, key),
            ) else return null;
            ?kv.1;
        };

        public func getQueryParams() : [(Text, Text)] = httpContext.getQueryParams();

        public func getQueryParam(key : Text) : ?Text = httpContext.getQueryParam(key);

        public func getHeader(key : Text) : ?Text = httpContext.getHeader(key);

        public func parseRawJsonBody() : Result.Result<Json.Json, Text> = httpContext.parseRawJsonBody();

        public func parseJsonBody<T>(f : Json.Json -> Result.Result<T, Text>) : Result.Result<T, Text> = httpContext.parseJsonBody(f);

        public func buildResponse(statusCode : HttpStatusCodeOrCustom, body : ResponseKind) : HttpResponse {
            httpContext.buildResponse(statusCode, body);
        };
    };

    public type ResponseKind = HttpContext.ResponseKind;

    public type ValidationError = {
        field : Text;
        message : Text;
    };

    public type RouteHandler = {
        #syncQuery : RouteContext -> HttpResponse;
        #syncUpdate : <system>(RouteContext) -> HttpResponse;
        #asyncUpdate : RouteContext -> async* HttpResponse;
    };

    public type PathSegment = {
        #text : Text;
        #param : Text;
        #wildcard : {
            #single;
            #multi;
        };
    };

    public type RouteMethod = {
        #get;
        #post;
        #put;
        #patch;
        #delete;
    };

    public func parsePathSegments(path : Text) : Result.Result<[PathSegment], Text> {
        let textSegments = path
        |> Text.trim(_, #char('/'))
        |> Text.split(_, #char('/'))
        |> Iter.map(_, func(segment : Text) : Text = Text.trim(segment, #char(' ')));

        let pathSegments = List.empty<PathSegment>();
        for (segment in textSegments) {
            if (segment == "") {
                return #err("Empty path segment found");
            };
            if (segment == "*") {
                // Wildcard segment: single wildcard
                List.add(pathSegments, #wildcard(#single));
            } else if (segment == "**") {
                // Wildcard segment: multi wildcard
                List.add(pathSegments, #wildcard(#multi));
            } else if (Text.startsWith(segment, #text("**"))) {
                return #err("Invalid wildcard segment: " # segment);
            } else if (Text.startsWith(segment, #char('{'))) {
                if (not Text.endsWith(segment, #char('}'))) {
                    return #err("Parameter segment must end with a '}'");
                };
                // Parameter segment: extract name between curly braces
                let paramName = TextX.slice(segment, 1, segment.size() - 2);
                if (TextX.isEmptyOrWhitespace(paramName)) {
                    return #err("Parameter name cannot be empty");
                };
                if (Text.contains(paramName, #char('{')) or Text.contains(paramName, #char('}'))) {
                    return #err("Parameter name cannot contain '{' or '}'");
                };
                List.add(pathSegments, #param(paramName));
            } else {
                // Regular text segment
                List.add(pathSegments, #text(segment));
            };
        };

        #ok(List.toArray(pathSegments));
    };

    public func pathSegmentsToText(segments : [PathSegment]) : Text {
        let path = segments.vals()
        |> Iter.map(
            _,
            func(segment : PathSegment) : Text {
                switch (segment) {
                    case (#text(text)) text;
                    case (#param(param)) "{" # param # "}";
                    case (#wildcard(#single)) "*";
                    case (#wildcard(#multi)) "**";
                };
            },
        )
        |> Text.join("/", _);
        "/" # path;
    };

    public func pathSegmentEqual(s1 : PathSegment, s2 : PathSegment) : Bool {
        switch (s1, s2) {
            case ((#text(t1), #text(t2))) t1 == t2;
            case ((#param(p1), #param(p2))) p1 == p2;
            case (_, _) false;
        };
    };
};
