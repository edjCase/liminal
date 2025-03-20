import Assets "../Assets";
import App "../App";
import Path "../Path";
import HttpContext "../HttpContext";
import Types "../Types";

module {

    public type Config = Assets.Config;

    public func new(options : Config) : App.Middleware {
        {
            handleQuery = ?(
                func(httpContext : HttpContext.HttpContext, next : App.Next) : ?Types.HttpResponse {
                    next(); // TODO
                }
            );
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : App.NextAsync) : async* ?Types.HttpResponse {
                Assets.serve(httpContext, options);
            };
        };
    };
};
