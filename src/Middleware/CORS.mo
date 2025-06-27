import HttpContext "../HttpContext";
import Types "../Types";
import App "../App";
import CORS "../CORS";
import List "mo:new-base/List";
import Text "mo:new-base/Text";

module {

    public type Options = CORS.Options;

    public let defaultOptions = CORS.defaultOptions;

    /// Creates a CORS middleware with default options.
    /// Uses permissive defaults suitable for development but should be configured for production.
    ///
    /// ```motoko
    /// import CORSMiddleware "mo:liminal/Middleware/CORS";
    ///
    /// let app = Liminal.App({
    ///     middleware = [CORSMiddleware.default()];
    ///     // other config
    /// });
    /// ```
    public func default() : App.Middleware {
        new(defaultOptions);
    };

    /// Creates a CORS middleware with custom options.
    /// Allows fine-grained control over CORS behavior including allowed origins, methods, and headers.
    ///
    /// ```motoko
    /// import CORSMiddleware "mo:liminal/Middleware/CORS";
    ///
    /// let corsOptions = {
    ///     allowedOrigins = #whitelist(["https://example.com"]);
    ///     allowedMethods = ["GET", "POST"];
    ///     allowedHeaders = ["Content-Type", "Authorization"];
    ///     maxAge = ?3600;
    ///     allowCredentials = true;
    ///     exposeHeaders = ["X-Custom-Header"];
    /// };
    ///
    /// let app = Liminal.App({
    ///     middleware = [CORSMiddleware.new(corsOptions)];
    ///     // other config
    /// });
    /// ```
    public func new(options : Options) : App.Middleware {
        {
            name = "CORS";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                switch (CORS.handlePreflight(context, options)) {
                    case (#complete(response)) {
                        context.log(#debug_, "Handled preflight request");
                        return #response(response);
                    };
                    case (#next({ corsHeaders })) {
                        switch (next()) {
                            case (#response(response)) {
                                let updatedResponse = addHeadersToResponse(response, corsHeaders);
                                #response(updatedResponse);
                            };
                            case (#upgrade) #upgrade;
                        };
                    };
                };
            };
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                switch (CORS.handlePreflight(context, options)) {
                    case (#complete(response)) return response;
                    case (#next({ corsHeaders })) {
                        let response = await* next();
                        let updatedResponse = addHeadersToResponse(response, corsHeaders);
                        updatedResponse;
                    };
                };
            };
        };
    };

    private func addHeadersToResponse(
        response : Types.HttpResponse,
        corsHeaders : [(Text, Text)],
    ) : Types.HttpResponse {

        // Combine headers
        let responseHeaders = List.fromArray<(Text, Text)>(response.headers);
        List.addAll(responseHeaders, corsHeaders.vals()); // Append CORS headers last

        {
            response with
            headers = List.toArray(responseHeaders);
        };
    };

};
