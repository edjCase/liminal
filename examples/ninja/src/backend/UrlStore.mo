import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Random "mo:base/Random";
import Char "mo:base/Char";

module {
  public type StableData = {
    urls : [Url];
    slugMap : [(Text, Nat)];
    nextId : Nat;
  };

  public type Url = {
    id : Nat;
    originalUrl : Text;
    shortCode : Text;
    clicks : Nat;
    createdAt : Int;
  };

  public type CreateRequest = {
    originalUrl : Text;
    customSlug : ?Text;
  };

  public type UrlStats = {
    id : Nat;
    originalUrl : Text;
    shortCode : Text;
    clicks : Nat;
    createdAt : Int;
  };

  public class Store(stableData : StableData) = self {

    var nextId = stableData.nextId;

    var urlMap = stableData.urls.vals()
    |> Iter.map<Url, (Nat, Url)>(
      _,
      func(url : Url) : (Nat, Url) {
        (url.id, url);
      },
    )
    |> HashMap.fromIter<Nat, Url>(
      _,
      stableData.urls.size(),
      Nat.equal,
      func(nat : Nat) : Nat32 {
        Nat32.fromIntWrap(nat);
      },
    );

    var slugToIdMap = HashMap.fromIter<Text, Nat>(
      stableData.slugMap.vals(),
      stableData.slugMap.size(),
      Text.equal,
      Text.hash,
    );

    public func getAllUrls() : [Url] {
      urlMap.vals() |> Iter.toArray(_);
    };

    public func getUrlByShortCode(shortCode : Text) : ?Url {
      let ?id = slugToIdMap.get(shortCode) else return null;
      urlMap.get(id);
    };

    public func incrementClicks(shortCode : Text) : ?Text {
      let ?url = getUrlByShortCode(shortCode) else return null;

      let updatedUrl : Url = {
        id = url.id;
        originalUrl = url.originalUrl;
        shortCode = url.shortCode;
        clicks = url.clicks + 1;
        createdAt = url.createdAt;
      };

      urlMap.put(url.id, updatedUrl);
      ?url.originalUrl;
    };

    public func create(request : CreateRequest) : Result.Result<Url, Text> {
      // Validate original URL
      if (not isValidUrl(request.originalUrl)) {
        return #err("Invalid URL format");
      };

      // Generate or validate short code
      let shortCode = switch (request.customSlug) {
        case (?slug) {
          if (not isValidSlug(slug)) {
            return #err("Invalid custom slug. Use only letters, numbers, hyphens, and underscores");
          };
          if (slugToIdMap.get(slug) != null) {
            return #err("Custom slug already exists");
          };
          slug;
        };
        case null {
          generateShortCode();
        };
      };

      let newUrl : Url = {
        id = nextId;
        originalUrl = request.originalUrl;
        shortCode = shortCode;
        clicks = 0;
        createdAt = Time.now();
      };

      nextId += 1;
      urlMap.put(newUrl.id, newUrl);
      slugToIdMap.put(shortCode, newUrl.id);

      #ok(newUrl);
    };

    public func delete(id : Nat) : Bool {
      switch (urlMap.get(id)) {
        case null false;
        case (?url) {
          urlMap.delete(id);
          slugToIdMap.delete(url.shortCode);
          true;
        };
      };
    };

    public func toStableData() : StableData {
      {
        urls = urlMap.vals() |> Iter.toArray(_);
        slugMap = slugToIdMap.entries() |> Iter.toArray(_);
        nextId = nextId;
      };
    };

    // Private helper functions

    private func isValidUrl(url : Text) : Bool {
      // Basic URL validation - must start with http:// or https://
      Text.startsWith(url, #text("http://")) or Text.startsWith(url, #text("https://"));
    };

    private func isValidSlug(slug : Text) : Bool {
      if (slug.size() == 0 or slug.size() > 20) return false;

      for (char in slug.chars()) {
        let isValid = Char.isAlphabetic(char) or Char.isDigit(char) or char == '-' or char == '_';
        if (not isValid) return false;
      };
      true;
    };

    private func generateShortCode() : Text {
      let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      let charsArray = chars.chars() |> Iter.toArray(_);
      let length = 6;
      var code = "";

      // Simple deterministic generation based on nextId for now
      // In production, you'd want a proper random generator
      let base = nextId;
      var num = base;

      for (i in Iter.range(0, length - 1)) {
        let index = num % charsArray.size();
        code := code # Char.toText(charsArray[index]);
        num := num / charsArray.size() + 1;
      };

      // Ensure uniqueness
      if (slugToIdMap.get(code) != null) {
        code # Nat.toText(nextId); // Add ID as suffix if collision
      } else {
        code;
      };
    };
  };
};
