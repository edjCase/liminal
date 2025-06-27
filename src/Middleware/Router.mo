import HttpContext "../HttpContext";
import Router "../Router";
import App "../App";

module Module {

    public type Config = Router.Config;

    /// Creates a new router middleware with the specified configuration
    /// Routes incoming requests to appropriate handlers based on path and method
    /// - Parameter config: Router configuration defining routes and behaviors
    /// - Returns: A middleware that handles request routing
    public func new(config : Config) : App.Middleware {
        let router = Router.Router(config);
        {
            name = "Router";
            handleQuery = func(httpContext : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                switch (router.routeQuery(httpContext)) {
                    case (#response(response)) #response(response);
                    case (#upgrade) #upgrade;
                    case (#noMatch) {
                        httpContext.log(#verbose, "No route matched, continuing to next middleware");
                        next();
                    };
                };
            };
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                switch (await* router.routeUpdate(httpContext)) {
                    case (#response(response)) response;
                    case (#noMatch) {
                        httpContext.log(#verbose, "No route matched in update, continuing to next middleware");
                        await* next();
                    };
                };
            };
        };
    };

};
