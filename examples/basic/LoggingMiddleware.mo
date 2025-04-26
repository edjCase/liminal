import HttpContext "../../src/HttpContext";
import HttpMethod "../../src/HttpMethod";
import Debug "mo:new-base/Debug";
import Iter "mo:new-base/Iter";
import Text "mo:base/Text";
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
                case (#response(response)) {
                    let trimmedHeaders = response.headers.vals()
                    |> Iter.filter(
                        _,
                        func((header, _) : (Text, Text)) : Bool {
                            switch (header) {
                                case ("ic-certificate") false;
                                case ("ic-certificateexpression") false;
                                case ("Content-Security-Policy") false;
                                case (_) true;
                            };
                        },
                    )
                    |> Iter.toArray(_);
                    let message = debug_show {
                        statusCode = response.statusCode;
                        headers = trimmedHeaders;
                    };
                    switch (response.streamingStrategy) {
                        case (null) message;
                        case (?ss) message # "\nStreaming... " # (
                            switch (ss) {
                                case (#callback(callback)) "Callback..." # debug_show (
                                    from_candid (callback.token) : ?{
                                        key : Text;
                                        sha256 : ?Blob;
                                        content_encoding : Text;
                                        index : Nat;
                                    }
                                );
                            }
                        );
                    };
                };
                case (#upgrade) "Upgrading...";
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
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                logRequest(#update, context);
                let result = await* next();
                logResponse(#update, #response(result));
                result;
            };
        };
    };
};
