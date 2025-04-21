import Route "../../src/Route";
import Nat "mo:new-base/Nat";
import Array "mo:new-base/Array";
import UserHandler "UserHandler";
import Json "mo:json";
import Serializer "Serializer";

module {

    public class Router(userHandler : UserHandler.Handler) = self {

        public func get(routeContext : Route.RouteContext) : Route.HttpResponse {
            let users = userHandler.get();
            let usersJson : Json.Json = #array(users |> Array.map<UserHandler.User, Json.Json>(_, Serializer.serializeUser));
            routeContext.buildResponse(#ok, #json(usersJson));
        };

        public func getById(routeContext : Route.RouteContext) : Route.HttpResponse {
            let idText = routeContext.getRouteParam("id");
            let ?id = Nat.fromText(idText) else return routeContext.buildErrorResponse(#badRequest, #message("Invalid id '" # idText # "', must be a positive integer"));

            let ?user = userHandler.getById(id) else return routeContext.buildErrorResponse(#notFound, #none);
            routeContext.buildResponse(#ok, #json(Serializer.serializeUser(user)));
        };

        public func create<system>(routeContext : Route.RouteContext) : Route.HttpResponse {
            let createUserRequest : UserHandler.CreateUserRequest = switch (routeContext.parseJsonBody<UserHandler.CreateUserRequest>(Serializer.deserializeCreateUserRequest)) {
                case (#err(e)) return routeContext.buildErrorResponse(#badRequest, #message("Failed to parse Json. Error: " # e));
                case (#ok(req)) req;
            };

            let newUser = userHandler.create(createUserRequest);

            routeContext.buildResponse(#created, #json(Serializer.serializeUser(newUser)));
        };
    };
};
