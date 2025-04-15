import HttpContext "../../src/HttpContext";
import Types "../../src/Types";
import HttpMethod "../../src/HttpMethod";
import Nat "mo:new-base/Nat";
import Debug "mo:new-base/Debug";
import Path "../../src/Path";
import App "../../src/App";

module {

    public func new() : App.Middleware {

        func getPrefix(kind : { #query_; #update }) : Text {
            switch (kind) {
                case (#query_) "Query ";
                case (#update) "Update ";
            };
        };

        func logRequest(kind : { #query_; #update }, context : HttpContext.HttpContext) {
            let prefix = getPrefix(kind);
            Debug.print(prefix # "HTTP Request: " # HttpMethod.toText(context.method) # " " # Path.toText(context.getPath()));
            switch (context.getIdentity()) {
                case (?identity) Debug.print("Identity:  " # debug_show ({ kind = identity.kind; id = identity.getId(); isAuthenticated = identity.isAuthenticated() }));
                case (null) Debug.print("Identity: null");
            }

        };

        func logResponse(kind : { #query_; #update }, responseOrNull : ?Types.HttpResponse) {
            let prefix = getPrefix(kind);
            let responseText = switch (responseOrNull) {
                case (?response) Nat.toText(response.statusCode);
                case (null) "null";
            };
            Debug.print(prefix # "HTTP Response: " # responseText);
        };
        {
            handleQuery = ?(
                func(context : HttpContext.HttpContext, next : App.Next) : ?Types.HttpResponse {
                    logRequest(#query_, context);
                    let responseOrNull = next();
                    logResponse(#query_, responseOrNull);
                    responseOrNull;
                }
            );
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* ?Types.HttpResponse {
                logRequest(#update, context);
                let responseOrNull = await* next();
                logResponse(#update, responseOrNull);
                responseOrNull;
            };
        };
    };
};
