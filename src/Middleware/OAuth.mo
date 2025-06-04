import Liminal "../";
import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Map "mo:new-base/Map";
import Array "mo:new-base/Array";
import Option "mo:new-base/Option";
import Time "mo:new-base/Time";
import Random "mo:base/Random";
import Blob "mo:new-base/Blob";
import Principal "mo:new-base/Principal";
import Buffer "mo:base/Buffer";
import Iter "mo:new-base/Iter";
import Char "mo:new-base/Char";
import Debug "mo:base/Debug";
import Nat32 "mo:new-base/Nat32";
import Nat8 "mo:new-base/Nat8";
import App "../App";
import Path "../Path";

module {

    // Common OAuth providers configurations
    public let Google = {
        authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth";
        tokenEndpoint = "https://oauth2.googleapis.com/token";
        userInfoEndpoint = ?"https://www.googleapis.com/oauth2/v2/userinfo";
        scopes = ["openid", "profile", "email"];
    };

    public let GitHub = {
        authorizationEndpoint = "https://github.com/login/oauth/authorize";
        tokenEndpoint = "https://github.com/login/oauth/access_token";
        userInfoEndpoint = ?"https://api.github.com/user";
        scopes = ["user:email"];
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

        func generateState() : Text {
            let entropy = Random.Finite(Blob.fromArray([1, 2, 3, 4])); // Use better entropy in production
            switch (entropy.byte()) {
                case (?b) Text.fromChar(Char.fromNat32(Nat32.fromNat(Nat8.toNat(b))));
                case (null) "default_state";
            };
        };

        func generateCodeVerifier() : Text {
            // PKCE code verifier - should be cryptographically random
            "code_verifier_" # generateState();
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

        func exchangeCodeForToken(code : Text, codeVerifier : ?Text) : async* Result.Result<TokenResponse, Text> {
            // This would make an HTTP request to the token endpoint
            // For now, returning a mock response
            #ok({
                accessToken = "mock_access_token";
                tokenType = "Bearer";
                expiresIn = ?3600;
                refreshToken = ?"mock_refresh_token";
                scope = ?Text.join(" ", config.scopes.vals());
                idToken = null;
            });
        };

        func handleLogin(context : Liminal.HttpContext) : Liminal.HttpResponse {
            let state = generateState();
            let codeVerifier = if (config.usePKCE) ?generateCodeVerifier() else null;
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

            return context.buildRedirectResponse(authUrl, false);
        };

        func handleCallback(context : Liminal.HttpContext) : async* Liminal.HttpResponse {
            switch (context.getQueryParam("code"), context.getQueryParam("state")) {
                case (?code, ?state) {
                    switch (config.stateStore.getState(state)) {
                        case (?oauthState) {
                            config.stateStore.removeState(state);

                            // Exchange code for token
                            let tokenResult = await* exchangeCodeForToken(code, oauthState.codeVerifier);
                            switch (tokenResult) {
                                case (#ok(tokenResponse)) {
                                    // Store token and create session
                                    // You'd typically get user info here and create a session
                                    let userId = "user_" # state; // Placeholder
                                    config.stateStore.saveToken(userId, tokenResponse);

                                    let session = switch (context.session) {
                                        case (?s) s;
                                        case (null) context.createSession();
                                    };

                                    // Set session cookie or JWT
                                    session.set("userId", userId);
                                    session.set("authenticated", "true");

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
                        case (null) {
                            return context.buildResponse(
                                #badRequest,
                                #error(#message("Invalid OAuth state")),
                            );
                        };
                    };
                };
                case (_, _) {
                    return context.buildResponse(
                        #badRequest,
                        #error(#message("Missing authorization code or state")),
                    );
                };
            };
        };

        {
            handleQuery = func(context : Liminal.HttpContext, next : App.Next) : App.QueryResult {
                let path = context.getPath();
                if (Path.equalToUrl(path, "/auth/login") and context.method == #get) {
                    return #upgrade;
                };
                if (Path.equalToUrl(path, "/auth/callback") and context.method == #get) {
                    return #upgrade;
                };
                if (Path.equalToUrl(path, "/auth/logout") and context.method == #post) {
                    return #upgrade;
                };
                next();
            };
            handleUpdate = func(context : Liminal.HttpContext, next : App.NextAsync) : async* Liminal.HttpResponse {
                let path = context.getPath();

                // Handle OAuth authorization initiation
                if (Path.equalToUrl(path, "/auth/login") and context.method == #get) {
                    return handleLogin(context);
                };

                // Handle OAuth callback
                if (Path.equalToUrl(path, "/auth/callback") and context.method == #get) {
                    return await* handleCallback(context);
                };

                // Handle logout
                if (Path.equalToUrl(path, "/auth/logout") and context.method == #post) {
                    context.session := null;
                    return context.buildRedirectResponse("/", false);
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
