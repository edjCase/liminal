import Text "mo:new-base/Text";

module {

    public type Encoding = {
        #wildcard;
        #identity;
        #gzip;
        #br;
        #compress;
        #deflate;
        #zstd;
    };
    public type EncodingWithWeight = {
        encoding : Encoding;
        weight : Nat; // 0-1000
    };

    public func encodingFromText(encoding : Text) : ?Encoding {
        let normalizedEncoding = encoding
        |> Text.trim(_, #char(' '))
        |> Text.toLower(_);
        let encodingVariant = switch (normalizedEncoding) {
            case ("identity") #identity;
            case ("gzip") #gzip;
            case ("deflate") #deflate;
            case ("br") #br;
            case ("compress") #compress;
            case ("zstd") #zstd;
            case ("*") #wildcard;
            case (_) {
                return null;
            };
        };
        ?encodingVariant;
    };

    public func encodingToText(encoding : Encoding) : Text {
        switch (encoding) {
            case (#identity) "identity";
            case (#gzip) "gzip";
            case (#deflate) "deflate";
            case (#br) "br";
            case (#compress) "compress";
            case (#zstd) "zstd";
            case (#wildcard) "*";
        };
    };

};
