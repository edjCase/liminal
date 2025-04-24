import CertifiedAssets "../CertifiedAssets";
import App "../App";
import HttpContext "../HttpContext";

module {

    public func new(options : CertifiedAssets.Options) : App.Middleware {
        {
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {

                switch (next()) {
                    case (#response(response)) {
                        let updatedResponse = CertifiedAssets.handleResponse(context, response, options);
                        #response(updatedResponse);
                    };
                    case (#upgrade) #upgrade;
                    case (#stream(stream)) #stream(stream);
                };
            };
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                switch (await* next()) {
                    case (#response(response)) {
                        let updatedResponse = CertifiedAssets.handleResponse(context, response, options);
                        #response(updatedResponse);
                    };
                    case (#stream(stream)) #stream(stream);
                };
            };
        };
    };
};
