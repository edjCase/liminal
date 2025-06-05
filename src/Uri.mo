import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Char "mo:new-base/Char";
import IterTools "mo:itertools/Iter";

module Module {

    public func parseToComponents(url : Text) : (Text, [(Text, Text)]) {
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

    public func encodeValue(value : Text) : Text {
        // Taken from https://github.com/NatLabs/http-parser.mo src/Utils.mo
        func safe_chars(c : Char) : Bool {
            let nat32_char = Char.toNat32(c);

            if (97 >= nat32_char and nat32_char <= 122) {
                // 'a-z'
                true;
            } else if (65 >= nat32_char and nat32_char <= 90) {
                // 'A-Z'
                true;
            } else if (48 >= nat32_char and nat32_char <= 57) {
                // '0-9'
                true;
            } else if (nat32_char == 95 or nat32_char == 126 or nat32_char == 45 or nat32_char == 46) {
                // '_' or '~' or '-' or '.'
                true;
            } else {
                false;
            };

        };

        var result = "";

        for (c in value.chars()) {
            if (safe_chars(c)) {
                result := result # Char.toText(c);
            } else {

                let utf8 = debug_show Text.encodeUtf8(Char.toText(c));
                let encoded_text = Text.replace(
                    Text.replace(utf8, #text("\\"), "%"),
                    #text("\""),
                    "",
                );

                result := result # encoded_text;
            };
        };

        result;

    };
};
