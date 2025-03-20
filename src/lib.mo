import HttpRouter "./Router";
import Types "./Types";
import HttpTypes "./HttpTypes";
import HttpContext "./HttpContext";
import AppModule "./App";

module {
    public type Router = HttpRouter.Router;

    public type HttpContext = HttpContext.HttpContext;

    public type HttpRequest = Types.HttpRequest;
    public type HttpResponse = Types.HttpResponse;

    public type RawQueryHttpRequest = HttpTypes.QueryRequest;
    public type RawQueryHttpResponse = HttpTypes.QueryResponse;

    public type RawUpdateHttpRequest = HttpTypes.UpdateRequest;
    public type RawUpdateHttpResponse = HttpTypes.UpdateResponse;

    public type App = AppModule.App;
    public func App(data : AppModule.Data) : App = AppModule.App(data);

    public type AppBuilder = AppModule.Builder;
    public func AppBuilder() : AppBuilder = AppModule.Builder();
};
