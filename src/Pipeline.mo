import Types "./Types";
import Blob "mo:base/Blob";
import Nat16 "mo:base/Nat16";
import Option "mo:base/Option";
import HttpContext "./HttpContext";
import HttpTypes "./HttpTypes";

module Module {

    public type Next = () -> ?Types.HttpResponse;
    public type NextAsync = () -> async* ?Types.HttpResponse;

    public type Middleware = {
        handleQuery : ?((HttpContext.HttpContext, Next) -> ?Types.HttpResponse);
        handleUpdate : (HttpContext.HttpContext, NextAsync) -> async* ?Types.HttpResponse;
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

        public func http_request(req : HttpTypes.QueryRequest) : HttpTypes.QueryResponse {
            let httpContext = HttpContext.HttpContext(req);

            func handle(middleware : Middleware, next : Next) : ?Types.HttpResponse {
                // Only run if the middleware has a handleQuery function
                // Otherwise, skip to the next middleware
                switch (middleware.handleQuery) {
                    case (?handleQuery) handleQuery(httpContext, next);
                    case (null) next();
                };
            };

            // Helper function to create the middleware chain
            func createNext(index : Nat) : Next {
                func() : ?Types.HttpResponse {
                    if (index >= pipelineData.middleware.size()) {
                        return null;
                    };

                    let middleware = pipelineData.middleware[index];
                    let next = createNext(index + 1);
                    handle(middleware, next);
                };
            };

            let response = if (pipelineData.middleware.size() < 1) {
                notFoundResponse();
            } else {
                // Start the middleware chain with the first middleware
                let middleware = pipelineData.middleware[0];
                let next = createNext(1);
                let responseOrNull = handle(middleware, next);

                let ?response = responseOrNull else return {
                    // Upgrade to update request if nothing is handled by the query middleware
                    status_code = 200;
                    headers = [];
                    body = Blob.fromArray([]);
                    streaming_strategy = null;
                    upgrade = ?true;
                };
                response;
            };
            {
                status_code = Nat16.fromNat(response.statusCode);
                headers = response.headers;
                body = Option.get(response.body, Blob.fromArray([]));
                streaming_strategy = null;
                upgrade = null;
            };
        };

        public func http_request_update(req : HttpTypes.UpdateRequest) : async* HttpTypes.UpdateResponse {
            let httpContext = HttpContext.HttpContext(req);

            // Helper function to create the middleware chain
            func createNext(index : Nat) : NextAsync {
                func() : async* ?Types.HttpResponse {
                    if (index >= pipelineData.middleware.size()) {
                        return null;
                    };

                    let middleware = pipelineData.middleware[index];
                    let next = createNext(index + 1);
                    await* middleware.handleUpdate(httpContext, next);
                };
            };

            let response = if (pipelineData.middleware.size() < 1) {
                notFoundResponse();
            } else {
                // Start the middleware chain with the first middleware
                let middleware = pipelineData.middleware[0];
                let next = createNext(1);
                let responseOrNull = await* middleware.handleUpdate(httpContext, next);

                Option.get(responseOrNull, notFoundResponse());
            };

            {
                status_code = Nat16.fromNat(response.statusCode);
                headers = response.headers;
                body = Option.get(response.body, Blob.fromArray([]));
                streaming_strategy = null;
            };
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
