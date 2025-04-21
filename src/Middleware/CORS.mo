import HttpContext "../HttpContext";
import Types "../Types";
import App "../App";
import CORS "../CORS";
import List "mo:new-base/List";
import Text "mo:new-base/Text";

module {

    public type Options = CORS.Options;

    public let defaultOptions = CORS.defaultOptions;

    public func default() : App.Middleware {
        new(defaultOptions);
    };

    public func new(options : Options) : App.Middleware {
        {
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                switch (CORS.handlePreflight(context, options)) {
                    case (#complete(response)) return #response(response);
                    case (#next({ corsHeaders })) {
                        switch (next()) {
                            case (#response(response)) {
                                let updatedResponse = addHeadersToResponse(response, corsHeaders);
                                #response(updatedResponse);
                            };
                            case (#upgrade) #upgrade;
                            case (#stream(stream)) #stream(stream);
                        };
                    };
                };
            };
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.UpdateResult {
                switch (CORS.handlePreflight(context, options)) {
                    case (#complete(response)) return #response(response);
                    case (#next({ corsHeaders })) {
                        switch (await* next()) {
                            case (#response(response)) {
                                let updatedResponse = addHeadersToResponse(response, corsHeaders);
                                #response(updatedResponse);
                            };
                            case (#stream(stream)) #stream(stream);
                        };
                    };
                };
            };
        };
    };

    private func addHeadersToResponse(
        response : Types.HttpResponse,
        corsHeaders : [(Text, Text)],
    ) : Types.HttpResponse {

        // Combine headers
        let responseHeaders = List.fromArray<(Text, Text)>(response.headers);
        List.addAll(responseHeaders, corsHeaders.vals()); // Append CORS headers last

        {
            response with
            headers = List.toArray(responseHeaders);
        };
    };

};
