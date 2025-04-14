import HttpTypes "./HttpTypes";
import Text "mo:new-base/Text";
import TextX "mo:xtended-text/TextX";
import Array "mo:new-base/Array";
import Result "mo:new-base/Result";
import Runtime "mo:new-base/Runtime";
import Iter "mo:new-base/Iter";
import IterTools "mo:itertools/Iter";
import Parser "./Parser";
import HttpMethod "./HttpMethod";
import Json "mo:json";
import Path "Path";
import JWT "mo:jwt";
import Identity "Identity";

module {

    public class HttpContext(r : HttpTypes.UpdateRequest) = self {
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
    };

};
