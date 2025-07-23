import Route "mo:liminal/Route";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import GhostStore "GhostStore";
import Serializer "Serializer";
import Serde "mo:serde";
import RouteContext "mo:liminal/RouteContext";

module {

    public class Router(store : GhostStore.Store) = self {

        public func get(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let ghosts = store.get();
            routeContext.buildResponse(#ok, #content(toCandid(to_candid (ghosts))));
        };

        public func getById(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let idText = routeContext.getRouteParam("id");
            let ?id = Nat.fromText(idText) else return routeContext.buildResponse(#badRequest, #error(#message("Invalid id '" # idText # "', must be a positive integer")));

            let ?ghost = store.getById(id) else return routeContext.buildResponse(#notFound, #error(#none));
            routeContext.buildResponse(#ok, #content(toCandid(to_candid (ghost))));
        };

        public func create<system>(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let createRequest : GhostStore.CreateRequest = switch (routeContext.parseJsonBody<GhostStore.CreateRequest>(Serializer.deserializeCreateRequest)) {
                case (#err(e)) return routeContext.buildResponse(#badRequest, #error(#message("Failed to parse Json. Error: " # e)));
                case (#ok(req)) req;
            };

            let newGhost = store.create(createRequest);

            routeContext.buildResponse(#created, #content(toCandid(to_candid (newGhost))));
        };

        public func update<system>(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let idText = routeContext.getRouteParam("id");
            let ?id = Nat.fromText(idText) else return routeContext.buildResponse(#badRequest, #error(#message("Invalid id '" # idText # "', must be a positive integer")));

            let updateRequest : GhostStore.UpdateRequest = switch (routeContext.parseJsonBody<GhostStore.UpdateRequest>(Serializer.deserializeUpdateRequest)) {
                case (#err(e)) return routeContext.buildResponse(#badRequest, #error(#message("Failed to parse Json. Error: " # e)));
                case (#ok(req)) req;
            };

            let existed = store.update(id, updateRequest) else return routeContext.buildResponse(#notFound, #error(#none));
            if (not existed) {
                return routeContext.buildResponse(#notFound, #error(#none));
            };
            routeContext.buildResponse(#noContent, #empty);
        };

        public func delete<system>(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let idText = routeContext.getRouteParam("id");
            let ?id = Nat.fromText(idText) else return routeContext.buildResponse(#badRequest, #error(#message("Invalid id '" # idText # "', must be a positive integer")));
            let existed = store.delete(id);
            if (not existed) {
                return routeContext.buildResponse(#notFound, #error(#none));
            };

            routeContext.buildResponse(#noContent, #empty);
        };

        func toCandid(value : Blob) : Serde.Candid.Candid {
            let ghostKeys = ["id", "name"];
            let renamedGhostKeys = [];
            let options : ?Serde.Options = ?{
                renameKeys = renamedGhostKeys;
                blob_contains_only_values = false;
                types = null;
                use_icrc_3_value_type = false;
            };
            switch (Serde.Candid.decode(value, ghostKeys, options)) {
                case (#err(e)) Debug.trap("Failed to decode ghost Candid. Error: " # e);
                case (#ok(candid)) {
                    if (candid.size() != 1) {
                        return Debug.trap("Invalid Candid response. Expected 1 element, got " # Nat.toText(candid.size()));
                    };
                    candid[0];
                };
            };
        };
    };
};
