import StaticAssets "../../src/StaticAssets";

module {
    public let assets : [StaticAssets.StaticAsset] = [
        {
            path = "/index.html";
            bytes = [1];
            contentType = "text/html";
            size = 1;
            lastModified = 1;
            etag = "123";
        },
    ];
};
