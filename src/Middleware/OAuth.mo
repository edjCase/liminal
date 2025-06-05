import Liminal "../";
import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Map "mo:new-base/Map";
import Time "mo:new-base/Time";
import Random "mo:base/Random";
import Buffer "mo:base/Buffer";
import Nat "mo:new-base/Nat";
import App "../App";
import Path "../Path";
import IC "ic:aaaaa-aa";
import Serde "mo:serde";
import List "mo:new-base/List";
import BaseX "mo:base-x-encoder";
import Option "mo:new-base/Option";

module {

    // Common OAuth providers configurations
    public let Google = {
        authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth";
        tokenEndpoint = "https://oauth2.googleapis.com/token";
        userInfoEndpoint = ?"https://www.googleapis.com/oauth2/v2/userinfo";
    };

    public let GitHub = {
        authorizationEndpoint = "https://github.com/login/oauth/authorize";
        tokenEndpoint = "https://github.com/login/oauth/access_token";
        userInfoEndpoint = ?"https://api.github.com/user";
    };

    public type Config = {
        clientId : Text;
        clientSecret : Text;
        redirectUri : Text;
        authorizationEndpoint : Text;
        tokenEndpoint : Text;
        userInfoEndpoint : ?Text;
        scopes : [Text];
        // Optional PKCE support
        usePKCE : Bool;
        // Where to store OAuth state/tokens
        stateStore : StateStore;
    };

    public type StateStore = {
        saveState : (key : Text, state : OAuthState) -> ();
        getState : (key : Text) -> ?OAuthState;
        removeState : (key : Text) -> ();
        saveToken : (userId : Text, token : TokenResponse) -> ();
        getToken : (userId : Text) -> ?TokenResponse;
    };

    public type OAuthState = {
        state : Text;
        codeVerifier : ?Text; // For PKCE
        redirectAfterAuth : ?Text;
        createdAt : Int;
    };

    public type TokenResponse = {
        accessToken : Text;
        tokenType : Text;
        expiresIn : ?Int;
        refreshToken : ?Text;
        scope : ?Text;
        idToken : ?Text; // For OpenID Connect
    };

    public type UserInfo = {
        sub : Text;
        name : ?Text;
        email : ?Text;
        picture : ?Text;
    };

    // Simple in-memory state store (you might want persistent storage)
    public func inMemoryStateStore() : StateStore {
        var states = Map.empty<Text, OAuthState>();
        var tokens = Map.empty<Text, TokenResponse>();

        {
            saveState = func(key : Text, state : OAuthState) {
                Map.add(states, Text.compare, key, state);
            };
            getState = func(key : Text) : ?OAuthState {
                Map.get(states, Text.compare, key);
            };
            removeState = func(key : Text) {
                ignore Map.delete<Text, OAuthState>(states, Text.compare, key);
            };
            saveToken = func(userId : Text, token : TokenResponse) {
                Map.add(tokens, Text.compare, userId, token);
            };
            getToken = func(userId : Text) : ?TokenResponse {
                Map.get(tokens, Text.compare, userId);
            };
        };
    };

    public func new(config : Config) : App.Middleware {

        func generateState() : async* Text {
            let randBytes = await Random.blob();
            BaseX.toBase64(randBytes.vals(), true);
        };

        func generateCodeVerifier(state : Text) : Text {
            // PKCE code verifier - should be cryptographically random
            "code_verifier_" # state;
        };

        func generateCodeChallenge(verifier : Text) : Text {
            // In production, this should be SHA256(verifier) base64url encoded
            // For now, using a simple transformation
            "challenge_" # verifier;
        };

        func buildAuthUrl(state : Text, codeChallenge : ?Text) : Text {
            let baseUrl = config.authorizationEndpoint;
            let params = Buffer.Buffer<Text>(8);

            params.add("response_type=code");
            params.add("client_id=" # config.clientId);
            params.add("redirect_uri=" # config.redirectUri);
            params.add("state=" # state);
            params.add("scope=" # Text.join(" ", config.scopes.vals()));

            switch (codeChallenge) {
                case (?challenge) {
                    params.add("code_challenge=" # challenge);
                    params.add("code_challenge_method=S256");
                };
                case (null) {};
            };

            baseUrl # "?" # Text.join("&", params.vals());
        };

        func exchangeCodeForToken(context : Liminal.HttpContext, code : Text, codeVerifier : ?Text) : async* Result.Result<TokenResponse, Text> {
            let formData = List.empty<(Text, Text)>();
            List.add(formData, ("grant_type", "authorization_code"));
            List.add(formData, ("code", code));
            List.add(formData, ("redirect_uri", config.redirectUri));
            List.add(formData, ("client_id", config.clientId));
            List.add(formData, ("client_secret", config.clientSecret));
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
            let tokenExchangeRequest : IC.http_request_args = {
                url = config.tokenEndpoint;
                max_response_bytes = ?1024; // config overridable
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

            let response : IC.http_request_result = await (with cycles = 230_949_972_000) IC.http_request(tokenExchangeRequest);
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

        func handleLogin(context : Liminal.HttpContext) : async* Liminal.HttpResponse {
            let state = await* generateState();
            let codeVerifier = if (config.usePKCE) ?generateCodeVerifier(state) else null;
            let codeChallenge = switch (codeVerifier) {
                case (?verifier) ?generateCodeChallenge(verifier);
                case (null) null;
            };

            let oauthState : OAuthState = {
                state = state;
                codeVerifier = codeVerifier;
                redirectAfterAuth = context.getQueryParam("redirect");
                createdAt = Time.now();
            };

            config.stateStore.saveState(state, oauthState);
            let authUrl = buildAuthUrl(state, codeChallenge);

            return context.buildResponse(#ok, #content(#Record([("url", #Text(authUrl))])));
        };

        func getUserInfo(context : Liminal.HttpContext, accessToken : Text, endpoint : Text) : async* Result.Result<UserInfo, Text> {

            let userInfoRequest : IC.http_request_args = {
                url = endpoint;
                max_response_bytes = null; // config overridable
                headers = [
                    {
                        name = "Authorization";
                        value = "Bearer " # accessToken;
                    },
                    { name = "Accept"; value = "application/json" },
                ];
                body = null;
                method = #get;
                transform = null; // todo configurable
            };

            let response : IC.http_request_result = await (with cycles = 230_949_972_000) IC.http_request(userInfoRequest);
            if (response.status != 200) {
                return #error(#message("Failed to fetch user info: " # Nat.toText(response.status)));
            };

            let ?jsonText = Text.decodeUtf8(response.body) else return #error(#message("Failed to decode user info response body"));

            let candidBlob = switch (Serde.JSON.fromText(jsonText, null)) {
                case (#ok(candidBlob)) candidBlob;
                case (#err(error)) return #error(#message("Failed to parse user info JSON: " # error));
            };
            let ?userInfo : ?{
                sub : Text;
                name : ?Text;
                email : ?Text;
                picture : ?Text;
            } = from_candid (candidBlob) else return #error(#message("Invalid user info format"));

            context.log(#info, "User info: " # debug_show (userInfo));

            userInfo;
        };

        func handleCallback(context : Liminal.HttpContext) : async* Liminal.HttpResponse {
            let ?code = context.getQueryParam("code") else {
                return context.buildResponse(
                    #badRequest,
                    #error(#message("Missing authorization code")),
                );
            };
            let oauthState = switch (context.getQueryParam("state")) {
                case (?state) {
                    let ?oauthState = config.stateStore.getState(state) else {
                        return context.buildResponse(
                            #badRequest,
                            #error(#message("Invalid OAuth state")),
                        );
                    };
                    config.stateStore.removeState(state);
                    oauthState;
                };
                case (null) ({
                    codeVerifier = null;
                    redirectAfterAuth = null;
                });
            };
            // Exchange code for token
            let tokenResult = await* exchangeCodeForToken(context, code, oauthState.codeVerifier);
            switch (tokenResult) {
                case (#ok(tokenResponse)) {
                    let userInfo = await* getUserInfo();
                    let userId = ""; // TODO
                    config.stateStore.saveToken(userId, tokenResponse);

                    // TODO set identity

                    let redirectUrl = switch (oauthState.redirectAfterAuth) {
                        case (?url) url;
                        case (null) "/";
                    };

                    return context.buildRedirectResponse(redirectUrl, false);
                };
                case (#err(error)) {
                    return context.buildResponse(
                        #unauthorized,
                        #error(#message("OAuth token exchange failed: " # error)),
                    );
                };
            };
        };

        let loginPath : Path.Path = ["auth", "login"];
        let callbackPath : Path.Path = ["auth", "callback"];
        let logoutPath : Path.Path = ["auth", "logout"];

        {
            handleQuery = func(context : Liminal.HttpContext, next : App.Next) : App.QueryResult {
                let path = context.getPath();
                switch (context.method) {
                    case (#get) {
                        if (path == loginPath or path == callbackPath) {
                            return #upgrade;
                        };
                    };
                    case (#post) {
                        if (path == logoutPath) {
                            return #upgrade;
                        };
                    };
                    case (_) ();
                };
                next();
            };
            handleUpdate = func(context : Liminal.HttpContext, next : App.NextAsync) : async* Liminal.HttpResponse {
                let path = context.getPath();

                switch (context.method) {
                    case (#get) {
                        if (path == loginPath) {
                            return await* handleLogin(context);
                        };
                        if (path == callbackPath) {
                            return await* handleCallback(context);
                        };
                    };
                    case (#post) {
                        if (path == logoutPath) {
                            context.session := null;
                            return context.buildRedirectResponse("/", false);
                        };
                    };
                    case (_) ();
                };

                // Continue to next middleware
                await* next();
            };
        };
    };

    // Get current user's OAuth token
    public func getUserToken(context : Liminal.HttpContext, stateStore : StateStore) : ?TokenResponse {
        let ?session = context.session else return null;
        let ?userId = session.get("userId") else return null;
        stateStore.getToken(userId);
    };
};
