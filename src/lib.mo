import RouterModule "./Router";
import Types "./Types";
import HttpTypes "./HttpTypes";
import HttpContext "./HttpContext";
import AppModule "./App";
import CandidRepresentationNegotation "./CandidRepresentationNegotiation";
import Logging "Logging";
import RouteContext "./RouteContext";

/// Liminal Web Framework Library
///
/// Liminal is a web framework for the Internet Computer built in Motoko.
/// It provides middleware support, routing, HTTP context management, and various utilities
/// for building web applications and APIs on the IC.
module {
    /// Router type for defining and matching HTTP routes
    public type Router = RouterModule.Router;

    /// HTTP context provides access to request data and response building utilities
    public type HttpContext = HttpContext.HttpContext;

    /// Internal HTTP request representation with parsed and validated data
    public type HttpRequest = Types.HttpRequest;

    /// Internal HTTP response representation with structured data
    public type HttpResponse = Types.HttpResponse;

    /// Raw query HTTP request as received from the IC (read-only operations)
    public type RawQueryHttpRequest = HttpTypes.QueryRequest;

    /// Raw query HTTP response as sent to the IC (read-only operations)
    public type RawQueryHttpResponse = HttpTypes.QueryResponse;

    /// Raw update HTTP request as received from the IC (state-changing operations)
    public type RawUpdateHttpRequest = HttpTypes.UpdateRequest;

    /// Raw update HTTP response as sent to the IC (state-changing operations)
    public type RawUpdateHttpResponse = HttpTypes.UpdateResponse;

    /// Route context provides route-specific data like path parameters
    public type RouteContext = RouteContext.RouteContext;

    /// Main application class that handles HTTP requests through middleware pipeline
    public type App = AppModule.App;

    /// Creates a new Liminal application instance.
    /// The application processes HTTP requests through a middleware pipeline and handles routing.
    ///
    /// ```motoko
    /// import Liminal "mo:liminal";
    ///
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
    public func App(data : AppModule.Data) : App = AppModule.App(data);

    /// Default JSON error serializer that converts HTTP errors to JSON format.
    /// Provides consistent error response structure across the application.
    ///
    /// ```motoko
    /// let app = Liminal.App({
    ///     errorSerializer = Liminal.defaultJsonErrorSerializer;
    ///     // other config
    /// });
    /// ```
    public let defaultJsonErrorSerializer : HttpContext.ErrorSerializer = AppModule.defaultJsonErrorSerializer;

    /// Default Candid representation negotiator for handling different response formats.
    /// Automatically selects appropriate response representation based on Accept headers.
    ///
    /// ```motoko
    /// let app = Liminal.App({
    ///     candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
    ///     // other config
    /// });
    /// ```
    public let defaultCandidRepresentationNegotiator : HttpContext.CandidRepresentationNegotiator = CandidRepresentationNegotation.defaultNegotiator;

    /// Creates a debug logger with configurable log levels.
    /// Useful for development and debugging HTTP request processing.
    ///
    /// ```motoko
    /// let app = Liminal.App({
    ///     logger = Liminal.buildDebugLogger(#verbose); // #error, #warning, #info, #debug, #verbose
    ///     // other config
    /// });
    /// ```
    public let buildDebugLogger = Logging.buildDebugLogger;
};
