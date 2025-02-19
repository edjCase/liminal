import Text "mo:base/Text";
import Array "mo:base/Array";
import Time "mo:base/Time";
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

    public type AssetData = {
        modifiedTime : Time.Time;
        encoding : Encoding;
        contentChunks : [Blob];
        totalContentSize : Nat;
        sha256 : Blob;
    };

    public type Asset = {
        key : Text;
        contentType : Text;
        encodedData : [AssetData];
    };

    public func encodingFromText(encoding : Text) : ?Encoding {
        let normalizedEncoding = encoding
        |> Text.trim(_, #char(' '))
        |> Text.toLowercase(_);
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

    public func getEncoding(asset : Asset, encoding : Encoding) : ?AssetData {
        Array.find(
            asset.encodedData,
            func(encodedData : AssetData) : Bool = encodedData.encoding == encoding,
        );
    };

    public func getEncodingByLargestWeight(asset : Asset, encodings : [EncodingWithWeight]) : ?AssetData {
        var excludeIdentity = false;
        var assetDataOrNull : ?AssetData = null;
        // Already ordered by quality
        label f for (encoding in encodings.vals()) {
            // Weight 0 means exclude
            if (encoding.weight == 0) {
                if (encoding.encoding == #identity) {
                    excludeIdentity := true; // Only exclude identity if it is set to 0
                };
                continue f;
            };
            assetDataOrNull := Array.find(asset.encodedData, func(data : AssetData) : Bool = data.encoding == encoding.encoding);
            if (assetDataOrNull != null) {
                break f;
            };
        };
        assetDataOrNull;
    };
};
