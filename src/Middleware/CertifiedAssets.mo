import CertifiedAssets "../CertifiedAssets";
import App "../App";
import HttpContext "../HttpContext";
import Types "../Types";

module {

    public func new(options : CertifiedAssets.Options) : App.Middleware {
        {
            handleQuery = ?(
                func(context : HttpContext.HttpContext, next : App.Next) : ?Types.HttpResponse {
                    let ?response = next() else return null;
                    ?CertifiedAssets.handleResponse(context, response, options);
                }
            );
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* ?Types.HttpResponse {
                let ?response = await* next() else return null;
                ?CertifiedAssets.handleResponse(context, response, options);
            };
        };
    };
};
