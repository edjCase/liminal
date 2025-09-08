import Array "mo:core@1/Array";
import Map "mo:core@1/Map";
import Iter "mo:core@1/Iter";
import Nat "mo:core@1/Nat";
import Nat32 "mo:core@1/Nat32";
import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Time "mo:core@1/Time";
import Int "mo:core@1/Int";
import Random "mo:core@1/Random";
import Char "mo:core@1/Char";
import BTree "mo:stableheapbtreemap@1/BTree";
import UrlKit "mo:url-kit@1";
import Debug "mo:core@1/Debug";

module {
  public type StableData = {
    urls : BTree.BTree<Nat, Url>;
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

    let slugToIdMap : Map.Map<Text, Nat> = stableData.urls
    |> BTree.entries(_)
    |> Iter.map<(Nat, Url), (Text, Nat)>(
      _,
      func((_, url) : (Nat, Url)) : (Text, Nat) = (url.shortCode, url.id),
    )
    |> Map.fromIter<Text, Nat>(_, Text.compare);

    public func getAllUrls() : [Url] {
      BTree.entries(stableData.urls)
      |> Iter.map(
        _,
        func((_, url) : (Nat, Url)) : Url = url,
      )
      |> Iter.toArray(_);
    };

    public func getUrlByShortCode(shortCode : Text) : ?Url {
      let ?id = Map.get(slugToIdMap, Text.compare, shortCode) else return null;
      BTree.get(stableData.urls, Nat.compare, id);
    };

    public func incrementClicks(shortCode : Text) : ?Text {
      let ?url = getUrlByShortCode(shortCode) else return null;

      Debug.print("Incrementing clicks for shortCode: " # shortCode # " (ID: " # Nat.toText(url.id) # "), current clicks: " # Nat.toText(url.clicks));

      let updatedUrl : Url = {
        url with
        clicks = url.clicks + 1;
      };

      ignore BTree.insert(stableData.urls, Nat.compare, url.id, updatedUrl);
      ?url.originalUrl;
    };

    public func create(request : CreateRequest) : Result.Result<Url, Text> {
      // Validate original URL
      if (not isValidUrl(request.originalUrl)) {
        return #err("Invalid URL format: " # request.originalUrl);
      };

      // Generate or validate short code
      let shortCode = switch (request.customSlug) {
        case (?slug) {
          if (not isValidSlug(slug)) {
            return #err("Invalid custom slug. Use only letters, numbers, hyphens, and underscores");
          };
          if (Map.get(slugToIdMap, Text.compare, slug) != null) {
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
      ignore BTree.insert(stableData.urls, Nat.compare, newUrl.id, newUrl);
      Map.add(slugToIdMap, Text.compare, shortCode, newUrl.id);

      #ok(newUrl);
    };

    public func delete(id : Nat) : Bool {
      let ?url = BTree.delete(stableData.urls, Nat.compare, id) else return false;
      ignore Map.delete(slugToIdMap, Text.compare, url.shortCode);
      true;
    };

    public func toStableData() : StableData {
      {
        urls = stableData.urls;
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

      for (i in Nat.range(0, length)) {
        let index = num % charsArray.size();
        code := code # Char.toText(charsArray[index]);
        num := num / charsArray.size() + 1;
      };

      // Ensure uniqueness
      if (Map.get(slugToIdMap, Text.compare, code) != null) {
        code # Nat.toText(nextId); // Add ID as suffix if collision
      } else {
        code;
      };
    };
  };
};
