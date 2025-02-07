import Http "mo:http";

actor {

    let server = Http.Router().get(
        "/",
        func(req) {
            Http.Response.text("Hello, world!");
        },
    );

    /*
     * http request hooks
     */
    public query func http_request(req : Server.HttpRequest) : async Server.HttpResponse {
        server.http_request(req);
    };
    public func http_request_update(req : HttpRequest) : async HttpResponse {
        await server.http_request_update(req);
    };

};
