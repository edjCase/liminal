import Array "mo:base/Array";
import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Blob "mo:base/Blob";

module {
  public type StableData = {
    ghosts : [Ghost];
    nextId : Nat;
  };

  public type Image = {
    data : Blob;
    mimeType : Text;
  };

  public type Ghost = {
    id : Nat;
    name : Text;
    image : Image;
  };

  public type CreateRequest = {
    name : Text;
    image : Image;
  };

  public type UpdateRequest = {
    name : ?Text;
    image : ?Image;
  };

  public type GhostMetaData = {
    id : Nat;
    name : Text;
  };

  public class Store(stableData : StableData) = self {

    var nextId = stableData.nextId;

    var ghostMap = stableData.ghosts.vals()
    |> Iter.map<Ghost, (Nat, Ghost)>(
      _,
      func(ghost : Ghost) : (Nat, Ghost) {
        (ghost.id, ghost);
      },
    )
    |> HashMap.fromIter<Nat, Ghost>(
      _,
      stableData.ghosts.size(),
      Nat.equal,
      func(nat : Nat) : Nat32 {
        // Simple hash function for Nat
        Nat32.fromIntWrap(nat);
      },
    );

    public func get() : [GhostMetaData] {
      ghostMap.vals() |> Iter.toArray(_);
    };

    public func getById(id : Nat) : ?GhostMetaData {
      ghostMap.get(id);
    };

    public func getImageById(id : Nat) : ?Image {
      let ?ghost = ghostMap.get(id) else return null;
      ?ghost.image;
    };

    public func create(request : CreateRequest) : Result.Result<GhostMetaData, Text> {
      let mimeType = switch (normalizeAndValidateMimeType(request.image.mimeType)) {
        case (#ok(mimeType)) mimeType;
        case (#err(e)) return #err(e);
      };

      let newGhost : Ghost = {
        id = nextId;
        name = request.name;
        image = {
          data = request.image.data;
          mimeType = mimeType;
        };
      };
      nextId += 1;

      ghostMap.put(newGhost.id, newGhost);
      #ok(newGhost);
    };

    public func update(id : Nat, request : UpdateRequest) : Result.Result<Bool, Text> {
      let currentGhost = switch (ghostMap.get(id)) {
        case (null) return #ok(false);
        case (?ghost) ghost;
      };
      let newName = switch (request.name) {
        case (null) currentGhost.name; // No name update, keep current name
        case (?name) name;
      };
      let newImage = switch (request.image) {
        case (null) currentGhost.image; // No image update, keep current image
        case (?image) {
          let mimeType = switch (normalizeAndValidateMimeType(image.mimeType)) {
            case (#ok(mimeType)) mimeType;
            case (#err(e)) return #err(e);
          };
          {
            data = image.data;
            mimeType = mimeType;
          };
        };
      };

      ghostMap.put(
        id,
        {
          id = id;
          name = newName;
          image = newImage;
        },
      );

      #ok(true);
    };

    public func delete(id : Nat) : Bool {
      ghostMap.remove(id) != null;
    };

    public func toStableData() : StableData {
      {
        ghosts = ghostMap.vals() |> Iter.toArray(_);
        nextId = nextId;
      };
    };

    private func normalizeAndValidateMimeType(mimeType : Text) : Result.Result<Text, Text> {
      let normalizedMimeType = Text.toLowercase(mimeType);
      switch (normalizedMimeType) {
        case ("image/png" or "image/jpeg" or "image/gif" or "image/webp" or "image/bmp" or "image/tiff" or "image/svg+xml" or "image/svg") ();
        case (unsupportedMimeType) return #err("Unsupported image mime type: " # unsupportedMimeType);
      };
      #ok(normalizedMimeType);
    };

  };
};
