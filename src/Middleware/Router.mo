import Types "../Types";
import HttpContext "../HttpContext";
import Router "../Router";
import App "../App";

module Module {

    public type Config = Router.Config;

    public func new(config : Config) : App.Middleware {
        let router = Router.Router(config);
        {
            handleQuery = ?(
                func(httpContext : HttpContext.HttpContext, next : App.Next) : ?Types.HttpResponse {
                    switch (router.route(httpContext)) {
                        case (?response) ?response;
                        case (null) next();
                    };
                }
            );
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : App.NextAsync) : async* ?Types.HttpResponse {
                switch (await* router.routeAsync(httpContext)) {
                    case (?response) ?response;
                    case (null) await* next();
                };
            };
        };
    };

};
