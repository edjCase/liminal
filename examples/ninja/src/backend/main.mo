import Liminal "mo:liminal";
import Principal "mo:new-base/Principal";
import Blob "mo:new-base/Blob";
import { ic } "mo:ic";
import CORSMiddleware "mo:liminal/Middleware/CORS";
import RouterMiddleware "mo:liminal/Middleware/Router";
import CompressionMiddleware "mo:liminal/Middleware/Compression";
import Router "mo:liminal/Router";
import GhostRouter "GhostRouter";
import GhostStore "GhostStore";

shared ({ caller = initializer }) actor class Actor() = self {
  stable var ghostStableData : GhostStore.StableData = {
    ghosts = [];
  };

  var ghostStore = GhostStore.Store(ghostStableData);

  let ghostRouter = GhostRouter.Router(ghostStore);

  // Upgrade methods

  system func preupgrade() {
    ghostStableData := ghostStore.toStableData();
  };

  system func postupgrade() {
    ghostStore := GhostStore.Store(ghostStableData);
  };

  let routerConfig : RouterMiddleware.Config = {
    prefix = null;
    identityRequirement = null;
    routes = [
      Router.group(
        "/ghosts",
        [
          Router.getQuery("/", ghostRouter.get),
          Router.postUpdate("/", ghostRouter.create),
          Router.getQuery("/{id}", ghostRouter.getById),
          Router.postUpdate("/{id}", ghostRouter.update),
          Router.deleteUpdate("/{id}", ghostRouter.delete),
        ],
      )
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
