import Liminal "mo:liminal";
import UserHandler "UserHandler";
import UserRouter "UserRouter";
import Principal "mo:new-base/Principal";
import Blob "mo:new-base/Blob";
import LoggingMiddleware "LoggingMiddleware";
import { ic } "mo:ic";
import CORSMiddleware "mo:liminal/Middleware/CORS";
import RouterMiddleware "mo:liminal/Middleware/Router";
import JWTMiddleware "mo:liminal/Middleware/JWT";
import CompressionMiddleware "mo:liminal/Middleware/Compression";
import SessionMiddleware "mo:liminal/Middleware/Session";
import OAuthMiddleware "mo:liminal/Middleware/OAuth";
import Router "mo:liminal/Router";
import RouteContext "mo:liminal/RouteContext";
import FileUploader "FileUploader";

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
            Router.getQuery("/upload", FileUploader.getUploadFormHtml),
            Router.postUpdate("/upload", FileUploader.handleUpload),
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

    stable var accessTokenOrNull : ?Text = null;

    let oauthConfig : OAuthMiddleware.Config = {
        providers = [{
            OAuthMiddleware.GitHub with
            name = "GitHub";
            clientId = "Ov23liYZ5V22rjHKThEN";
            scopes = ["read:user", "user:email"];
            // PKCE is now mandatory for security - no client secrets needed
        }];
        siteUrl = "http://uxrrr-q7777-77774-qaaaq-cai.raw.localhost:4943";
        store = OAuthMiddleware.inMemoryStore();
        onLogin = func(context : Liminal.HttpContext, data : OAuthMiddleware.LoginData) : async* Liminal.HttpResponse {
            accessTokenOrNull := ?data.tokenInfo.accessToken;
            context.buildRedirectResponse("/post-login", false);
        };
        onLogout = func(context : Liminal.HttpContext, _ : OAuthMiddleware.LogoutData) : async* Liminal.HttpResponse {
            accessTokenOrNull := null;
            context.buildRedirectResponse("/post-logout", false);
        };
    };

    // Http App
    let app = Liminal.App({
        middleware = [
            LoggingMiddleware.new(),
            SessionMiddleware.inMemoryDefault(),
            CompressionMiddleware.default(),
            CORSMiddleware.default(),
            OAuthMiddleware.new(oauthConfig),
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
            RouterMiddleware.new(routerConfig),
        ];
        errorSerializer = Liminal.defaultJsonErrorSerializer;
        candidRepresentationNegotiator = Liminal.defaultCandidRepresentationNegotiator;
        logger = Liminal.buildDebugLogger(#info);
    });

    // Http server methods

    public query func http_request(request : Liminal.RawQueryHttpRequest) : async Liminal.RawQueryHttpResponse {
        app.http_request(request);
    };

    public func http_request_update(request : Liminal.RawUpdateHttpRequest) : async Liminal.RawUpdateHttpResponse {
        await* app.http_request_update(request);
    };

};
