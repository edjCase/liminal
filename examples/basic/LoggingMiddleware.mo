import HttpContext "../../src/HttpContext";
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

        func logResponse(kind : { #query_; #update }, result : App.QueryResult) {
            let prefix = getPrefix(kind);
            let responseText = switch (result) {
                case (#response(response)) Nat.toText(response.statusCode);
                case (#upgrade) "Upgrading...";
                case (#stream(_)) "Streaming...";
            };
            Debug.print(prefix # "HTTP Response: " # responseText);
        };
        {
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                logRequest(#query_, context);
                let result = next();
                logResponse(#query_, result);
                result;
            };
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.UpdateResult {
                logRequest(#update, context);
                let result = await* next();
                logResponse(#update, result);
                result;
            };
        };
    };
};
