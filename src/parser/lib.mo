import Types "../types";
import Text "mo:base/Text";
import TextX "mo:xtended-text/TextX";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import IterTools "mo:itertools/Iter";
import HttpTypes "../http-types";

module Module {

    public class HttpContext(r : HttpTypes.UpdateRequest) = self {
        public let request : HttpTypes.UpdateRequest = r;

        var pathQueryCache : ?(Text, [(Text, Text)]) = null;

        public let method : Types.HttpMethod = parseHttpMethod(request.method);

        public func getPath() : Text {
            getPathQueryInternal().0;
        };

        public func getQueryParams() : [(Text, Text)] {
            getPathQueryInternal().1;
        };

        private func getPathQueryInternal() : (Text, [(Text, Text)]) {
            switch (pathQueryCache) {
                case (?v) v;
                case (null) {
                    let v = Module.parseUrl(request.url);
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
    };

    public func parseHttpMethod(method : Text) : Types.HttpMethod {
        switch (TextX.toLower(method)) {
            case ("get") #get;
            case ("post") #post;
            case (_) Debug.trap("Unsupported HTTP method: " # method);
        };
    };

    public func parseUrl(url : Text) : (Text, [(Text, Text)]) {
        let urlParts = Text.split(url, #char('?'));

        let ?path = urlParts.next() else return ("", []);

        let ?queryString = urlParts.next() else return (path, []); // TODO what if there is more than one '?' in the URL?

        let queryParams = queryString
        |> Text.split(_, #char('&'))
        |> IterTools.mapFilter<Text, (Text, Text)>(
            _,
            func(param : Text) : ?(Text, Text) {
                let parts = Text.split(param, #char('='));
                let ?key = parts.next() else return null;
                let ?value = parts.next() else return ?(key, ""); // TODO what if there is more than one '=' in the query string?
                return ?(key, value);
            },
        )
        |> Iter.toArray(_);

        (path, queryParams);
    };
};
