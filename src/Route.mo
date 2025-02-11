import HttpContext "./HttpContext";
import Types "./Types";
import HttpMethod "./HttpMethod";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import TextX "mo:xtended-text/TextX";

module {

    public class RouteContext(route_ : Route, params_ : [(Text, Text)]) = self {
        public let route : Route = route_;
        public let params : [(Text, Text)] = params_;

        public func getParam(key : Text) : ?Text {
            let ?kv = Array.find(
                params,
                func(kv : (Text, Text)) : Bool = TextX.equalIgnoreCase(kv.0, key),
            ) else return null;
            ?kv.1;
        };

        public func run(httpContext : HttpContext.HttpContext) : Types.HttpResponse {
            route.handler(httpContext, self);
        };
    };

    public type RouteHandler = (HttpContext.HttpContext, RouteContext) -> Types.HttpResponse;

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
};
