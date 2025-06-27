import Assets "../Assets";
import App "../App";
import HttpContext "../HttpContext";

module {

    public type Config = Assets.Config;

    public func new(options : Config) : App.Middleware {
        {
            name = "Assets";
            handleQuery = func(httpContext : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                switch (Assets.serve(httpContext, options)) {
                    case (#noMatch) next();
                    case (#response(response)) {
                        httpContext.log(#debug_, "Served static asset");
                        #response(response);
                    };
                };
            };
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                // Only works with query, but possible could add support for update. TODO?
                await* next();
            };
        };
    };
};
