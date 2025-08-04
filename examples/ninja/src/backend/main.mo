import Liminal "mo:liminal";
import CORSMiddleware "mo:liminal/Middleware/CORS";
import RouterMiddleware "mo:liminal/Middleware/Router";
import CompressionMiddleware "mo:liminal/Middleware/Compression";
import Router "mo:liminal/Router";
import UrlRouter "UrlRouter";
import UrlStore "UrlStore";

shared ({ caller = initializer }) actor class Actor() = self {
  stable var urlStableData : UrlStore.StableData = {
    urls = [];
    slugMap = [];
    nextId = 1;
  };

  var urlStore = UrlStore.Store(urlStableData);

  let urlRouter = UrlRouter.Router(urlStore);

  // Upgrade methods

  system func preupgrade() {
    urlStableData := urlStore.toStableData();
  };

  system func postupgrade() {
    urlStore := UrlStore.Store(urlStableData);
  };

  let routerConfig : RouterMiddleware.Config = {
    prefix = null;
    identityRequirement = null;
    routes = [
      // URL management endpoints
      Router.getQuery("/urls", urlRouter.getAllUrls),
      Router.postUpdate("/shorten", urlRouter.createShortUrl),
      Router.deleteUpdate("/urls/{id}", urlRouter.deleteUrl),

      // Short URL redirect and stats
      Router.getQuery("/s/{shortCode}", urlRouter.redirect),
      Router.getQuery("/s/{shortCode}/stats", urlRouter.getStats),
    ];
  };

  // Http App
  let app = Liminal.App({
    middleware = [
      CompressionMiddleware.default(),
      CORSMiddleware.default(),
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
