import HttpContext "./HttpContext";
import Types "./Types";
import Nat "mo:core@1/Nat";
import Blob "mo:core@1/Blob";
import Nat16 "mo:core@1/Nat16";
import HttpAssets "mo:http-assets@0";

module {
  public type Seconds = Nat;

  public type Config = {
    store : HttpAssets.Assets;
  };

  public type StreamingStrategy = {
    #none;
    #callback : shared query (Blob) -> async Types.StreamingCallbackResponse;
  };

  public type StreamResult = {
    kind : Types.StreamingStrategy;
    response : Types.HttpResponse;
  };

  /// Serves static assets through an asset canister integration.
  /// Attempts to serve the requested path from the configured asset store and returns
  /// an appropriate response or indicates no match was found.
  ///
  /// ```motoko
  /// import Assets "mo:liminal/Assets";
  ///
  /// let config = {
  ///     store = assetCanister; // Your asset canister reference
  ///     fallbackPath = ?"/index.html"; // SPA fallback
  /// };
  ///
  /// switch (Assets.serve(httpContext, config)) {
  ///     case (#response(response)) {
  ///         // Asset found and served
  ///         response
  ///     };
  ///     case (#noMatch) {
  ///         // No asset found, continue to other handlers
  ///         httpContext.buildResponse(#notFound, #error(#message("Not found")))
  ///     };
  /// }
  /// ```
  public func serve(
    httpContext : HttpContext.HttpContext,
    options : Config,
  ) : {
    #response : Types.HttpResponse;
    #noMatch;
  } {

    let request = {
      httpContext.request with
      certificate_version = httpContext.certificateVersion;
    };
    switch (options.store.http_request(request)) {
      case (#err(e)) {
        httpContext.log(#error, "Error serving asset: " # debug_show (e));
        return #noMatch;
      }; // TODO handle error
      case (#ok(response)) {
        switch (response.streaming_strategy) {
          case (null) ();
          case (?streamingStrategy) switch (streamingStrategy) {
            case (#Callback(callback)) {
              return #response({
                statusCode = Nat16.toNat(response.status_code);
                headers = response.headers;
                body = ?response.body;
                streamingStrategy = ?#callback(callback);
              });
            };
          };
        };
        #response({
          statusCode = Nat16.toNat(response.status_code);
          headers = response.headers;
          body = ?response.body;
          streamingStrategy = null;
        });
      };
    };
  };

};
