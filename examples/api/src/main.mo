import Liminal "mo:liminal";
import UserHandler "UserHandler";
import UserRouter "UserRouter";
import Principal "mo:core@1/Principal";
import LoggingMiddleware "LoggingMiddleware";
import { ic } "mo:ic@3";
import CORSMiddleware "mo:liminal/Middleware/CORS";
import RouterMiddleware "mo:liminal/Middleware/Router";
import JWTMiddleware "mo:liminal/Middleware/JWT";
import CompressionMiddleware "mo:liminal/Middleware/Compression";
import SessionMiddleware "mo:liminal/Middleware/Session";
import OAuthMiddleware "mo:liminal/Middleware/OAuth";
import Router "mo:liminal/Router";
import RouteContext "mo:liminal/RouteContext";
import FileUploader "FileUploader";

shared ({ caller = initializer }) persistent actor class Actor() = self {

  var userStableData : UserHandler.StableData = {
    users = [];
  };

  transient let userHandler = UserHandler.Handler(userStableData);

  transient let userRouter = UserRouter.Router(userHandler);

  // Upgrade methods

  system func preupgrade() {
    userStableData := userHandler.toStableData();
  };

  transient let routerConfig : RouterMiddleware.Config = {
    prefix = null;
    identityRequirement = null;
    routes = [
      Router.groupWithAuthorization(
        "/users",
        [
          Router.get("/", #query_(userRouter.get)),
          Router.post("/", #update(#sync(userRouter.create))),
          Router.get("/{id}", #query_(userRouter.getById)),
        ],
        #authenticated,
      ),
      Router.get("/upload", #query_(FileUploader.getUploadFormHtml)),
      Router.post("/upload", #update(#sync(FileUploader.handleUpload))),
      Router.get(
        "/hash",
        #update(
          #async_(
            func(routeContext : RouteContext.RouteContext) : async* Liminal.HttpResponse {
              let result = await ic.canister_info({
                canister_id = Principal.fromActor(self);
                num_requested_changes = ?0;
              });
              let hashJson = switch (result.module_hash) {
                case (null) #Null;
                case (?hash) #Text(debug_show (hash));
              };
              routeContext.buildResponse(#ok, #content(#Record([("hash", hashJson)])));
            }
          )
        ),
      ),
    ];
  };

  var accessTokenOrNull : ?Text = null;

  transient let oauthConfig : OAuthMiddleware.Config = {
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
  transient let app = Liminal.App({
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
    urlNormalization = {
      pathIsCaseSensitive = false;
      preserveTrailingSlash = false;
      queryKeysAreCaseSensitive = false;
      removeEmptyPathSegments = true;
      resolvePathDotSegments = true;
      usernameIsCaseSensitive = false;
    };
  });

  // Http server methods

  public query func http_request(request : Liminal.RawQueryHttpRequest) : async Liminal.RawQueryHttpResponse {
    app.http_request(request);
  };

  public func http_request_update(request : Liminal.RawUpdateHttpRequest) : async Liminal.RawUpdateHttpResponse {
    await* app.http_request_update(request);
  };

};
