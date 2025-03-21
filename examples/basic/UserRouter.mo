import Route "../../src/Route";
import Nat "mo:new-base/Nat";
import Array "mo:new-base/Array";
import UserHandler "UserHandler";
import Json "mo:json";
import Serializer "Serializer";

module {

    public class Router(userHandler : UserHandler.Handler) = self {

        public func get(_ : Route.RouteContext) : Route.RouteResult {
            let users = userHandler.get();
            let usersJson : Json.Json = #array(users |> Array.map<UserHandler.User, Json.Json>(_, Serializer.serializeUser));
            #ok(#json(usersJson));
        };

        public func getById(routeContext : Route.RouteContext) : Route.RouteResult {
            let idText = routeContext.getRouteParam("id");
            let ?id = Nat.fromText(idText) else return #badRequest("Invalid id '" # idText # "', must be a positive integer");

            let ?user = userHandler.getById(id) else return #notFound(null);

            #ok(#json(Serializer.serializeUser(user)));
        };

        public func create<system>(context : Route.RouteContext) : Route.RouteResult {
            let createUserRequest : UserHandler.CreateUserRequest = switch (context.parseJsonBody<UserHandler.CreateUserRequest>(Serializer.deserializeCreateUserRequest)) {
                case (#err(e)) return #badRequest("Failed to parse Json. Error: " # e);
                case (#ok(req)) req;
            };

            let newUser = userHandler.create(createUserRequest);

            #created(#json(Serializer.serializeUser(newUser)));
        };
    };
};
