import UserHandler "UserHandler";
import Json "mo:json";
import Result "mo:new-base/Result";

module {

    public func serializeUser(user : UserHandler.User) : Json.Json {
        #object_([("id", #number(#int(user.id))), ("name", #string(user.name))]);
    };

    public func deserializeCreateUserRequest(json : Json.Json) : Result.Result<UserHandler.CreateUserRequest, Text> {
        let name = switch (Json.getAsText(json, "name")) {
            case (#ok(name)) name;
            case (#err(e)) return #err("Error with field 'name': " # debug_show (e));
        };
        #ok({
            name = name;
        });
    };
};
