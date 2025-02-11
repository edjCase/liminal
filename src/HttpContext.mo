import HttpTypes "./HttpTypes";
import Text "mo:base/Text";
import TextX "mo:xtended-text/TextX";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import IterTools "mo:itertools/Iter";
import Parser "./Parser";
import HttpMethod "./HttpMethod";
import Json "mo:json";

module {

    public class HttpContext(r : HttpTypes.UpdateRequest) = self {
        public let request : HttpTypes.UpdateRequest = r;

        var pathQueryCache : ?(Text, [(Text, Text)]) = null;

        public let ?method : ?HttpMethod.HttpMethod = HttpMethod.fromText(request.method) else Debug.trap("Unsupported HTTP method: " # request.method);

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
    };

};
