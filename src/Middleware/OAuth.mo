import Liminal "../";
import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Map "mo:new-base/Map";
import Time "mo:new-base/Time";
import Random "mo:base/Random";
import Buffer "mo:base/Buffer";
import Nat "mo:new-base/Nat";
import App "../App";
import IC "mo:ic";
import Serde "mo:serde";
import List "mo:new-base/List";
import BaseX "mo:base-x-encoder";
import Option "mo:new-base/Option";
import Array "mo:new-base/Array";
import Sha256 "mo:sha2/Sha256";

module {

    // Common OAuth providers configurations
    public let Google = {
        authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth";
        tokenEndpoint = "https://oauth2.googleapis.com/token";
        userInfoEndpoint = "https://www.googleapis.com/oauth2/v2/userinfo";
    };

    public let GitHub = {
        authorizationEndpoint = "https://github.com/login/oauth/authorize";
        tokenEndpoint = "https://github.com/login/oauth/access_token";
        userInfoEndpoint = "https://api.github.com/user";
    };

    public type Config = {
        providers : [ProviderConfig];
        siteUrl : Text;
        store : OAuthStore; // Where to store OAuth state/tokens
        onLogin : (Liminal.HttpContext, LoginData) -> async* Liminal.HttpResponse;
        onLogout : (Liminal.HttpContext, LogoutData) -> async* Liminal.HttpResponse;
    };

    public type LoginData = {
        providerConfig : ProviderConfig;
        tokenInfo : TokenInfo;
        oauthContext : OAuthContext;
    };

    public type LogoutData = {
        providerConfig : ProviderConfig;
    };

    public type ProviderConfig = {
        name : Text; // e.g., "Google", "GitHub"
        clientId : Text;
        clientSecret : Text; // TODO this is insecure even with environment variables, need secure method, canister encryption?
        authorizationEndpoint : Text;
        tokenEndpoint : Text;
        scopes : [Text];
        usePKCE : Bool; // Optional PKCE support
    };

    public type OAuthStore = {
        saveContext : (value : OAuthContext) -> ();
        getContext : (key : Text) -> ?OAuthContext;
        removeContext : (key : Text) -> ();
    };

    public type OAuthContext = {
        state : Text;
        codeVerifier : ?Text; // For PKCE
        redirectAfterAuth : ?Text;
        createdAt : Int;
    };

    public type TokenInfo = {
        accessToken : Text;
        tokenType : Text;
        expiresIn : ?Int;
        refreshToken : ?Text;
        scope : ?Text;
        idToken : ?Text; // For OpenID Connect
    };

    public type UserInfo = {
        id : Text;
        name : ?Text;
        email : ?Text;
    };

    // Simple in-memory state store (you might want persistent storage)
    public func inMemoryStore() : OAuthStore {
        var contexts = Map.empty<Text, OAuthContext>();

        {
            saveContext = func(value : OAuthContext) {
                Map.add(contexts, Text.compare, value.state, value);
            };
            getContext = func(state : Text) : ?OAuthContext {
                Map.get(contexts, Text.compare, state);
            };
            removeContext = func(state : Text) {
                ignore Map.delete<Text, OAuthContext>(contexts, Text.compare, state);
            };
        };
    };

    public func new(config : Config) : App.Middleware {

        func getRedirectUri(providerName : Text) : Text {
            // Construct the redirect URI based on the provider name and site URL
            let siteUrlWithSlash = if (Text.endsWith(config.siteUrl, #char('/'))) config.siteUrl else config.siteUrl # "/";
            siteUrlWithSlash # "auth/" # Text.toLower(providerName) # "/callback";
        };

        func buildAuthUrl(providerConfig : ProviderConfig, state : Text, codeChallenge : ?Text) : Text {
            let baseUrl = providerConfig.authorizationEndpoint;
            let params = Buffer.Buffer<Text>(8);

            params.add("response_type=code");
            params.add("client_id=" # providerConfig.clientId);
            params.add("redirect_uri=" # getRedirectUri(providerConfig.name));
            params.add("state=" # state);
            params.add("scope=" # Text.join(" ", providerConfig.scopes.vals()));

            switch (codeChallenge) {
                case (?challenge) {
                    params.add("code_challenge=" # challenge);
                    params.add("code_challenge_method=S256");
                };
                case (null) {};
            };

            baseUrl # "?" # Text.join("&", params.vals());
        };

        func exchangeCodeForToken(
            providerConfig : ProviderConfig,
            context : Liminal.HttpContext,
            code : Text,
            codeVerifier : ?Text,
        ) : async* Result.Result<TokenInfo, Text> {
            let formData = List.empty<(Text, Text)>();
            List.add(formData, ("grant_type", "authorization_code"));
            List.add(formData, ("code", code));
            List.add(formData, ("redirect_uri", getRedirectUri(providerConfig.name)));
            List.add(formData, ("client_id", providerConfig.clientId));
            List.add(formData, ("client_secret", providerConfig.clientSecret));
            switch (codeVerifier) {
                case (?verifier) List.add(formData, ("code_verifier", verifier));
                case (null) {};
            };
            let formDataText = Text.join(
                "&",
                formData |> List.map<(Text, Text), Text>(
                    _,
                    func(pair : (Text, Text)) : Text = pair.0 # "=" # pair.1,
                )
                |> List.values(_),
            );
            let tokenExchangeRequest : IC.HttpRequestArgs = {
                url = providerConfig.tokenEndpoint;
                max_response_bytes = null; // config overridable
                headers = [
                    {
                        name = "Content-Type";
                        value = "application/x-www-form-urlencoded";
                    },
                    { name = "Accept"; value = "application/json" },
                ];
                body = ?Text.encodeUtf8(formDataText);
                method = #post;
                transform = null; // todo configurable
            };

            let response : IC.HttpRequestResult = await (with cycles = 230_949_972_000) IC.ic.http_request(tokenExchangeRequest);
            if (response.status != 200) {

                let jsonText = Text.decodeUtf8(response.body);
                return #err(
                    "Token exchange failed with status: " # Nat.toText(response.status) # ", body: " # Option.get(jsonText, "No response body")
                );
            };
            let ?jsonText = Text.decodeUtf8(response.body) else return #err("Failed to decode response body");

            let candidBlob = switch (Serde.JSON.fromText(jsonText, null)) {
                case (#ok(candidBlob)) candidBlob;
                case (#err(error)) return #err("Failed to parse JSON: " # error);
            };
            let ?tokenResponse : ?{
                access_token : Text;
                token_type : Text;
                expires_in : ?Int;
                refresh_token : ?Text;
                scope : ?Text;
                id_token : ?Text; // For OpenID Connect
            } = from_candid (candidBlob) else return #err("Invalid token response format");

            context.log(#info, "Token response: " # debug_show (tokenResponse));

            #ok({
                accessToken = tokenResponse.access_token;
                tokenType = tokenResponse.token_type;
                expiresIn = tokenResponse.expires_in;
                refreshToken = tokenResponse.refresh_token;
                scope = tokenResponse.scope;
                idToken = tokenResponse.id_token;
            });
        };

        func handleLogin(providerConfig : ProviderConfig, context : Liminal.HttpContext) : async* Liminal.HttpResponse {

            let stateBytes = await Random.blob();
            let state : Text = BaseX.toBase64(stateBytes.vals(), true);

            let (codeVerifier, codeChallenge) = if (providerConfig.usePKCE) {
                let verifierBytes = await Random.blob();
                let challenge = BaseX.toBase64(Sha256.fromBlob(#sha256, verifierBytes).vals(), true);
                let verifier = BaseX.toBase64(verifierBytes.vals(), true);
                (?verifier, ?challenge);
            } else (null, null);

            let oauthContext : OAuthContext = {
                state = state;
                codeVerifier = codeVerifier;
                redirectAfterAuth = context.getQueryParam("redirect");
                createdAt = Time.now();
            };

            config.store.saveContext(oauthContext);
            let authUrl = buildAuthUrl(providerConfig, state, codeChallenge);

            // return context.buildResponse(#ok, #content(#Record([("url", #Text(authUrl))])));
            context.buildRedirectResponse(authUrl, false);
        };

        func handleCallback(providerConfig : ProviderConfig, context : Liminal.HttpContext) : async* Liminal.HttpResponse {
            let ?code = context.getQueryParam("code") else {
                return context.buildResponse(
                    #badRequest,
                    #error(#message("Missing authorization code")),
                );
            };
            let oauthContext : OAuthContext = switch (context.getQueryParam("state")) {
                case (?state) {
                    let ?oauthContext = config.store.getContext(state) else {
                        return context.buildResponse(
                            #badRequest,
                            #error(#message("Invalid OAuth state")),
                        );
                    };
                    config.store.removeContext(state);
                    oauthContext;
                };
                case (null) return context.buildResponse(
                    #badRequest,
                    #error(#message("Missing OAuth state")),
                );
            };
            // Exchange code for token
            let tokenResult = await* exchangeCodeForToken(providerConfig, context, code, oauthContext.codeVerifier);
            switch (tokenResult) {
                case (#ok(tokenInfo)) {
                    await* config.onLogin(
                        context,
                        {
                            providerConfig;
                            tokenInfo;
                            oauthContext;
                        },
                    );
                };
                case (#err(error)) {
                    return context.buildResponse(
                        #unauthorized,
                        #error(#message("OAuth token exchange failed: " # error)),
                    );
                };
            };
        };
        type RequestInfo = {
            #login : ProviderConfig;
            #callback : ProviderConfig;
            #logout : ProviderConfig;
            #providerNotFound : Text;
            #invalidRoute : Text;
        };
        func parseRequest(context : Liminal.HttpContext) : ?RequestInfo {
            let path = context.getPath();
            if (path.size() < 3 or Text.toLower(path[0]) != "auth") {
                return null;
            };
            let providerName = Text.toLower(path[1]);
            let ?providerConfig = Array.find(
                config.providers,
                func(p : ProviderConfig) : Bool = Text.toLower(p.name) == providerName,
            ) else {
                return ?#providerNotFound(providerName);
            };
            let oauthPath = Text.toLower(path[2]);
            ?(
                switch (oauthPath) {
                    case ("login") #login(providerConfig);
                    case ("callback") #callback(providerConfig);
                    case ("logout") #logout(providerConfig);
                    case (path) #invalidRoute(path);
                }
            );
        };

        {
            handleQuery = func(context : Liminal.HttpContext, next : App.Next) : App.QueryResult {
                let ?requestKind = parseRequest(context) else return next();
                switch (requestKind) {
                    case (#login(_)) {
                        if (context.method != #get) {
                            return #response(
                                context.buildResponse(
                                    #methodNotAllowed,
                                    #error(#message("Method not allowed for OAuth login, expected GET")),
                                )
                            );
                        };
                        return #upgrade;
                    };
                    case (#callback(_)) {
                        if (context.method != #get) {
                            return #response(
                                context.buildResponse(
                                    #methodNotAllowed,
                                    #error(#message("Method not allowed for OAuth callback, expected GET")),
                                )
                            );
                        };
                        return #upgrade;
                    };
                    case (#logout(_)) {
                        if (context.method != #post) {
                            return #response(
                                context.buildResponse(
                                    #methodNotAllowed,
                                    #error(#message("Method not allowed for OAuth logout, expected POST")),
                                )
                            );
                        };
                        #upgrade;
                    };
                    case (#providerNotFound(providerName)) {
                        return #response(
                            context.buildResponse(
                                #notFound,
                                #error(#message("OAuth provider not found: " # providerName)),
                            )
                        );
                    };
                    case (#invalidRoute(path)) {
                        return #response(
                            context.buildResponse(
                                #notFound,
                                #error(#message("Invalid OAuth route: " # path)),
                            )
                        );
                    };
                };
            };
            handleUpdate = func(context : Liminal.HttpContext, next : App.NextAsync) : async* Liminal.HttpResponse {
                let ?requestKind = parseRequest(context) else return await* next();

                switch (requestKind) {
                    case (#login(providerConfig)) {
                        if (context.method != #get) {
                            return context.buildResponse(
                                #methodNotAllowed,
                                #error(#message("Method not allowed for OAuth login, expected GET")),
                            );
                        };
                        return await* handleLogin(providerConfig, context);
                    };
                    case (#callback(providerConfig)) {
                        if (context.method != #get) {
                            return context.buildResponse(
                                #methodNotAllowed,
                                #error(#message("Method not allowed for OAuth callback, expected GET")),
                            );
                        };
                        return await* handleCallback(providerConfig, context);
                    };
                    case (#logout(providerConfig)) {
                        if (context.method != #post) {
                            return context.buildResponse(
                                #methodNotAllowed,
                                #error(#message("Method not allowed for OAuth logout, expected POST")),
                            );
                        };
                        await* config.onLogout(
                            context,
                            {
                                providerConfig;
                            },
                        );
                    };
                    case (#providerNotFound(providerName)) {
                        return context.buildResponse(
                            #notFound,
                            #error(#message("OAuth provider not found: " # providerName)),
                        );
                    };
                    case (#invalidRoute(path)) {
                        return context.buildResponse(
                            #notFound,
                            #error(#message("Invalid OAuth route: " # path)),
                        );
                    };
                };
            };
        };
    };
};
