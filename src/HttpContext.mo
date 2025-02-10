import HttpTypes "./HttpTypes";
import Types "./Types";
import Text "mo:base/Text";
import TextX "mo:xtended-text/TextX";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import IterTools "mo:itertools/Iter";
import Parser "./Parser";

module {

    public class HttpContext(r : HttpTypes.UpdateRequest) = self {
        public let request : HttpTypes.UpdateRequest = r;

        var pathQueryCache : ?(Text, [(Text, Text)]) = null;

        public let method : Types.HttpMethod = Parser.parseHttpMethod(request.method);

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
    };

};
