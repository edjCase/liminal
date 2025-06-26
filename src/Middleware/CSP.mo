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
            name = "CSP";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                switch (next()) {
                    case (#response(response)) {
                        context.log(#verbose, "Adding CSP headers to response");
                        let updatedResponse = CSP.addHeadersToResponse(response, options);
                        #response(updatedResponse);
                    };
                    case (#upgrade) #upgrade;
                };
            };
            handleUpdate = func(_ : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                let response = await* next();
                let updatedResponse = CSP.addHeadersToResponse(response, options);
                updatedResponse;
            };
        };
    };

};
