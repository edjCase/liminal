import Array "mo:base/Array";
import Nat "mo:base/Nat";
import HashMap "mo:base/HashMap";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";

module {
    public type StableData = {
        ghosts : [Ghost];
    };

    public type Ghost = {
        id : Nat;
        name : Text;
    };

    public type CreateRequest = {
        name : Text;
    };

    public type UpdateRequest = {
        name : Text;
    };

    public class Store(stableData : StableData) = self {

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

        public func get() : [Ghost] {
            ghostMap.vals() |> Iter.toArray(_);
        };

        public func getById(id : Nat) : ?Ghost {
            ghostMap.get(id);
        };

        public func create(request : CreateRequest) : Ghost {
            let newGhost : Ghost = {
                id = ghostMap.size() + 1;
                name = request.name;
            };

            ghostMap.put(newGhost.id, newGhost);
            newGhost;
        };

        public func update(id : Nat, request : CreateRequest) : Bool {
            if (ghostMap.get(id) == null) {
                return false;
            };

            ghostMap.put(
                id,
                {
                    id = id;
                    name = request.name;
                },
            );

            true;
        };

        public func delete(id : Nat) : Bool {
            ghostMap.remove(id) != null;
        };

        public func toStableData() : StableData {
            {
                ghosts = ghostMap.vals() |> Iter.toArray(_);
            };
        };
    };
};
