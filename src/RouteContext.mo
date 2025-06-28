import HttpContext "./HttpContext";
import Types "./Types";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Result "mo:new-base/Result";
import Runtime "mo:new-base/Runtime";
import TextX "mo:xtended-text/TextX";
import Json "mo:json";
import Identity "./Identity";
import FileUpload "FileUpload";

module {
    public type HttpResponse = Types.HttpResponse;
    public type ResponseKind = HttpContext.ResponseKind;

    public type HttpErrorDataKind = HttpContext.HttpErrorDataKind;

    public type HttpStatusCode = HttpContext.HttpStatusCode;
    public type HttpStatusCodeOrCustom = HttpContext.HttpStatusCodeOrCustom;
    public type SuccessHttpStatusCode = HttpContext.SuccessHttpStatusCode;
    public type SuccessHttpStatusCodeOrCustom = HttpContext.SuccessHttpStatusCodeOrCustom;
    public type ErrorHttpStatusCode = HttpContext.ErrorHttpStatusCode;
    public type ErrorHttpStatusCodeOrCustom = HttpContext.ErrorHttpStatusCodeOrCustom;
    public type RedirectionHttpStatusCode = HttpContext.RedirectionHttpStatusCode;
    public type RedirectionHttpStatusCodeOrCustom = HttpContext.RedirectionHttpStatusCodeOrCustom;

    public type RouteHandler = {
        #syncQuery : RouteContext -> HttpResponse;
        #syncUpdate : <system>(RouteContext) -> HttpResponse;
        #asyncUpdate : RouteContext -> async* HttpResponse;
    };

    /// Route-specific context that extends HttpContext with route parameters and utilities.
    /// Provides access to parsed route parameters, query parameters, and all HTTP context functionality.
    /// This is the primary interface used within route handlers.
    ///
    /// ```motoko
    /// // In a route handler function
    /// let handler = func(routeContext : RouteContext.RouteContext) : HttpResponse {
    ///     // Access route parameters
    ///     let userId = routeContext.getRouteParam("id");
    ///
    ///     // Access query parameters
    ///     let sortBy = routeContext.getQueryParam("sort");
    ///
    ///     // Parse request body
    ///     switch (routeContext.parseRawJsonBody()) {
    ///         case (#ok(json)) { /* process JSON */ };
    ///         case (#err(e)) { /* handle error */ };
    ///     };
    ///
    ///     // Build response
    ///     routeContext.buildResponse(#ok, #content(#text("Success")));
    /// };
    /// ```
    public class RouteContext(
        httpContext_ : HttpContext.HttpContext,
        handler_ : RouteHandler,
        params_ : [(Text, Text)],
    ) = self {
        public let httpContext : HttpContext.HttpContext = httpContext_;
        public let handler : RouteHandler = handler_;
        public let params : [(Text, Text)] = params_;
        public let log = httpContext.log;

        /// Returns the current user identity if set, null otherwise.
        /// Delegates to the underlying HTTP context's identity management.
        ///
        /// ```motoko
        /// switch (routeContext.getIdentity()) {
        ///     case (?identity) {
        ///         if (identity.isAuthenticated()) {
        ///             // User is authenticated
        ///         };
        ///     };
        ///     case (null) {
        ///         // No identity set
        ///     };
        /// };
        /// ```
        public func getIdentity() : ?Identity.Identity = httpContext.getIdentity();

        /// Gets a route parameter value by key. Traps if the parameter doesn't exist.
        /// Use getRouteParamOrNull() for safe access that returns null instead of trapping.
        ///
        /// ```motoko
        /// // For route "/users/:id" and URL "/users/123"
        /// let userId = routeContext.getRouteParam("id"); // Returns "123"
        /// ```
        public func getRouteParam(key : Text) : Text {
            let ?param = getRouteParamOrNull(key) else {
                Runtime.trap("Parameter '" # key # "' for route was not parsed");
            };
            param;
        };

        /// Gets a route parameter value by key, returns null if not found.
        /// Safer alternative to getRouteParam() that doesn't trap on missing parameters.
        ///
        /// ```motoko
        /// // For route "/users/:id?" and URL "/users"
        /// let userId = routeContext.getRouteParamOrNull("id"); // Returns null
        /// ```
        public func getRouteParamOrNull(key : Text) : ?Text {
            let ?kv = Array.find(
                params,
                func(kv : (Text, Text)) : Bool = TextX.equalIgnoreCase(kv.0, key),
            ) else return null;
            ?kv.1;
        };

        /// Returns all query parameters as key-value pairs.
        /// Delegates to the HTTP context's query parameter parsing.
        ///
        /// ```motoko
        /// let params = routeContext.getQueryParams();
        /// // For URL "/search?q=motoko&sort=date", returns [("q", "motoko"), ("sort", "date")]
        /// ```
        public func getQueryParams() : [(Text, Text)] = httpContext.getQueryParams();

        /// Returns the value of a specific query parameter, or null if not found.
        /// Parameter lookup is case-insensitive.
        ///
        /// ```motoko
        /// let searchQuery = routeContext.getQueryParam("q");
        /// // For URL "/search?q=motoko", returns ?"motoko"
        /// ```
        public func getQueryParam(key : Text) : ?Text = httpContext.getQueryParam(key);

        /// Returns the value of a specific HTTP header, or null if not found.
        /// Header lookup is case-insensitive following HTTP standards.
        ///
        /// ```motoko
        /// let contentType = routeContext.getHeader("Content-Type");
        /// let userAgent = routeContext.getHeader("User-Agent");
        /// ```
        public func getHeader(key : Text) : ?Text = httpContext.getHeader(key);

        /// Parses the request body as JSON and returns the parsed JSON object.
        /// Delegates to the HTTP context's JSON parsing functionality.
        ///
        /// ```motoko
        /// switch (routeContext.parseRawJsonBody()) {
        ///     case (#ok(json)) {
        ///         // Process JSON object
        ///     };
        ///     case (#err(error)) {
        ///         // Handle parsing error
        ///     };
        /// };
        /// ```
        public func parseRawJsonBody() : Result.Result<Json.Json, Text> = httpContext.parseRawJsonBody();

        /// Parses the request body as JSON and applies a transformation function.
        /// Combines JSON parsing with custom deserialization in one step.
        ///
        /// ```motoko
        /// let parseUser = func(json : Json.Json) : Result.Result<User, Text> {
        ///     // Custom parsing logic
        /// };
        /// switch (routeContext.parseJsonBody(parseUser)) {
        ///     case (#ok(user)) {
        ///         // Use parsed user object
        ///     };
        ///     case (#err(error)) {
        ///         // Handle parsing/transformation error
        ///     };
        /// };
        /// ```
        public func parseJsonBody<T>(f : Json.Json -> Result.Result<T, Text>) : Result.Result<T, Text> = httpContext.parseJsonBody(f);

        /// Builds an HTTP response with the specified status code and content.
        /// Convenience wrapper around the HTTP context's response building functionality.
        ///
        /// ```motoko
        /// // Return JSON response
        /// let response = routeContext.buildResponse(#ok, #content(#json(userJson)));
        ///
        /// // Return custom response
        /// let customResponse = routeContext.buildResponse(#created, #custom({
        ///     headers = [("Location", "/users/123")];
        ///     body = Text.encodeUtf8("User created");
        /// }));
        /// ```
        public func buildResponse(statusCode : HttpStatusCodeOrCustom, body : ResponseKind) : HttpResponse {
            httpContext.buildResponse(statusCode, body);
        };

        private var parsedFiles : ?[FileUpload.UploadedFile] = null;

        /// Returns all uploaded files from a multipart/form-data request.
        /// Files are parsed and cached on first access for performance.
        /// Returns an empty array if the request doesn't contain file uploads.
        ///
        /// ```motoko
        /// let files = routeContext.getUploadedFiles();
        /// for (file in files.vals()) {
        ///     let name = file.name;
        ///     let content = file.content;
        ///     let contentType = file.contentType;
        ///     // Process uploaded file
        /// };
        /// ```
        public func getUploadedFiles() : [FileUpload.UploadedFile] {
            switch (parsedFiles) {
                case (?files) files;
                case (null) {
                    // Parse files on first access
                    let files = FileUpload.parseMultipartFormData(self.httpContext);
                    parsedFiles := ?files;
                    files;
                };
            };
        };

    };
};
