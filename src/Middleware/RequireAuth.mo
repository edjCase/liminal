import App "../App";
import Identity "../Identity";
import HttpContext "../HttpContext";
import Types "../Types";
import Text "mo:new-base/Text";

module {

    /// Creates a new authentication requirement middleware
    /// Checks that requests have authenticated identities that meet the specified requirement
    /// - Parameter requirement: The identity requirement to enforce (authenticated or custom)
    /// - Returns: A middleware that validates authentication and authorization requirements
    public func new(requirement : Identity.IdentityRequirement) : App.Middleware {
        let checkRequirement = func(
            httpContext : HttpContext.HttpContext
        ) : ?Types.HttpResponse {
            let ?identity = httpContext.getIdentity() else {
                httpContext.log(#warning, "No identity found - unauthorized");
                return ?httpContext.buildResponse(#unauthorized, #error(#message("Unauthorized")));
            };

            if (not identity.isAuthenticated()) {
                httpContext.log(#warning, "Identity not authenticated - unauthorized");
                return ?httpContext.buildResponse(#unauthorized, #error(#message("Unauthorized")));
            };

            let meetsRequirement = switch (requirement) {
                case (#authenticated) true; // no additional checks
                case (#custom(custom)) custom(identity);
            };
            if (not meetsRequirement) {
                httpContext.log(#warning, "Authorization requirement not met - forbidden");
                return ?httpContext.buildResponse(#forbidden, #error(#message("Forbidden")));
            };
            null;
        };
        {
            name = "Require Auth";
            handleQuery = func(
                httpContext : HttpContext.HttpContext,
                next : App.Next,
            ) : App.QueryResult {
                switch (checkRequirement(httpContext)) {
                    case (?response) #response(response);
                    case (null) next();
                };
            };
            handleUpdate = func(
                httpContext : HttpContext.HttpContext,
                next : App.NextAsync,
            ) : async* App.HttpResponse {
                switch (checkRequirement(httpContext)) {
                    case (?response) response;
                    case (null) await* next();
                };
            };
        };
    };
};
