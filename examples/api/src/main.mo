import Liminal "mo:liminal";
import UserHandler "UserHandler";
import UserRouter "UserRouter";
import Principal "mo:new-base/Principal";
import Blob "mo:new-base/Blob";
import LoggingMiddleware "LoggingMiddleware";
import { ic } "mo:ic";
import CORSMiddleware "mo:liminal/Middleware/CORS";
import RouterMiddleware "mo:liminal/Middleware/Router";
import CSPMiddleware "mo:liminal/Middleware/CSP";
import JWTMiddleware "mo:liminal/Middleware/JWT";
import CompressionMiddleware "mo:liminal/Middleware/Compression";
import SessionMiddleware "mo:liminal/Middleware/Session";
// import OAuthMiddleware "mo:liminal/Middleware/OAuth";
import Router "mo:liminal/Router";
import RouteContext "mo:liminal/RouteContext";
import Iter "mo:new-base/Iter";
import Text "mo:new-base/Text";
import Nat "mo:new-base/Nat";
import FileUpload "mo:liminal/FileUpload";

shared ({ caller = initializer }) actor class Actor() = self {

    stable var userStableData : UserHandler.StableData = {
        users = [];
    };

    var userHandler = UserHandler.Handler(userStableData);

    let userRouter = UserRouter.Router(userHandler);

    // Upgrade methods

    system func preupgrade() {
        userStableData := userHandler.toStableData();
    };

    system func postupgrade() {
        userHandler := UserHandler.Handler(userStableData);
    };

    let routerConfig : RouterMiddleware.Config = {
        prefix = null;
        identityRequirement = null;
        routes = [
            Router.groupWithAuthorization(
                "/users",
                [
                    Router.getQuery("/", userRouter.get),
                    Router.postUpdate("/", userRouter.create),
                    Router.getQuery("/{id}", userRouter.getById),
                ],
                #authenticated,
            ),
            Router.getQuery(
                "/upload",
                func(routeContext : RouteContext.RouteContext) : Liminal.HttpResponse {
                    routeContext.buildResponse(#ok, #html("<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>File Upload</title>
</head>
<body>
    <form action=\"/api/upload\" method=\"POST\" enctype=\"multipart/form-data\">
        <div class=\"form-group\">
            <label for=\"file\">Select file to upload:</label>
            <input type=\"file\" id=\"file\" name=\"file\">
        </div>
        <button type=\"submit\" class=\"btn\">Upload File</button>
    </form>
</body>
</html>"));
                },
            ),
            Router.postUpdate(
                "/upload",
                func<system>(routeContext : RouteContext.RouteContext) : Liminal.HttpResponse {
                    let files = routeContext.getUploadedFiles();

                    if (files.size() == 0) {
                        return routeContext.buildResponse(
                            #badRequest,
                            #error(#message("No files were uploaded")),
                        );
                    };

                    // Process each uploaded file
                    let responseData = files.vals()
                    |> Iter.map(
                        _,
                        func(file : FileUpload.UploadedFile) : Text {
                            "Received file: " # file.filename #
                            " (Size: " # Nat.toText(file.size) #
                            " bytes, Type: " # file.contentType # ")";
                        },
                    )
                    |> Text.join("\n", _);

                    // Return success response
                    routeContext.buildResponse(#ok, #text(responseData));
                },
            ),
            Router.getAsyncUpdate(
                "/hash",
                func(routeContext : RouteContext.RouteContext) : async* Liminal.HttpResponse {
                    let result = await ic.canister_info({
                        canister_id = Principal.fromActor(self);
                        num_requested_changes = ?0;
                    });
                    let hashJson = switch (result.module_hash) {
                        case (null) #Null;
                        case (?hash) #Text(debug_show (Blob.toArray(hash)));
                    };
                    routeContext.buildResponse(#ok, #content(#Record([("hash", hashJson)])));
                },
            ),
        ];
    };

    // let oauthConfig : OAuthMiddleware.Config = {
    //     clientId = "Ov23liYZ5V22rjHKThEN";
    //     clientSecret = "52716f17326479e63509d5d74879ed3493e4235e";
    //     redirectUri = "http://uxrrr-q7777-77774-qaaaq-cai.raw.localhost:4943/auth/callback";
    //     authorizationEndpoint = OAuthMiddleware.GitHub.authorizationEndpoint;
    //     tokenEndpoint = OAuthMiddleware.GitHub.tokenEndpoint;
    //     userInfoEndpoint = OAuthMiddleware.GitHub.userInfoEndpoint;
    //     scopes = ["read:user", "user:email"];
    //     usePKCE = false;
    //     stateStore = OAuthMiddleware.inMemoryStateStore();
    // };

    // Http App
    let app = Liminal.App({
        middleware = [
            LoggingMiddleware.new(),
            SessionMiddleware.inMemoryDefault(),
            CompressionMiddleware.default(),
            CORSMiddleware.default(),
            // OAuthMiddleware.new(oauthConfig),
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
            // RequireAuthMiddleware.new(#authenticated),
            RouterMiddleware.new(routerConfig),
            CSPMiddleware.default(),
        ];
        errorSerializer = Liminal.defaultJsonErrorSerializer;
        candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
        logger = Liminal.debugLogger;
    });

    // Http server methods

    public query func http_request(request : Liminal.RawQueryHttpRequest) : async Liminal.RawQueryHttpResponse {
        app.http_request(request);
    };

    public func http_request_update(request : Liminal.RawUpdateHttpRequest) : async Liminal.RawUpdateHttpResponse {
        await* app.http_request_update(request);
    };

};
