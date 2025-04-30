# Liminal

[![MOPS](https://img.shields.io/badge/MOPS-liminal-blue)](https://mops.one/liminal)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/edjcase/motoko_http/blob/main/LICENSE)

A middleware-based HTTP framework for Motoko on the Internet Computer.

## Overview

Liminal is a flexible HTTP framework designed to make building web applications with Motoko simpler and more maintainable. It provides a middleware pipeline architecture, built-in routing capabilities, and a variety of helper modules for common web development tasks.

Key features:

- 🔄 **Middleware**: Compose your application using reusable middleware components
- 🛣️ **Routing**: Powerful route matching with parameter extraction and group support
- 🔒 **CORS Support**: Configurable Cross-Origin Resource Sharing
- 🔐 **CSP Support**: Content Security Policy configuration
- 📦 **Asset Canister Integration**: Simplified interface with Internet Computer's certified assets
- 🔑 **JWT Authentication**: Built-in JWT parsing and validation
- 🚀 **Compression**: Automatic response compression for performance
- ⏱️ **Rate Limiting**: Protect your APIs from abuse
- 🛡️ **Authentication**: Configurable authentication requirements
- 🔀 **Content Negotiation**: Automatically convert data to JSON, CBOR, XML based on Accept header
- 📤 **File Uploads**: Parse and process multipart/form-data for handling file uploads (limited to 2MB)

## Package

### MOPS

```bash
mops add liminal
```

To setup MOPS package manager, follow the instructions from the [MOPS Site](https://mops.one)

## Quick Start

Here's a minimal example to get started:

```motoko
import Liminal "mo:liminal";
import Route "mo:liminal/Route";
import Router "mo:liminal/Router";
import RouterMiddleware "mo:liminal/Middleware/Router";
import CORSMiddleware "mo:liminal/Middleware/CORS";

actor {
    // Define your routes
    let routerConfig = {
        prefix = ?"/api";
        identityRequirement = null;
        routes = [
            Router.getQuery(
                "/hello/{name}",
                func(context : RouteContext.RouteContext) : Route.HttpResponse {
                    let name = context.getRouteParam("name");
                    context.buildResponse(#ok, #text("Hello, " # name # "!"));
                }
            )
        ]
    };

    // Create the HTTP App with middleware
    let app = Liminal.App({
        middleware = [
            // Order matters
            // First middleware will be called FIRST with the HTTP request
            // and LAST with handling the HTTP response
            CORSMiddleware.default(),
            RouterMiddleware.new(routerConfig),
        ];
        errorSerializer = Liminal.defaultJsonErrorSerializer;
        candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
    });

    // Expose standard HTTP interface
    public query func http_request(request : Liminal.RawQueryHttpRequest) : async Liminal.RawQueryHttpResponse {
        app.http_request(request)
    };

    public func http_request_update(request : Liminal.RawUpdateHttpRequest) : async Liminal.RawUpdateHttpResponse {
        await* app.http_request_update(request)
    };
}
```

## More Complete Example

Here's a more comprehensive example demonstrating multiple middleware components:

```motoko
import Liminal "mo:liminal";
import Route "mo:liminal/Route";
import Router "mo:liminal/Router";
import RouterMiddleware "mo:liminal/Middleware/Router";
import CORSMiddleware "mo:liminal/Middleware/CORS";
import JWTMiddleware "mo:liminal/Middleware/JWT";
import CompressionMiddleware "mo:liminal/Middleware/Compression";
import CSPMiddleware "mo:liminal/Middleware/CSP";
import LoggingMiddleware "mo:liminal/Middleware/Logging";
import AssetsMiddleware "mo:liminal/Middleware/Assets";

actor {
    // Define your routes
    let routerConfig = {
        prefix = ?"/api";
        identityRequirement = null;
        routes = [
            Router.getQuery(
                "/public",
                func(context : RouteContext.RouteContext) : Route.HttpResponse {
                    context.buildResponse(#ok, #text("Public endpoint"))
                }
            ),
            Router.groupWithAuthorization(
                "/secure",
                [
                    Router.getQuery(
                        "/profile",
                        func(context : RouteContext.RouteContext) : Route.HttpResponse {
                            context.buildResponse(#ok, #text("Secure profile endpoint"))
                        }
                    )
                ],
                #authenticated
            )
        ]
    };

    // Initialize asset store
    stable var assetStableData = HttpAssets.init_stable_store(canisterId, initializer);
    assetStableData := HttpAssets.upgrade_stable_store(assetStableData);
    var assetStore = HttpAssets.Assets(assetStableData);

    // Create the HTTP App with middleware
    let app = Liminal.App({
        middleware = [
            // Order matters - middleware are executed in this order for requests
            // and in reverse order for responses
            CompressionMiddleware.default(),
            CORSMiddleware.default(),
            JWTMiddleware.new({
                locations = JWTMiddleware.defaultLocations;
                validation = {
                    audience = #skip;
                    issuer = #skip;
                    signature = #skip;
                    notBefore = false;
                    expiration = false;
                };
            }),
            LoggingMiddleware.new(),
            RouterMiddleware.new(routerConfig),
            CSPMiddleware.default(),
            AssetsMiddleware.new({
                store = assetStore;
            }),
        ];
        errorSerializer = Liminal.defaultJsonErrorSerializer;
        candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
    });

    // Expose standard HTTP interface
    public query func http_request(request : Liminal.RawQueryHttpRequest) : async Liminal.RawQueryHttpResponse {
        app.http_request(request)
    };

    public func http_request_update(request : Liminal.RawUpdateHttpRequest) : async Liminal.RawUpdateHttpResponse {
        await* app.http_request_update(request)
    };
}
```

## Core Concepts

### Middleware

Middleware are components that process HTTP requests and responses in a pipeline. Each middleware can:

- Handle the request and produce a response
- Pass the request to the next middleware in the pipeline
- Modify the request before passing it on
- Modify the response after the next middleware processes it

```motoko
// Example of a simple logging middleware
public func createLoggingMiddleware() : App.Middleware {
    {
        handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
            Debug.print("Query: " # HttpMethod.toText(context.method) # " " # context.request.url);
            let response = next();
            Debug.print("Response: " # debug_show(Option.map(response, func(r) = r.statusCode)));
            response
        };
        handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
            Debug.print("Update: " # HttpMethod.toText(context.method) # " " # context.request.url);
            let response = await* next();
            Debug.print("Response: " # debug_show(Option.map(response, func(r) = r.statusCode)));
            response
        };
    }
}
```

### Routing

The routing system supports:

- Path parameters (`/users/{id}`)
- Nested routes with prefixes
- HTTP method-specific handlers
- Synchronous and asynchronous handlers
- Authorization controls

```motoko
// Route configuration example
let routerConfig = {
    prefix = ?"/api"; // All routes with have prefix `/api`
    identityRequirement = null; // Default identity requirement for all routes
    routes = [
        // Group adds a prefix to all nested routes of `/users`
        Router.group(
            "/users",
            [
                Router.getQuery("/", getAllUsers), // GET + query call -> getAllUsers
                Router.postUpdate("/", createUser), // POST + update call -> createUser
                Router.getQuery("/{id}", getUserById), // GET + query call -> getUserById
                Router.putUpdateAsync("/{id}", updateUser), // PUT + update call (using async method) -> updateUser
                Router.deleteUpdate("/{id}", deleteUser) // DELETE + update call -> deleteUser
            ]
        )
    ]
};
```

### Route Path Formatting

Liminal provides a flexible and powerful path matching system that supports various path patterns:

#### Static Paths

Basic routes with fixed path segments:

```motoko
Router.getQuery("/users", getAllUsers)
Router.getQuery("/api/products", getProducts)
```

#### Path Parameters

Capture dynamic values from the URL using curly braces:

```motoko
// Matches: /users/123, /users/abc
Router.getQuery("/users/{id}", getUserById)

// Multiple parameters
// Matches: /blog/2023/05/hello-world
Router.getQuery("/blog/{year}/{month}/{slug}", getBlogPost)
```

Access parameters in your handler:

```motoko
func getUserById(context : RouteContext.RouteContext) : Route.HttpResponse {
    let userId : Text = context.getRouteParam("id"); // or getRouteParamOrNull("id")
    // ...
}
```

#### Wildcard Segments

##### Single Wildcard (\*)

Matches exactly one segment in the path:

```motoko
// Matches: /files/document.txt, /files/image.jpg
// Does NOT match: /files/folder/document.txt
Router.getQuery("/files/*", getFile)

// Can appear in the middle of a path
// Matches: /files/document.txt/versions
Router.getQuery("/files/*/versions", getFileVersions)
```

##### Multi Wildcard (\*\*)

Matches any number of segments (including zero):

```motoko
// Matches: /api, /api/users, /api/users/123/profile
Router.getQuery("/api/**", handleApiRequest)

// Can appear in the middle of a path
// Matches: /api/info, /api/users/123/info
Router.getQuery("/api/**/info", getApiInfo)
```

### HTTP Context

The `HttpContext` provides access to request details:

- Path and query parameters
- Headers
- Request body (with JSON parsing helpers)
- HTTP method
- Identity (for authentication)

```motoko
public func handleRequest(context : RouteContext.RouteContext) : Route.HttpResponse {
    // Access route parameters
    let id = context.getRouteParam("id");

    // Access query parameters
    let filter = context.getQueryParam("filter");

    // Access headers
    let authorization = context.getHeader("Authorization");

    // Get authenticated identity
    let identity = context.getIdentity();

    // Parse JSON body
    let result = context.parseJsonBody<CreateRequest>(deserializeCreateRequest);

    // Return a response
    context.buildResponse(#ok, #content(#Record([("id", #number(#int(id)))])));
}
```

### Content Negotiation

The framework includes built-in content negotiation that converts Candid data to various formats based on the client's Accept header:

```motoko
// Return data using automatic content negotiation
context.buildResponse(#ok, #content(myCandidData))
```

The `#content` response kind takes a Candid representation of your data and uses the client's Accept header to determine the appropriate format (JSON, CBOR, Candid, or XML). This works around Motoko's lack of reflection by using Candid as the common intermediate format - Motoko's `to_candid` converts your types to Candid, which is then converted to the requested format.

### File Uploads

Liminal provides built-in support for handling file uploads via multipart/form-data requests. The file upload functionality allows you to easily access uploaded files within your route handlers:

```motoko
func(context : RouteContext.RouteContext) : Route.HttpResponse {
    // Access all uploaded files
    let files = context.getUploadedFiles();

    // Process each uploaded file
    for (file in files.vals()) {
        // Each file has: fieldName, filename, contentType, size, and content
        let fieldName = file.fieldName;  // Form field name
        let filename = file.filename;    // Original filename
        let contentType = file.contentType;  // MIME type
        let size = file.size;            // Size in bytes
        let content = file.content;      // Blob containing file data

        // Process the file as needed...
    };

    return context.buildResponse(#ok, #text("Upload successful"));
}
```

The `getUploadedFiles()` method automatically parses the multipart/form-data content from the request and returns information about each uploaded file. This makes it straightforward to handle file uploads without needing to manually parse complex multipart boundaries and headers.

## Built-in Middleware

### Router

Handles route matching and dispatching to the appropriate handler.

```motoko
RouterMiddleware.new(routerConfig)
```

### CORS

Configures Cross-Origin Resource Sharing.

```motoko
CORSMiddleware.default()

// Or with custom options
CORSMiddleware.new({
    allowOrigins = ["https://yourdomain.com"];
    allowMethods = [#get, #post, #put, #delete];
    allowHeaders = ["Content-Type", "Authorization"];
    maxAge = ?86400;
    allowCredentials = true;
    exposeHeaders = ["Content-Length"];
})
```

### JWT

Handles JSON Web Token authentication and parsing.

```motoko
JWTMiddleware.new({
    locations = [#header("Authorization"), #cookie("jwt"), #queryString("token")];
    validation = {
        audience = #skip;
        issuer = #skip;
        signature = #skip;
        notBefore = false;
        expiration = false;
    };
})

// Or use default settings
JWTMiddleware.new({
    locations = JWTMiddleware.defaultLocations;
    validation = {
        audience = #skip;
        issuer = #skip;
        signature = #skip;
        notBefore = false;
        expiration = false;
    };
})
```

### Compression

Automatically compresses HTTP responses for better performance.

```motoko
CompressionMiddleware.default()

// Or with custom options
CompressionMiddleware.new({
    minSize = 1024; // Minimum size in bytes to apply compression
    mimeTypes = [
        "text/",
        "application/javascript",
        "application/json",
        "application/xml"
    ];
    skipCompressionIf = null;
})
```

### Rate Limiter

Protects your API from abuse by limiting request rates.

```motoko
RateLimiterMiddleware.new({
    limit = 100; // Maximum requests per window
    windowSeconds = 60; // Time window in seconds
    includeResponseHeaders = true;
    limitExceededMessage = ?"Rate limit exceeded. Try again later.";
    keyExtractor = #ip; // Use client IP as the rate limit key
    skipIf = null;
})
```

### Require Authentication

Enforces authentication requirements for specific routes.

```motoko
RequireAuthMiddleware.new(#authenticated)

// Or with a custom validation function
RequireAuthMiddleware.new(#custom(func(identity : Identity) : Bool {
    // Custom validation logic
    let ?id = identity.getId() else return false;
    // Check roles, permissions, etc.
    return true;
}))
```

### Assets

Serves static files with configurable caching.

```motoko
AssetsMiddleware.new({
    prefix = ?"/static";
    store = assetStore;
    indexAssetPath = ?"/index.html";
    cache = {
        default = #public_({
            immutable = false;
            maxAge = 3600;
        });
        rules = [
            {
                pattern = "/*.css";
                cache = #public_({
                    immutable = true;
                    maxAge = 86400;
                });
            }
        ];
    };
})
```

### CSP (Content Security Policy)

Configures security policies for your application.

```motoko
CSPMiddleware.default()

// Or with custom options
CSPMiddleware.new({
    defaultSrc = ["'self'"];
    scriptSrc = ["'self'", "'unsafe-inline'", "https://trusted-scripts.com"];
    connectSrc = ["'self'", "https://api.example.com"];
    // Additional CSP directives...
})
```

## Assets Integration

Liminal provides a wrapper around the Internet Computer's asset canister functionality:

```motoko
// Initialize asset store
stable var assetStableData = HttpAssets.init_stable_store(canisterId, initializer);
assetStableData := HttpAssets.upgrade_stable_store(assetStableData);
var assetStore = HttpAssets.Assets(assetStableData);
var assetCanister = AssetCanister.AssetCanister(assetStore);

...

// Use in middleware
AssetsMiddleware.new({
    prefix = null;
    store = assetStore;
    indexAssetPath = ?"/index.html";
    // Cache configuration...
})

...

// Expose asset canister methods
public shared query func get(args : Assets.GetArgs) : async Assets.EncodedAsset {
    assetCanister.get(args);
}

// Additional asset canister methods...
```

## Error Handling

Custom error handling can be configured via the app's `errorSerializer`:

```motoko
let app = Liminal.App({
    middleware = [ /* ... */ ];
    errorSerializer = func(error : HttpContext.HttpError) : HttpContext.ErrorSerializerResponse {
        let body = #object_([
            ("error", #string("Custom Error")),
            ("code", #number(#int(error.statusCode))),
            ("message", #string(Option.get(error.message, ""))),
            // Additional error fields...
        ])
        |> Json.stringify(_, null)
        |> Text.encodeUtf8(_);

        {
            body = ?body;
            headers = [("content-type", "application/json")];
        };
    };
    candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
});
```

The `candidRepresentationNegotiator` handles the conversion of Candid values to different representations based on the client's Accept header. The default implementation supports converting to JSON, CBOR, Candid, and XML formats.

## Testing

Run the test suite with:

```bash
mops test
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
