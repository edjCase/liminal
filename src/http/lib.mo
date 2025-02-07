module {
    // // Core types
    // public type Route = {
    //     method : Text;
    //     path : Text;
    //     handler : Handler;
    // };

    // public type Router = {
    //     routes : [Route];
    //     middlewares : [Middleware];
    // };

    // public type Handler = (request : Request) -> Response;
    // public type UpdateHandler = (request : Request) -> async Response;

    // // Public functions
    // public func new() : Router {
    //     Router {
    //         routes = [];
    //         middlewares = [];
    //     };
    // };
    // public func get(router : Router, path : Text, handler : Handler) : Router;
    // public func post(router : Router, path : Text, handler : UpdateHandler) : Router;
    // public func put(router : Router, path : Text, handler : UpdateHandler) : Router;
    // public func delete(router : Router, path : Text, handler : UpdateHandler) : Router;
    // public func use(router : Router, middleware : Middleware) : Router;
    // public func handleRequest(router : Router, request : Request) : Response;
    // public func handleUpdateRequest(router : Router, request : Request) : async Response;
};

// http_request
// http_request_update - only on upgrade. needed for getting signed request
