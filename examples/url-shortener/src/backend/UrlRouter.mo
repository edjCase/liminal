import Route "mo:liminal/Route";
import Nat "mo:core@1/Nat";
import Debug "mo:core@1/Debug";
import UrlStore "UrlStore";
import Serializer "Serializer";
import Serde "mo:serde";
import RouteContext "mo:liminal/RouteContext";
import Text "mo:core@1/Text";
import Result "mo:core@1/Result";
import Iter "mo:core@1/Iter";
import UrlKit "mo:url-kit@3";
import Runtime "mo:core@1/Runtime";

module {

  public class Router(
    store : UrlStore.Store
  ) = self {

    public func getAllUrls(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
      let urls = store.getAllUrls();
      routeContext.buildResponse(#ok, #content(toCandid(to_candid (urls))));
    };

    public func redirect<system>(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
      let shortCode = routeContext.getRouteParam("shortCode");

      switch (store.incrementClicks(shortCode)) {
        case (null) {
          routeContext.buildResponse(#notFound, #error(#message("Short URL not found")));
        };
        case (?originalUrl) {
          routeContext.buildResponse(
            #found, // 302 redirect
            #custom({
              body = Text.encodeUtf8("Redirecting to " # originalUrl);
              headers = [
                ("Location", originalUrl),
                ("Cache-Control", "no-cache"),
              ];
            }),
          );
        };
      };
    };

    public func getStats(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
      let shortCode = routeContext.getRouteParam("shortCode");

      switch (store.getUrlByShortCode(shortCode)) {
        case (null) {
          routeContext.buildResponse(#notFound, #error(#message("Short URL not found")));
        };
        case (?url) {
          routeContext.buildResponse(#ok, #content(toCandid(to_candid (url))));
        };
      };
    };

    public func createShortUrl<system>(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
      Debug.print("Creating short URL...");

      // Handle different content types
      let contentType = routeContext.httpContext.getHeader("content-type");

      let createRequest : UrlStore.CreateRequest = switch (contentType) {
        case (?"application/x-www-form-urlencoded") {
          // Parse form data: url=...&slug=...
          parseFormData(routeContext);
        };
        case (?"text/plain") {
          // Simple text body is just the URL
          let ?body : ?Text = routeContext.parseUtf8Body() else Runtime.trap("Failed to decode request body as UTF-8");
          { originalUrl = body; customSlug = null };
        };
        case _ {
          // Try JSON
          switch (routeContext.parseJsonBody<UrlStore.CreateRequest>(Serializer.deserializeCreateRequest)) {
            case (#err(e)) return routeContext.buildResponse(#badRequest, #error(#message("Failed to parse request. Error: " # e)));
            case (#ok(req)) req;
          };
        };
      };

      switch (store.create(createRequest)) {
        case (#err(errorMessage)) {
          routeContext.buildResponse(#badRequest, #error(#message(errorMessage)));
        };
        case (#ok(url)) {
          routeContext.buildResponse(#created, #content(toCandid(to_candid (url))));
        };
      };
    };

    public func deleteUrl<system>(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
      let idText = routeContext.getRouteParam("id");
      let ?id = Nat.fromText(idText) else return routeContext.buildResponse(#badRequest, #error(#message("Invalid id '" # idText # "', must be a positive integer")));

      if (store.delete(id)) {
        routeContext.buildResponse(#noContent, #empty);
      } else {
        routeContext.buildResponse(#notFound, #error(#message("URL not found")));
      };
    };

    // Helper function to parse form data
    private func parseFormData(routeContext : RouteContext.RouteContext) : UrlStore.CreateRequest {
      let ?body : ?Text = routeContext.parseUtf8Body() else Runtime.trap("Failed to decode request body as UTF-8");
      var originalUrl = "";
      var customSlug : ?Text = null;

      // Simple form parsing - split by & and then by =
      let pairs = Text.split(body, #char('&'));
      for (pair in pairs) {
        let keyValue = Text.split(pair, #char('='));
        let keyValueArray = Iter.toArray(keyValue);
        if (keyValueArray.size() == 2) {
          let key = switch (UrlKit.decodeText(keyValueArray[0])) {
            case (#ok(decoded)) decoded;
            case (#err(e)) Runtime.trap("Failed to decode key: " # e);
          };
          let value = switch (UrlKit.decodeText(keyValueArray[1])) {
            case (#ok(decoded)) decoded;
            case (#err(e)) Runtime.trap("Failed to decode value: " # e);
          };

          if (key == "url") {
            originalUrl := value;
          } else if (key == "slug") {
            customSlug := ?value;
          };
        };
      };

      { originalUrl = originalUrl; customSlug = customSlug };
    };

    func toCandid(value : Blob) : Serde.Candid.Candid {
      let urlKeys = ["id", "originalUrl", "shortCode", "clicks", "createdAt"];
      let renamedUrlKeys = [];
      let options : ?Serde.Options = ?{
        renameKeys = renamedUrlKeys;
        blob_contains_only_values = false;
        types = null;
        use_icrc_3_value_type = false;
      };
      switch (Serde.Candid.decode(value, urlKeys, options)) {
        case (#err(e)) {
          Debug.print("Failed to decode URL Candid. Error: " # e);
          Runtime.trap("Failed to decode URL Candid. Error: " # e);
        };
        case (#ok(candid)) {
          if (candid.size() != 1) {
            Debug.print("Invalid Candid response. Expected 1 element, got " # Nat.toText(candid.size()));
            Runtime.trap("Invalid Candid response. Expected 1 element, got " # Nat.toText(candid.size()));
          };
          candid[0];
        };
      };
    };
  };
};
