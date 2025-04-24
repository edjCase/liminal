import HttpContext "../HttpContext";
import Router "../Router";
import App "../App";

module Module {

    public type Config = Router.Config;

    public func new(config : Config) : App.Middleware {
        let router = Router.Router(config);
        {
            handleQuery = func(httpContext : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                switch (router.route(httpContext)) {
                    case (#response(response)) #response(response);
                    case (#upgrade) #upgrade;
                    case (#noMatch) next();
                };
            };
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                switch (await* router.routeAsync(httpContext)) {
                    case (#response(response)) response;
                    case (#noMatch) await* next();
                };
            };
        };
    };

};
