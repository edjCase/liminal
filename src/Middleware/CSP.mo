import App "../App";
import HttpContext "../HttpContext";
import Types "../Types";
import CSP "../CSP";

module {
    public type Options = CSP.Options;

    public let defaultOptions = CSP.defaultOptions;

    public func default() : App.Middleware {
        new(defaultOptions);
    };

    public func new(options : Options) : App.Middleware {
        {
            handleQuery = ?(
                func(context : HttpContext.HttpContext, next : App.Next) : ?Types.HttpResponse {
                    let ?response = next() else return null;
                    ?CSP.addHeadersToResponse(response, options);
                }
            );
            handleUpdate = func(_ : HttpContext.HttpContext, next : App.NextAsync) : async* ?Types.HttpResponse {
                let ?response = await* next() else return null;
                ?CSP.addHeadersToResponse(response, options);
            };
        };
    };

};
