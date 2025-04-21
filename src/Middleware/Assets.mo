import Assets "../Assets";
import App "../App";
import HttpContext "../HttpContext";

module {

    public type Config = Assets.Config;

    public func new(options : Config) : App.Middleware {
        {
            handleQuery = func(httpContext : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                next(); // TODO
            };
            handleUpdate = func(httpContext : HttpContext.HttpContext, next : App.NextAsync) : async* App.UpdateResult {
                switch (Assets.serve(httpContext, options)) {
                    case (#noMatch) await* next();
                    case (#stream(stream)) #stream(stream);
                    case (#response(response)) #response(response);
                };
            };
        };
    };

    public func streamingCallbackHandler(options : Config) : Blob -> ?App.StreamingCallbackResponse {
        func(token : Blob) : ?App.StreamingCallbackResponse {
            Assets.streamingCallbackHandler(token, options);
        };
    };
};
