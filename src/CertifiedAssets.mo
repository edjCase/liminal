import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Nat16 "mo:new-base/Nat16";
import Option "mo:new-base/Option";
import Blob "mo:new-base/Blob";
import CertifiedAssets "mo:certified-assets";
import HttpContext "./HttpContext";
import Types "./Types";
import HttpTypes "./HttpTypes";
import HttpMethod "HttpMethod";

module {
    public type Options = {
        assets : CertifiedAssets.CertifiedAssets;
        fallbackPath : ?Text;
    };

    public func handleResponse(
        context : HttpContext.HttpContext,
        response : Types.HttpResponse,
        options : Options,
    ) : Types.HttpResponse {
        let req : HttpTypes.QueryRequest = {
            method = HttpMethod.toText(context.method);
            url = context.request.url;
            headers = context.request.headers;
            body = context.request.body;
            certificate_version = null; // TODO
        };
        let res : HttpTypes.QueryResponse = {
            status_code = Nat16.fromNat(response.statusCode);
            headers = response.headers;
            body = Option.get(response.body, Blob.fromArray([]));
            streaming_strategy = null;
            upgrade = null;
        };

        switch (options.assets.get_certificate(req, res, null)) {
            // Return certified response if successful
            case (#ok(certificate_headers)) ({
                response with headers = Array.concat(
                    response.headers,
                    certificate_headers,
                )
            });
            // Try fallback if configured
            case (#err(_)) response;
        };
    };
};
