import App "../App";
import Identity "../Identity";
import HttpContext "../HttpContext";
import Types "../Types";
import Text "mo:new-base/Text";

module {

    public func new(requirement : Identity.IdentityRequirement) : App.Middleware {
        let checkRequirement = func(
            httpContext : HttpContext.HttpContext
        ) : ?Types.HttpResponse {
            let ?identity = httpContext.getIdentity() else return ?unauthorized();

            if (not identity.isAuthenticated()) {
                return ?unauthorized();
            };

            let meetsRequirement = switch (requirement) {
                case (#authenticated) true; // no additional checks
                case (#custom(custom)) custom(identity);
            };
            if (not meetsRequirement) {
                return ?forbidden();
            };
            null;
        };
        {
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
                    case (?response) #response(response);
                    case (null) await* next();
                };
            };
        };
    };

    private func unauthorized() : Types.HttpResponse {
        {
            statusCode = 401;
            headers = [("WWW-Authenticate", "")]; // TODO config?
            body = ?Text.encodeUtf8("Unauthorized"); // TODO json?
        };
    };

    private func forbidden() : Types.HttpResponse {
        {
            statusCode = 403;
            headers = [];
            body = ?Text.encodeUtf8("Forbidden"); // TODO json?
        };
    };
};
