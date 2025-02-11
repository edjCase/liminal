import Text "mo:base/Text";
import Iter "mo:base/Iter";
import IterTools "mo:itertools/Iter";

module Module {

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
