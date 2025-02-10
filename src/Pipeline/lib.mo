import Types "../Types";
import Blob "mo:base/Blob";
import Nat16 "mo:base/Nat16";
import Option "mo:base/Option";
import HttpContext "../HttpContext";
import HttpTypes "../HttpTypes";

module Module {

    public type Next = () -> Types.HttpResponse;

    public type MiddlewareFunc = (HttpContext.HttpContext, Next) -> Types.HttpResponse;

    public type Middleware = {
        handle : MiddlewareFunc;
    };

    public type PipelineData = {
        middleware : [Middleware];
    };

    public func empty() : PipelineData {
        {
            middleware = [];
        };
    };

    public func build(data : PipelineData) : Pipeline {
        Pipeline(data);
    };

    public class Pipeline(pipelineData : PipelineData) = self {

        public func http_request(_ : HttpTypes.QueryRequest) : HttpTypes.QueryResponse {
            // TODO
            {
                status_code = 200;
                headers = [];
                body = Blob.fromArray([]);
                streaming_strategy = null;
                upgrade = ?true;
            };

        };

        public func http_request_update(req : HttpTypes.UpdateRequest) : HttpTypes.UpdateResponse {

            let httpContext = HttpContext.HttpContext(req);

            let response = runMiddleware(httpContext);

            {
                status_code = Nat16.fromNat(response.statusCode);
                headers = response.headers;
                body = Option.get(response.body, Blob.fromArray([]));
                streaming_strategy = null;
            };

        };

        private func runMiddleware(httpContext : HttpContext.HttpContext) : Types.HttpResponse {
            // Helper function to create the middleware chain
            func createNext(index : Nat) : Next {
                func() : Types.HttpResponse {
                    if (index >= pipelineData.middleware.size()) {
                        return notFoundResponse();
                    };

                    let currentMiddleware = pipelineData.middleware[index];
                    currentMiddleware.handle(httpContext, createNext(index + 1));
                };
            };

            if (pipelineData.middleware.size() < 1) {
                return notFoundResponse();
            };

            // Start the middleware chain with the first middleware
            pipelineData.middleware[0].handle(httpContext, createNext(1));
        };

        private func notFoundResponse() : Types.HttpResponse {
            {
                statusCode = 404;
                headers = [];
                body = null;
            };
        };
    };

};
