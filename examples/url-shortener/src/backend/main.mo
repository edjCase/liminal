import Liminal "mo:liminal";
import RouterMiddleware "mo:liminal/Middleware/Router";
import Router "mo:liminal/Router";
import UrlRouter "UrlRouter";
import UrlStore "UrlStore";
import BTree "mo:stableheapbtreemap/BTree";

shared ({ caller = initializer }) persistent actor class Actor() = self {
  var urlStableData : UrlStore.StableData = {
    urls = BTree.init<Nat, UrlStore.Url>(null);
    nextId = 1;
  };

  transient var urlStore = UrlStore.Store(urlStableData);

  transient let urlRouter = UrlRouter.Router(urlStore);

  // Upgrade methods

  system func preupgrade() {
    urlStableData := urlStore.toStableData();
  };

  system func postupgrade() {
    urlStore := UrlStore.Store(urlStableData);
  };

  transient let routerConfig : RouterMiddleware.Config = {
    prefix = null;
    identityRequirement = null;
    routes = [
      // URL management endpoints
      Router.getQuery("/urls", urlRouter.getAllUrls),
      Router.postUpdate("/shorten", urlRouter.createShortUrl),
      Router.deleteUpdate("/urls/{id}", urlRouter.deleteUrl),

      // Short URL redirect and stats
      Router.getUpdate("/s/{shortCode}", urlRouter.redirect),
      Router.getQuery("/s/{shortCode}/stats", urlRouter.getStats),
    ];
  };

  // Http App
  transient let app = Liminal.App({
    middleware = [
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
