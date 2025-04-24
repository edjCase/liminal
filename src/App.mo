import Types "./Types";
import Blob "mo:new-base/Blob";
import Nat16 "mo:new-base/Nat16";
import Option "mo:new-base/Option";
import Text "mo:new-base/Text";
import Nat "mo:new-base/Nat";
import HttpContext "./HttpContext";
import HttpTypes "./HttpTypes";
import Json "mo:json";
import Buffer "mo:base/Buffer";

module {
    public type Next = () -> QueryResult;
    public type NextAsync = () -> async* Types.HttpResponse;

    public type HttpResponse = Types.HttpResponse;

    public type StreamResult = {
        kind : Types.StreamingStrategy;
        response : Types.HttpResponse;
    };

    public type QueryResult = {
        #response : Types.HttpResponse;
        #upgrade;
    };

    public type QueryFunc = (HttpContext.HttpContext, Next) -> QueryResult;

    public type UpdateFunc = (HttpContext.HttpContext, NextAsync) -> async* Types.HttpResponse;

    public type StreamingCallbackResponse = {
        body : Blob;
        token : ?Blob;
    };

    public type Middleware = {
        handleQuery : QueryFunc;
        handleUpdate : UpdateFunc;
    };

    public type Data = {
        middleware : [Middleware];
        errorSerializer : HttpContext.HttpError -> HttpContext.ErrorSerializerResponse;
    };

    public func defaultJsonErrorSerializer(
        error : HttpContext.HttpError
    ) : HttpContext.ErrorSerializerResponse {
        let jsonBody : Json.Json = switch (error.data) {
            case (#none) return {
                headers = [];
                body = null;
            };
            case (#message(message)) {
                let statusCodeText = HttpContext.getStatusCodeLabel(error.statusCode);
                #object_([
                    ("status", #number(#int(error.statusCode))),
                    ("error", #string(statusCodeText)),
                    ("message", #string(message)),
                ]);
            };
            case (#rfc9457(rfc)) {
                let fields = Buffer.Buffer<(Text, Json.Json)>(10);
                let addIfNotNull = func(
                    key : Text,
                    value : ?Text,
                ) {
                    switch (value) {
                        case (?v) fields.add((key, #string(v)));
                        case (null) ();
                    };
                };
                fields.add(("type", #string(rfc.type_)));
                fields.add(("status", #number(#int(error.statusCode))));
                addIfNotNull("title", rfc.title);
                addIfNotNull("detail", rfc.detail);
                addIfNotNull("instance", rfc.instance);

                for (extension in rfc.extensions.vals()) {
                    fields.add((extension.name, mapExtensionToJson(extension.value)));
                };

                #object_(Buffer.toArray(fields));
            };
        };
        let body = Text.encodeUtf8(Json.stringify(jsonBody, null));
        {
            headers = [
                ("Content-Type", "application/json"),
                ("Content-Length", Nat.toText(body.size())),
            ];
            body = ?body;
        };
    };

    public class App(data : Data) = self {

        public func http_request(req : HttpTypes.QueryRequest) : HttpTypes.QueryResponse {
            let httpContext = HttpContext.HttpContext(
                req,
                req.certificate_version,
                {
                    errorSerializer = data.errorSerializer;
                },
            );

            func handle(middleware : Middleware, next : Next) : QueryResult {
                // Only run if the middleware has a handleQuery function
                // Otherwise, skip to the next middleware
                middleware.handleQuery(httpContext, next);
            };

            // Helper function to create the middleware chain
            func createNext(index : Nat) : Next {
                func() : QueryResult {
                    if (index >= data.middleware.size()) {
                        // If no middleware handled the request, return not found
                        return #response(getNotFoundResponse());
                    };

                    let middleware = data.middleware[index];
                    let next = createNext(index + 1);
                    handle(middleware, next);
                };
            };

            if (data.middleware.size() < 1) {
                return getHttpNotFoundResponse();
            };
            // Start the middleware chain with the first middleware
            let middleware = data.middleware[0];
            let next = createNext(1);
            switch (handle(middleware, next)) {
                case (#upgrade) {
                    // Upgrade to update request if nothing is handled by the query middleware
                    {
                        status_code = 200;
                        headers = [];
                        body = Blob.fromArray([]);
                        streaming_strategy = null;
                        upgrade = ?true;
                    };
                };
                case (#response(response)) {
                    // Return the response from the middleware
                    {
                        mapResponse(response) with
                        upgrade = null;
                    };
                };
            };
        };

        public func http_request_update(req : HttpTypes.UpdateRequest) : async* HttpTypes.UpdateResponse {
            let httpContext = HttpContext.HttpContext(
                req,
                null,
                {
                    errorSerializer = data.errorSerializer;
                },
            );

            func callMiddlewareUpdate(middleware : Middleware, next : NextAsync) : async* HttpResponse {
                // Only run if the middleware has a handleUpdate function
                // Otherwise, skip to the next middleware
                await* middleware.handleUpdate(httpContext, next);
            };

            // Helper function to create the middleware chain
            func createNext(index : Nat) : NextAsync {
                func() : async* HttpResponse {
                    if (index >= data.middleware.size()) {
                        return getNotFoundResponse();
                    };

                    let middleware = data.middleware[index];
                    let next = createNext(index + 1);
                    await* callMiddlewareUpdate(middleware, next);
                };
            };

            if (data.middleware.size() < 1) {
                return getHttpNotFoundResponse();
            };
            // Start the middleware chain with the first middleware
            let middleware = data.middleware[0];
            let next = createNext(1);
            let response = await* callMiddlewareUpdate(middleware, next);
            mapResponse(response);
        };

        private func mapResponse(response : Types.HttpResponse) : HttpTypes.UpdateResponse {
            {
                status_code = Nat16.fromNat(response.statusCode);
                headers = response.headers;
                body = Option.get(response.body, Blob.fromArray([]));
                streaming_strategy = switch (response.streamingStrategy) {
                    case (null) null;
                    case (?streamingStrategy) ?mapStreamingStrategy(streamingStrategy);
                };
            };
        };

        private func mapStreamingStrategy(streamingStrategy : Types.StreamingStrategy) : HttpTypes.StreamingStrategy {
            switch (streamingStrategy) {
                case (#callback(callback)) #Callback(callback);
            };
        };

        private func getNotFoundResponse() : Types.HttpResponse {
            {
                statusCode = 404;
                headers = [];
                body = null;
                streamingStrategy = null;
            };
        };

        private func getHttpNotFoundResponse() : HttpTypes.QueryResponse {
            {
                status_code = 404;
                headers = [];
                body = Blob.fromArray([]);
                streaming_strategy = null;
                upgrade = null;
            };
        };
    };

    private func mapExtensionToJson(
        value : HttpContext.ExtensionValue
    ) : Json.Json {
        switch (value) {
            case (#text(v)) #string(v);
            case (#number(v)) #number(#int(v));
            case (#boolean(v)) #bool(v);
            case (#array(v)) {
                let jsonArray = Buffer.Buffer<Json.Json>(v.size());
                for (innerExtension in v.vals()) {
                    jsonArray.add(mapExtensionToJson(innerExtension));
                };
                #array(Buffer.toArray(jsonArray));
            };
            case (#object_(v)) {
                let jsonObject = Buffer.Buffer<(Text, Json.Json)>(v.size());
                for ((innerName, innerValue) in v.vals()) {
                    jsonObject.add((innerName, mapExtensionToJson(innerValue)));
                };
                #object_(Buffer.toArray(jsonObject));
            };
        };
    };
};
