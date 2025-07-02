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
import ContentNegotiation "ContentNegotiation";
import MimeType "MimeType";
import Serde "mo:serde";
import Logging "Logging";

module {
    public type Next = () -> QueryResult;
    public type NextAsync = () -> async* Types.HttpResponse;

    public type HttpResponse = Types.HttpResponse;

    public type MimeType = MimeType.MimeType;
    public type ContentPreference = ContentNegotiation.ContentPreference;

    public type Candid = Serde.Candid;

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
        name : Text;
        handleQuery : QueryFunc;
        handleUpdate : UpdateFunc;
    };

    public type Data = {
        middleware : [Middleware];
        errorSerializer : HttpContext.ErrorSerializer;
        candidRepresentationNegotiator : HttpContext.CandidRepresentationNegotiator;
        logger : Logging.Logger;
    };

    /// Main application class that handles HTTP requests through a middleware pipeline.
    /// Processes both query (read-only) and update (state-changing) requests.
    /// Provides automatic content negotiation, error handling, and logging.
    ///
    /// ```motoko
    /// let app = Liminal.App({
    ///     middleware = [
    ///         RouterMiddleware.new(routerConfig),
    ///         CORSMiddleware.new(corsConfig)
    ///     ];
    ///     errorSerializer = Liminal.defaultJsonErrorSerializer;
    ///     candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
    ///     logger = Liminal.buildDebugLogger(#info);
    /// });
    /// ```
    public class App(data : Data) = self {

        /// Handles HTTP query requests (read-only operations).
        /// Query requests cannot modify state and are processed synchronously.
        /// Used for GET requests and other read operations that don't change application state.
        ///
        /// ```motoko
        /// let app = Liminal.App({ middleware = []; /* other config */ });
        /// let request = { method = "GET"; url = "/users"; headers = []; body = ""; certificate_version = null };
        /// let response = app.http_request(request);
        /// ```
        public func http_request(req : HttpTypes.QueryRequest) : HttpTypes.QueryResponse {
            let httpContext = HttpContext.HttpContext(
                req,
                req.certificate_version,
                {
                    errorSerializer = data.errorSerializer;
                    candidRepresentationNegotiator = data.candidRepresentationNegotiator;
                    logger = data.logger;
                },
            );

            // Helper function to create the middleware chain
            func createNext(index : Nat) : Next {
                func() : QueryResult {

                    // Ensure we restore the original logger
                    if (index >= data.middleware.size()) {
                        // If no middleware handled the request, return not found
                        return #response(getNotFoundResponse());
                    };

                    let originalLogger = httpContext.logger;

                    let next = func() : QueryResult {
                        httpContext.logger := originalLogger; // Restore original logger
                        httpContext.log(#verbose, "Finished handling query with middleware: " # middleware.name);
                        createNext(index + 1)();
                    };

                    // Only run if the middleware has a handleQuery function
                    // Otherwise, skip to the next middleware

                    let middleware = data.middleware[index];
                    httpContext.log(#verbose, "Handling query with middleware: " # middleware.name);
                    httpContext.logger := Logging.withLogScope(originalLogger, "{Query} " # middleware.name);
                    // Call the middleware's handleQuery function
                    middleware.handleQuery(httpContext, next);
                };
            };

            if (data.middleware.size() < 1) {
                return getHttpNotFoundResponse();
            };
            // Start the middleware chain with the first middleware
            let startMiddlewareChain = createNext(0);
            switch (startMiddlewareChain()) {
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

        /// Handles HTTP update requests (state-changing operations).
        /// Update requests can modify application state and support async operations.
        /// Used for POST, PUT, PATCH, DELETE requests and other operations that change state.
        ///
        /// ```motoko
        /// let app = Liminal.App({ middleware = []; /* other config */ });
        /// let request = { method = "POST"; url = "/users"; headers = []; body = "{\"name\": \"John\"}"; certificate_version = null };
        /// let response = await* app.http_request_update(request);
        /// ```
        public func http_request_update(req : HttpTypes.UpdateRequest) : async* HttpTypes.UpdateResponse {
            let httpContext = HttpContext.HttpContext(
                req,
                null,
                {
                    errorSerializer = data.errorSerializer;
                    candidRepresentationNegotiator = data.candidRepresentationNegotiator;
                    logger = data.logger;
                },
            );

            func callMiddlewareUpdate(middleware : Middleware, next : NextAsync) : async* HttpResponse {
                // Only run if the middleware has a handleUpdate function
                // Otherwise, skip to the next middleware

                let originalLogger = httpContext.logger;
                httpContext.logger := Logging.withLogScope(originalLogger, "{Update} " # middleware.name);
                try {
                    await* middleware.handleUpdate(httpContext, next);
                } finally {
                    // Ensure we restore the original logger even if an error occurs
                    httpContext.logger := originalLogger; // Restore original logger
                };
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

    /// Default JSON error serializer for HTTP errors.
    /// Converts HTTP errors into JSON format with appropriate error structure.
    /// Supports various error data types including validation errors and generic messages.
    ///
    /// ```motoko
    /// let app = Liminal.App({
    ///     errorSerializer = Liminal.defaultJsonErrorSerializer;
    ///     // other config
    /// });
    /// ```
    public func defaultJsonErrorSerializer(
        error : HttpContext.HttpError
    ) : HttpContext.ErrorSerializerResponse {
        let (jsonBody, contentTypeOrNull) : (Json.Json, ?Text) = switch (error.data) {
            case (#none) return {
                headers = [];
                body = null;
            };
            case (#message(message)) {
                let statusCodeText = HttpContext.getStatusCodeLabel(error.statusCode);
                let json = #object_([
                    ("status", #number(#int(error.statusCode))),
                    ("error", #string(statusCodeText)),
                    ("message", #string(message)),
                ]);
                (json, null);
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

                let json = #object_(Buffer.toArray(fields));
                (json, ?"application/problem+json");
            };
        };
        let body = Text.encodeUtf8(Json.stringify(jsonBody, null));
        {
            headers = [
                ("Content-Type", Option.get(contentTypeOrNull, "application/json")),
                ("Content-Length", Nat.toText(body.size())),
            ];
            body = ?body;
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
