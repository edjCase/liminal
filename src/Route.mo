import HttpContext "./HttpContext";
import Types "./Types";
import HttpMethod "./HttpMethod";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import TextX "mo:xtended-text/TextX";
import Json "mo:json";

module {

    public class RouteContext(
        httpContext_ : HttpContext.HttpContext,
        route_ : Route,
        params_ : [(Text, Text)],
    ) = self {
        public let httpContext : HttpContext.HttpContext = httpContext_;
        public let route : Route = route_;
        public let params : [(Text, Text)] = params_;

        public func getRouteParam(key : Text) : Text {
            let ?param = getRouteParamOrNull(key) else {
                let path = pathSegmentsToText(route.pathSegments);
                Debug.trap("Parameter '" # key # "' for route '" # path # "' was not parsed correctly");
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

    };

    public type ResponseBody = {
        #raw : Blob;
        #json : Json.Json;
    };

    public type ValidationError = {
        field : Text;
        message : Text;
    };

    public type RouteResult = {
        #raw : Types.HttpResponse;

        // 2xx: Success
        #ok : ResponseBody;
        #created : ResponseBody;
        #noContent;

        // 4xx: Client Errors
        #badRequest : Text;
        #unauthorized : Text;
        #forbidden : Text;
        #notFound : ?Text;
        #methodNotAllowed : [HttpMethod.HttpMethod]; // Allowed methods
        #unprocessableEntity : Text;

        // 5xx: Server Errors
        #internalServerError : Text;
        #serviceUnavailable : Text;
    };

    public type RouteHandler = (RouteContext) -> RouteResult;

    public type PathSegment = {
        #text : Text;
        #param : Text;
    };

    public type Route = {
        pathSegments : [PathSegment];
        methods : [HttpMethod.HttpMethod];
        handler : RouteHandler;
    };

    public func parsePathSegments(path : Text) : Result.Result<[PathSegment], Text> {
        let pathSegments = path
        |> Text.split(_, #char('/'))
        |> Iter.map(
            _,
            func(segment : Text) : PathSegment {
                if (Text.startsWith(segment, #char('{')) and Text.endsWith(segment, #char('}'))) {
                    // Parameter segment: extract name between curly braces
                    let paramName = TextX.slice(segment, 1, segment.size() - 2);
                    return #param(paramName);
                };
                // Regular text segment
                #text(segment);
            },
        )
        |> Iter.toArray(_);

        #ok(pathSegments);
    };

    public func pathSegmentsToText(segments : [PathSegment]) : Text {
        let path = segments.vals()
        |> Iter.map(
            _,
            func(segment : PathSegment) : Text {
                switch (segment) {
                    case (#text(text)) text;
                    case (#param(param)) "{" # param # "}";
                };
            },
        )
        |> Text.join("/", _);
        "/" # path;
    };
};
