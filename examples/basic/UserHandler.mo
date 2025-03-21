import Array "mo:new-base/Array";
import Nat "mo:new-base/Nat";

module {
    public type StableData = {
        users : [User];
    };
    public type User = {
        id : Nat;
        name : Text;
    };

    public type CreateUserRequest = {
        name : Text;
    };

    public class Handler(stableData : StableData) = self {

        var users : [User] = stableData.users;

        public func get() : [User] {
            users;
        };

        public func getById(id : Nat) : ?User {
            users
            |> Array.find(
                _,
                func(user : User) : Bool = user.id == id,
            );
        };

        public func create(request : CreateUserRequest) : User {

            let newUser : User = {
                id = users.size() + 1;
                name = request.name;
            };

            users := Array.concat(users, [newUser]);

            newUser;
        };

        public func toStableData() : StableData {
            {
                users = users;
            };
        };
    };
};
