import Pipeline "./Pipeline";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import HttpContext "./HttpContext";
import Types "./Types";

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

    public func use(data : Pipeline.PipelineData, options : Options) : Pipeline.PipelineData {
        let newMiddleware = createMiddleware(options);
        {
            middleware = Array.append(data.middleware, [newMiddleware]);
        };
    };

    public func createMiddleware(options : Options) : Pipeline.Middleware {
        {
            handleQuery = ?(
                func(context : HttpContext.HttpContext, next : Pipeline.Next) : ?Types.HttpResponse {
                    let ?response = next() else return null;
                    ?addCSPHeaders(response, options);
                }
            );
            handleUpdate = func(_ : HttpContext.HttpContext, next : Pipeline.NextAsync) : async* ?Types.HttpResponse {
                let ?response = await* next() else return null;
                ?addCSPHeaders(response, options);
            };
        };
    };

    private func addCSPHeaders(response : Types.HttpResponse, options : Options) : Types.HttpResponse {
        let cspParts = Buffer.Buffer<Text>(12);

        if (options.defaultSrc.size() > 0) {
            cspParts.add("default-src " # Text.join(" ", options.defaultSrc.vals()));
        };

        if (options.scriptSrc.size() > 0) {
            cspParts.add("script-src " # Text.join(" ", options.scriptSrc.vals()));
        };

        if (options.connectSrc.size() > 0) {
            cspParts.add("connect-src " # Text.join(" ", options.connectSrc.vals()));
        };

        if (options.imgSrc.size() > 0) {
            cspParts.add("img-src " # Text.join(" ", options.imgSrc.vals()));
        };

        if (options.styleSrc.size() > 0) {
            cspParts.add("style-src " # Text.join(" ", options.styleSrc.vals()));
        };

        if (options.styleSrcElem.size() > 0) {
            cspParts.add("style-src-elem " # Text.join(" ", options.styleSrcElem.vals()));
        };

        if (options.fontSrc.size() > 0) {
            cspParts.add("font-src " # Text.join(" ", options.fontSrc.vals()));
        };

        if (options.objectSrc.size() > 0) {
            cspParts.add("object-src " # Text.join(" ", options.objectSrc.vals()));
        };

        if (options.baseUri.size() > 0) {
            cspParts.add("base-uri " # Text.join(" ", options.baseUri.vals()));
        };

        if (options.frameAncestors.size() > 0) {
            cspParts.add("frame-ancestors " # Text.join(" ", options.frameAncestors.vals()));
        };

        if (options.formAction.size() > 0) {
            cspParts.add("form-action " # Text.join(" ", options.formAction.vals()));
        };

        if (options.upgradeInsecureRequests) {
            cspParts.add("upgrade-insecure-requests");
        };

        let cspValue = Text.join(";", cspParts.vals());

        let headers = Buffer.Buffer<(Text, Text)>(response.headers.size() + 1);
        headers.append(Buffer.fromArray(response.headers));
        headers.add(("Content-Security-Policy", cspValue));

        {
            response with
            headers = Buffer.toArray(headers);
        };
    };
};
