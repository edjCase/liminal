import Assets "../Assets";
import App "../App";
import Path "../Path";
import HttpContext "../HttpContext";
import Types "../Types";

module {

    public func new(prefix : Text, options : Assets.Options) : App.Middleware {
        let rootPath = Path.parse(prefix);

        {
            handleQuery = ?(
                func(httpContext : HttpContext.HttpContext, next : App.Next) : ?Types.HttpResponse {
                    next(); // TODO
                }
            );
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : App.NextAsync) : async* ?Types.HttpResponse {
                Assets.serve(httpContext, options, ?rootPath);
            };
        };
    };
};
