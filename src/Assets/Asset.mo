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
        encoding : Encoding;
        content : Blob;
        sha256 : Blob;
    };

    public type Asset = {
        key : Text;
        contentType : Text;
        encodedData : [AssetData];
    };
};
