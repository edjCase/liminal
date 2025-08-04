import UrlStore "UrlStore";
import Json "mo:json";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import BaseX "mo:base-x-encoder";
import UrlKit "mo:url-kit";

module {

  public func deserializeCreateRequest(json : Json.Json) : Result.Result<UrlStore.CreateRequest, Text> {
    let originalUrl : Text = switch (Json.getAsText(json, "url")) {
      case (#ok(url)) url;
      case (#err(e)) return #err("Error with field 'url': " # debug_show (e));
    };

    let customSlug = switch (Json.getAsText(json, "slug")) {
      case (#ok(slug)) ?slug;
      case (#err(#pathNotFound)) null; // Allow customSlug to be optional
      case (#err(e)) return #err("Error with field 'slug': " # debug_show (e));
    };

    #ok({
      originalUrl = originalUrl;
      customSlug = customSlug;
    });
  };
};
