import UrlStore "UrlStore";
import Json "mo:json";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import BaseX "mo:base-x-encoder";

module {

  public func deserializeCreateRequest(json : Json.Json) : Result.Result<UrlStore.CreateRequest, Text> {
    let originalUrl = switch (Json.getAsText(json, "originalUrl")) {
      case (#ok(url)) url;
      case (#err(e)) return #err("Error with field 'originalUrl': " # debug_show (e));
    };

    let customSlug = switch (Json.getAsText(json, "customSlug")) {
      case (#ok(slug)) ?slug;
      case (#err(#pathNotFound)) null; // Allow customSlug to be optional
      case (#err(e)) return #err("Error with field 'customSlug': " # debug_show (e));
    };

    #ok({
      originalUrl = originalUrl;
      customSlug = customSlug;
    });
  };
};
