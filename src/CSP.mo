import List "mo:new-base/List";
import Text "mo:new-base/Text";
import Types "Types";

module {

    public type Options = {
        defaultSrc : [Text];
        scriptSrc : [Text];
        connectSrc : [Text];
        imgSrc : [Text];
        styleSrc : [Text];
        styleSrcElem : [Text];
        fontSrc : [Text];
        objectSrc : [Text];
        baseUri : [Text];
        frameAncestors : [Text];
        formAction : [Text];
        upgradeInsecureRequests : Bool;
    };

    public let defaultOptions : Options = {
        defaultSrc = ["'self'"];
        scriptSrc = ["'self'"];
        connectSrc = ["'self'", "http://localhost:*", "https://icp0.io", "https://*.icp0.io", "https://icp-api.io"];
        imgSrc = ["'self'", "data:"];
        styleSrc = ["*", "'unsafe-inline'"];
        styleSrcElem = ["*", "'unsafe-inline'"];
        fontSrc = ["*"];
        objectSrc = ["'none'"];
        baseUri = ["'self'"];
        frameAncestors = ["'none'"];
        formAction = ["'self'"];
        upgradeInsecureRequests = true;
    };

    public func addHeadersToResponse(response : Types.HttpResponse, options : Options) : Types.HttpResponse {
        let cspValue = buildHeaderValue(options);
        let headers = List.fromArray<(Text, Text)>(response.headers);
        List.add(headers, ("Content-Security-Policy", cspValue));

        {
            response with
            headers = List.toArray(headers);
        };
    };

    public func buildHeaderValue(options : Options) : Text {
        let cspParts = List.empty<Text>();

        if (options.defaultSrc.size() > 0) {
            List.add(cspParts, "default-src " # Text.join(" ", options.defaultSrc.vals()));
        };

        if (options.scriptSrc.size() > 0) {
            List.add(cspParts, "script-src " # Text.join(" ", options.scriptSrc.vals()));
        };

        if (options.connectSrc.size() > 0) {
            List.add(cspParts, "connect-src " # Text.join(" ", options.connectSrc.vals()));
        };

        if (options.imgSrc.size() > 0) {
            List.add(cspParts, "img-src " # Text.join(" ", options.imgSrc.vals()));
        };

        if (options.styleSrc.size() > 0) {
            List.add(cspParts, "style-src " # Text.join(" ", options.styleSrc.vals()));
        };

        if (options.styleSrcElem.size() > 0) {
            List.add(cspParts, "style-src-elem " # Text.join(" ", options.styleSrcElem.vals()));
        };

        if (options.fontSrc.size() > 0) {
            List.add(cspParts, "font-src " # Text.join(" ", options.fontSrc.vals()));
        };

        if (options.objectSrc.size() > 0) {
            List.add(cspParts, "object-src " # Text.join(" ", options.objectSrc.vals()));
        };

        if (options.baseUri.size() > 0) {
            List.add(cspParts, "base-uri " # Text.join(" ", options.baseUri.vals()));
        };

        if (options.frameAncestors.size() > 0) {
            List.add(cspParts, "frame-ancestors " # Text.join(" ", options.frameAncestors.vals()));
        };

        if (options.formAction.size() > 0) {
            List.add(cspParts, "form-action " # Text.join(" ", options.formAction.vals()));
        };

        if (options.upgradeInsecureRequests) {
            List.add(cspParts, "upgrade-insecure-requests");
        };

        Text.join(";", List.values(cspParts));
    };
};
