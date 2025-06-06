import Route "mo:liminal/Route";
import Nat "mo:new-base/Nat";
import Runtime "mo:new-base/Runtime";
import UserHandler "UserHandler";
import Serializer "Serializer";
import Serde "mo:serde";
import RouteContext "mo:liminal/RouteContext";

module {

    public class Router(userHandler : UserHandler.Handler) = self {

        let userKeys = ["id", "name"];
        let renamedUserKeys = [];

        public func get(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let users = userHandler.get();
            routeContext.buildResponse(#ok, #content(toCandid(to_candid (users))));
        };

        public func getById(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let idText = routeContext.getRouteParam("id");
            let ?id = Nat.fromText(idText) else return routeContext.buildResponse(#badRequest, #error(#message("Invalid id '" # idText # "', must be a positive integer")));

            let ?user = userHandler.getById(id) else return routeContext.buildResponse(#notFound, #error(#none));
            routeContext.buildResponse(#ok, #content(toCandid(to_candid (user))));
        };

        public func create<system>(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let createUserRequest : UserHandler.CreateUserRequest = switch (routeContext.parseJsonBody<UserHandler.CreateUserRequest>(Serializer.deserializeCreateUserRequest)) {
                case (#err(e)) return routeContext.buildResponse(#badRequest, #error(#message("Failed to parse Json. Error: " # e)));
                case (#ok(req)) req;
            };

            let newUser = userHandler.create(createUserRequest);

            routeContext.buildResponse(#created, #content(toCandid(to_candid (newUser))));
        };

        func toCandid(value : Blob) : Serde.Candid.Candid {
            let options : ?Serde.Options = ?{
                renameKeys = renamedUserKeys;
                blob_contains_only_values = false;
                types = null;
                use_icrc_3_value_type = false;
            };
            switch (Serde.Candid.decode(value, userKeys, options)) {
                case (#err(e)) Runtime.trap("Failed to decode user Candid. Error: " # e);
                case (#ok(candid)) {
                    if (candid.size() != 1) {
                        return Runtime.trap("Invalid Candid response. Expected 1 element, got " # Nat.toText(candid.size()));
                    };
                    candid[0];
                };
            };
        };
    };
};
