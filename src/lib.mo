import HttpRouter "./router";
import Types "./types";

module {
    public type Router = HttpRouter.Router;
    public func Router() : Router = HttpRouter.Router();

    public type HttpContext = HttpRouter.HttpContext;

    public type HttpResponseRaw = HttpRouter.HttpResponseRaw;
    public type HttpResponseTyped<T> = HttpRouter.HttpResponseTyped<T>;

    public type GetHandlerRaw = HttpRouter.GetHandlerRaw;
    public type GetHandlerTyped<TResponse> = HttpRouter.GetHandlerTyped<TResponse>;

    public type PostHandlerRaw = HttpRouter.PostHandlerRaw;
    public type PostHandlerTyped<TRequest, TResponse> = HttpRouter.PostHandlerTyped<TRequest, TResponse>;

    public type RawQueryHttpRequest = Types.QueryRequest;
    public type RawQueryHttpResponse = Types.QueryResponse;

    public type RawUpdateHttpRequest = Types.UpdateRequest;
    public type RawUpdateHttpResponse = Types.UpdateResponse;

    public func ok<T>(value : ?T) : HttpResponseTyped<T> = HttpRouter.ok<T>(value);
    public func noContent<T>() : HttpResponseTyped<T> = HttpRouter.noContent<T>();
};
