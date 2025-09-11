import UrlStore "UrlStore";
import Json "mo:json@1";
import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Blob "mo:core@1/Blob";
import BaseX "mo:base-x-encoder@2";
import UrlKit "mo:url-kit@3";

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
