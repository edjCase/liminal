import HttpPipeline "../../src/Pipeline";
import HttpContext "../../src/HttpContext";
import Types "../../src/Types";
import HttpMethod "../../src/HttpMethod";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Path "../../src/Path";

module {

    public func use(data : HttpPipeline.PipelineData) : HttpPipeline.PipelineData {

        func getPrefix(kind : { #query_; #update }) : Text {
            switch (kind) {
                case (#query_) "Query ";
                case (#update) "Update ";
            };
        };

        func logRequest(kind : { #query_; #update }, context : HttpContext.HttpContext) {
            let prefix = getPrefix(kind);
            Debug.print(prefix # "HTTP Request: " # HttpMethod.toText(context.method) # " " # Path.toText(context.getPath()));
        };

        func logResponse(kind : { #query_; #update }, responseOrNull : ?Types.HttpResponse) {
            let prefix = getPrefix(kind);
            let responseText = switch (responseOrNull) {
                case (?response) Nat.toText(response.statusCode);
                case (null) "null";
            };
            Debug.print(prefix # "HTTP Response: " # responseText);
        };

        let newMiddleware : HttpPipeline.Middleware = {
            handleQuery = ?(
                func(context : HttpContext.HttpContext, next : HttpPipeline.Next) : ?Types.HttpResponse {
                    logRequest(#query_, context);
                    let responseOrNull = next();
                    logResponse(#query_, responseOrNull);
                    responseOrNull;
                }
            );
            handleUpdate = func(context : HttpContext.HttpContext, next : HttpPipeline.NextAsync) : async* ?Types.HttpResponse {
                logRequest(#update, context);
                let responseOrNull = await* next();
                logResponse(#update, responseOrNull);
                responseOrNull;
            };
        };
        {
            middleware = Array.append(data.middleware, [newMiddleware]);
        };
    };
};
