import HttpRouter "./router";
import Types "./types";
import HttpPipeline "./pipeline";
import HttpTypes "./http-types";
import HttpParser "./parser";

module {
    public type Router = HttpRouter.Router;
    public func Router(data : HttpRouter.RouterData) : Router = HttpRouter.Router(data);

    public type Pipeline = HttpPipeline.Pipeline;
    public func Pipeline(data : HttpPipeline.PipelineData) : Pipeline = HttpPipeline.Pipeline(data);

    public type HttpContext = HttpParser.HttpContext;

    public type HttpRequest = Types.HttpRequest;
    public type HttpResponse = Types.HttpResponse;

    public type RawQueryHttpRequest = HttpTypes.QueryRequest;
    public type RawQueryHttpResponse = HttpTypes.QueryResponse;

    public type RawUpdateHttpRequest = HttpTypes.UpdateRequest;
    public type RawUpdateHttpResponse = HttpTypes.UpdateResponse;
};
