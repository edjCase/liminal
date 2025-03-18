import HttpRouter "./Router";
import Types "./Types";
import HttpPipeline "./Pipeline";
import HttpTypes "./HttpTypes";
import HttpContext "./HttpContext";

module {
    public type Router = HttpRouter.Router;

    public type Pipeline = HttpPipeline.Pipeline;
    public func Pipeline(data : HttpPipeline.PipelineData) : Pipeline = HttpPipeline.Pipeline(data);

    public type HttpContext = HttpContext.HttpContext;

    public type HttpRequest = Types.HttpRequest;
    public type HttpResponse = Types.HttpResponse;

    public type RawQueryHttpRequest = HttpTypes.QueryRequest;
    public type RawQueryHttpResponse = HttpTypes.QueryResponse;

    public type RawUpdateHttpRequest = HttpTypes.UpdateRequest;
    public type RawUpdateHttpResponse = HttpTypes.UpdateResponse;
};
