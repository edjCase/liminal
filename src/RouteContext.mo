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

    public class RouteContext(
        httpContext_ : HttpContext.HttpContext,
        handler_ : RouteHandler,
        params_ : [(Text, Text)],
    ) = self {
        public let httpContext : HttpContext.HttpContext = httpContext_;
        public let handler : RouteHandler = handler_;
        public let params : [(Text, Text)] = params_;

        public func getIdentity() : ?Identity.Identity = httpContext.getIdentity();

        public func getRouteParam(key : Text) : Text {
            let ?param = getRouteParamOrNull(key) else {
                Runtime.trap("Parameter '" # key # "' for route was not parsed");
            };
            param;
        };

        public func getRouteParamOrNull(key : Text) : ?Text {
            let ?kv = Array.find(
                params,
                func(kv : (Text, Text)) : Bool = TextX.equalIgnoreCase(kv.0, key),
            ) else return null;
            ?kv.1;
        };

        public func getQueryParams() : [(Text, Text)] = httpContext.getQueryParams();

        public func getQueryParam(key : Text) : ?Text = httpContext.getQueryParam(key);

        public func getHeader(key : Text) : ?Text = httpContext.getHeader(key);

        public func parseRawJsonBody() : Result.Result<Json.Json, Text> = httpContext.parseRawJsonBody();

        public func parseJsonBody<T>(f : Json.Json -> Result.Result<T, Text>) : Result.Result<T, Text> = httpContext.parseJsonBody(f);

        public func buildResponse(statusCode : HttpStatusCodeOrCustom, body : ResponseKind) : HttpResponse {
            httpContext.buildResponse(statusCode, body);
        };

        private var parsedFiles : ?[FileUpload.UploadedFile] = null;

        /// Get all uploaded files from the multipart/form-data request
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
