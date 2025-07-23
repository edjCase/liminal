import GhostStore "GhostStore";
import Json "mo:json";
import Result "mo:base/Result";

module {

    public func serializeGhost(ghost : GhostStore.Ghost) : Json.Json {
        #object_([("id", #number(#int(ghost.id))), ("name", #string(ghost.name))]);
    };

    public func deserializeCreateRequest(json : Json.Json) : Result.Result<GhostStore.CreateRequest, Text> {
        let name = switch (Json.getAsText(json, "name")) {
            case (#ok(name)) name;
            case (#err(e)) return #err("Error with field 'name': " # debug_show (e));
        };
        #ok({
            name = name;
        });
    };

    public func deserializeUpdateRequest(json : Json.Json) : Result.Result<GhostStore.UpdateRequest, Text> {
        let name = switch (Json.getAsText(json, "name")) {
            case (#ok(name)) name;
            case (#err(e)) return #err("Error with field 'name': " # debug_show (e));
        };
        #ok({
            name = name;
        });
    };
};
