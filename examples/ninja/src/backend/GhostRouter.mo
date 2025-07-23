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

        public func getImageById(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let idText = routeContext.getRouteParam("id");
            let ?id = Nat.fromText(idText) else return routeContext.buildResponse(#badRequest, #error(#message("Invalid id '" # idText # "', must be a positive integer")));

            let ?image = store.getImageById(id) else return routeContext.buildResponse(#notFound, #error(#none));

            routeContext.buildResponse(
                #ok,
                #custom({
                    body = image.data;
                    headers = [
                        ("Content-Type", image.mimeType),
                        ("Content-Length", Nat.toText(image.data.size())),
                    ];
                }),
            );
        };

        public func create<system>(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            Debug.print("Creating ghost...");

            let createRequest : GhostStore.CreateRequest = switch (routeContext.parseJsonBody<GhostStore.CreateRequest>(Serializer.deserializeCreateRequest)) {
                case (#err(e)) return routeContext.buildResponse(#badRequest, #error(#message("Failed to parse Json. Error: " # e)));
                case (#ok(req)) req;
            };

            switch (store.create(createRequest)) {
                case (#ok(newGhost)) routeContext.buildResponse(#created, #content(toCandid(to_candid (newGhost))));
                case (#err(e)) routeContext.buildResponse(#badRequest, #error(#message("Failed to update ghost. Error: " # e)));
            };
        };

        public func update<system>(routeContext : RouteContext.RouteContext) : Route.HttpResponse {
            let idText = routeContext.getRouteParam("id");
            let ?id = Nat.fromText(idText) else return routeContext.buildResponse(#badRequest, #error(#message("Invalid id '" # idText # "', must be a positive integer")));

            let updateRequest : GhostStore.UpdateRequest = switch (routeContext.parseJsonBody<GhostStore.UpdateRequest>(Serializer.deserializeUpdateRequest)) {
                case (#err(e)) return routeContext.buildResponse(#badRequest, #error(#message("Failed to parse Json. Error: " # e)));
                case (#ok(req)) req;
            };

            switch (store.update(id, updateRequest)) {
                case (#ok(existed)) {
                    if (not existed) {
                        return routeContext.buildResponse(#notFound, #error(#none));
                    };
                    routeContext.buildResponse(#noContent, #empty);
                };
                case (#err(e)) routeContext.buildResponse(#badRequest, #error(#message("Failed to update ghost. Error: " # e)));
            };
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
            Debug.print("Encoding ghost Candid");
            switch (Serde.Candid.decode(value, ghostKeys, options)) {
                case (#err(e)) {
                    Debug.print("Failed to decode ghost Candid. Error: " # e);
                    Debug.trap("Failed to decode ghost Candid. Error: " # e);
                };
                case (#ok(candid)) {
                    if (candid.size() != 1) {
                        Debug.print("Invalid Candid response. Expected 1 element, got " # Nat.toText(candid.size()));
                        Debug.trap("Invalid Candid response. Expected 1 element, got " # Nat.toText(candid.size()));
                    };
                    candid[0];
                };
            };
        };
    };
};
