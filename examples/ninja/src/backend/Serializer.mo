import GhostStore "GhostStore";
import Json "mo:json";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import BaseX "mo:base-x-encoder";

module {

    public func serializeGhost(ghost : GhostStore.Ghost) : Json.Json {
        #object_([("id", #number(#int(ghost.id))), ("name", #string(ghost.name))]);
    };

    public func deserializeCreateRequest(json : Json.Json) : Result.Result<GhostStore.CreateRequest, Text> {
        let name = switch (Json.getAsText(json, "name")) {
            case (#ok(name)) name;
            case (#err(e)) return #err("Error with field 'name': " # debug_show (e));
        };

        let image = switch (Json.get(json, "image")) {
            case (?imageJson) switch (deserializeImage(imageJson)) {
                case (#ok(image)) image;
                case (#err(e)) return #err("Error with field 'image': " # e);
            };
            case (null) return #err("Missing 'image' field");
        };

        #ok({
            name = name;
            image = image;
        });
    };

    public func deserializeUpdateRequest(json : Json.Json) : Result.Result<GhostStore.UpdateRequest, Text> {
        let name = switch (Json.getAsText(json, "name")) {
            case (#ok(name)) ?name;
            case (#err(#pathNotFound)) null; // Allow name to be optional
            case (#err(e)) return #err("Error with field 'name': " # debug_show (e));
        };

        let image = switch (Json.get(json, "image")) {
            case (?imageJson) switch (deserializeImage(imageJson)) {
                case (#ok(image)) ?image;
                case (#err(e)) return #err("Error with field 'image': " # e);
            };
            case (null) null;
        };

        #ok({
            name = name;
            image = image;
        });
    };

    private func deserializeImage(json : Json.Json) : Result.Result<GhostStore.Image, Text> {

        let imageBlob = switch (Json.getAsText(json, "data")) {
            case (#ok(imageBase64)) switch (BaseX.fromBase64(imageBase64)) {
                case (#ok(blob)) Blob.fromArray(blob);
                case (#err(e)) return #err("Invalid base64 data: " # e);
            };
            case (#err(e)) return #err("Error with field 'data': " # debug_show (e));
        };

        let mimeType = switch (Json.getAsText(json, "mimeType")) {
            case (#ok(mimeType)) mimeType;
            case (#err(e)) return #err("Error with field 'mimeType': " # debug_show (e));
        };
        #ok({
            data = imageBlob;
            mimeType = mimeType;
        });
    };
};
