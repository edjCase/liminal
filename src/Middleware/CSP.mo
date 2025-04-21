import App "../App";
import HttpContext "../HttpContext";
import CSP "../CSP";

module {
    public type Options = CSP.Options;

    public let defaultOptions = CSP.defaultOptions;

    public func default() : App.Middleware {
        new(defaultOptions);
    };

    public func new(options : Options) : App.Middleware {
        {
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                switch (next()) {
                    case (#response(response)) {
                        let updatedResponse = CSP.addHeadersToResponse(response, options);
                        #response(updatedResponse);
                    };
                    case (#upgrade) #upgrade;
                    case (#stream(stream)) #stream(stream);
                };
            };
            handleUpdate = func(_ : HttpContext.HttpContext, next : App.NextAsync) : async* App.UpdateResult {
                switch (await* next()) {
                    case (#response(response)) {
                        let updatedResponse = CSP.addHeadersToResponse(response, options);
                        #response(updatedResponse);
                    };
                    case (#stream(stream)) #stream(stream);
                };
            };
        };
    };

};
