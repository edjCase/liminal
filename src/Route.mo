import HttpContext "./HttpContext";
import Types "./Types";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Result "mo:new-base/Result";
import List "mo:new-base/List";
import TextX "mo:xtended-text/TextX";
import Identity "./Identity";
import RouteContext "RouteContext";

module {

    public type HttpResponse = Types.HttpResponse;

    public type Route = {
        pathSegments : [PathSegment];
        method : RouteMethod;
        handler : RouteHandler;
        identityRequirement : ?Identity.IdentityRequirement;
    };

    public type ResponseKind = HttpContext.ResponseKind;

    public type ValidationError = {
        field : Text;
        message : Text;
    };

    public type RouteHandler = RouteContext.RouteHandler;

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

    /// Parses a URL path string into structured path segments.
    /// Supports text segments, parameters (prefixed with :), and wildcards (* and **).
    ///
    /// ```motoko
    /// let result1 = Route.parsePathSegments("/users/:id/posts");
    /// // result1 is #ok([#text("users"), #param("id"), #text("posts")])
    ///
    /// let result2 = Route.parsePathSegments("/api/*/files/**");
    /// // result2 is #ok([#text("api"), #wildcard(#single), #text("files"), #wildcard(#multi)])
    ///
    /// let invalid = Route.parsePathSegments("/users/:id:");
    /// // invalid is #err("Invalid parameter syntax")
    /// ```
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

    /// Converts path segments back to a text representation.
    /// Parameters are wrapped in braces for clarity, wildcards use * notation.
    ///
    /// ```motoko
    /// let segments = [#text("users"), #param("id"), #wildcard(#single)];
    /// let path = Route.pathSegmentsToText(segments);
    /// // path is "users/{id}/*"
    /// ```
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

    /// Compares two path segments for equality.
    /// Considers parameter names and wildcard types when determining equality.
    ///
    /// ```motoko
    /// let equal1 = Route.pathSegmentEqual(#text("users"), #text("users"));
    /// // equal1 is true
    ///
    /// let equal2 = Route.pathSegmentEqual(#param("id"), #param("userId"));
    /// // equal2 is false (different parameter names)
    ///
    /// let equal3 = Route.pathSegmentEqual(#wildcard(#single), #wildcard(#single));
    /// // equal3 is true
    /// ```
    public func pathSegmentEqual(s1 : PathSegment, s2 : PathSegment) : Bool {
        switch (s1, s2) {
            case ((#text(t1), #text(t2))) t1 == t2;
            case ((#param(p1), #param(p2))) p1 == p2;
            case (_, _) false;
        };
    };
};
