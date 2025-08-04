import Route "mo:liminal/Route";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import UrlStore "UrlStore";
import Serializer "Serializer";
import Serde "mo:serde";
import RouteContext "mo:liminal/RouteContext";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Iter "mo:base/Iter";

module {

  public class Router(store : UrlStore.Store) = self {

    public func getAllUrls(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
      let urls = store.getAllUrls();
      routeContext.buildResponse(#ok, #content(toCandid(to_candid (urls))));
    };

    public func redirect(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
      let shortCode = routeContext.getRouteParam("shortCode");

      switch (store.incrementClicks(shortCode)) {
        case null {
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
        case null {
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
          let ?body : ?Text = routeContext.parseUtf8Body() else Debug.trap("Failed to decode request body as UTF-8");
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
      let ?body : ?Text = routeContext.parseUtf8Body() else Debug.trap("Failed to decode request body as UTF-8");
      var originalUrl = "";
      var customSlug : ?Text = null;

      // Simple form parsing - split by & and then by =
      let pairs = Text.split(body, #char('&'));
      for (pair in pairs) {
        let keyValue = Text.split(pair, #char('='));
        let keyValueArray = Iter.toArray(keyValue);
        if (keyValueArray.size() == 2) {
          let key = urlDecode(keyValueArray[0]);
          let value = urlDecode(keyValueArray[1]);

          if (key == "url") {
            originalUrl := value;
          } else if (key == "slug") {
            customSlug := ?value;
          };
        };
      };

      { originalUrl = originalUrl; customSlug = customSlug };
    };

    // Simple URL decode function
    private func urlDecode(text : Text) : Text {
      // For now, just handle basic cases
      let decoded = Text.replace(text, #text("+"), " ");
      let decoded2 = Text.replace(decoded, #text("%20"), " ");
      decoded2;
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
      Debug.print("Encoding URL Candid");
      switch (Serde.Candid.decode(value, urlKeys, options)) {
        case (#err(e)) {
          Debug.print("Failed to decode URL Candid. Error: " # e);
          Debug.trap("Failed to decode URL Candid. Error: " # e);
        };
        case (#ok(candid)) {
          if (candid.size() != 1) {
            Debug.print("Invalid Candid response. Expected 1 element, got " # Nat.toText(candid.size()));
            Debug.trap("Invalid Candid response. Expected 1 element, got " # Nat.toText(candid.size()));
          };
          candid[0];
        };
      };
    };
  };
};
