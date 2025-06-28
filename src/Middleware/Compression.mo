import Compression "../Compression";
import App "../App";
import HttpContext "../HttpContext";
module {

    public type Config = Compression.Config;

    // Default configuration with balanced settings
    public func defaultConfig() : Config {
        {
            minSize = 1024; // Don't compress responses smaller than 1KB
            mimeTypes = [
                "text/",
                "application/javascript",
                "application/json",
                "application/xml",
                "application/xhtml+xml",
                "application/rss+xml",
                "application/atom+xml",
                "application/x-font-ttf",
                "font/",
                "image/svg+xml",
            ];
            skipCompressionIf = null;
            maxDecompressedSize = null;
        };
    };

    public func default() : App.Middleware {
        new(defaultConfig());
    };

    public func new(config : Config) : App.Middleware {
        // Function to compress a response if appropriate

        {
            name = "Compression";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                switch (next()) {
                    case (#response(response)) {
                        let compressedResponse = Compression.compressResponse(context, response, config);
                        #response(compressedResponse);
                    };
                    case (#upgrade) #upgrade;
                };
            };

            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                let response = await* next();
                Compression.compressResponse(context, response, config);
            };
        };
    };
};
