import App "../App";
import HttpContext "../HttpContext";
import Text "mo:new-base/Text";
import Time "mo:new-base/Time";
import Nat "mo:new-base/Nat";
import Array "mo:new-base/Array";
import List "mo:new-base/List";
import Int "mo:new-base/Int";
import Runtime "mo:new-base/Runtime";
import Map "mo:new-base/Map";
import Random "mo:new-base/Random";
import Session "../Session";
import BaseX "mo:base-x-encoder";
import NatX "mo:xtended-numbers/NatX";
import Buffer "mo:base/Buffer";

module {
    // Configuration for the middleware
    public type Config = {
        cookieName : Text;
        idleTimeout : Nat; // Seconds
        cookieOptions : CookieOptions;
        store : SessionStore;
        idGenerator : () -> async* Text;
    };

    // Stable storage for persisting session data
    public type SessionStore = {
        get : (sessionId : Text) -> ?SessionData;
        set : (sessionId : Text, data : SessionData) -> ();
        delete : (sessionId : Text) -> ();
    };

    public type CookieOptions = {
        path : Text;
        secure : Bool;
        httpOnly : Bool;
        sameSite : ?SameSiteOption;
        maxAge : ?Nat;
    };

    public type SameSiteOption = {
        #strict;
        #lax;
        #none;
    };

    // Actual session data structure
    public type SessionData = {
        id : Text;
        data : [(Text, Text)];
        createdAt : Int;
        expiresAt : Int;
    };

    /// Creates a default session configuration with standard settings
    /// - Parameter store: The session store to use for persisting session data
    /// - Returns: A Config object with sensible defaults (20-minute timeout, secure cookies, etc.)
    public func defaultConfig(store : SessionStore) : Config {
        {
            cookieName = "session";
            idleTimeout = 20 * 60; // 20 minutes
            cookieOptions = {
                path = "/";
                secure = true;
                httpOnly = true;
                sameSite = ?#lax;
                maxAge = null;
            };
            store = store;
            idGenerator = generateRandomId;
        };
    };

    /// Creates a session middleware with default configuration and in-memory storage
    /// This is a convenience function for quick setup without custom configuration
    /// - Returns: A ready-to-use session middleware with standard settings
    public func inMemoryDefault() : App.Middleware {
        new(defaultConfig(buildInMemoryStore()));
    };

    /// Creates a new session middleware with custom configuration
    /// - Parameter config: The session configuration object defining behavior
    /// - Returns: A middleware that handles session creation, validation, and cleanup
    public func new(config : Config) : App.Middleware {
        {
            name = "Session";
            handleQuery = func(context : HttpContext.HttpContext, next : App.Next) : App.QueryResult {
                // Get or create session
                switch (getSessionId(context, config)) {
                    case (null) ();
                    case (?sessionId) {
                        // Attach session to the context
                        context.session := ?buildSessionInterface(sessionId, config.store);
                    };
                };

                // Continue with the middleware chain
                next();
            };
            handleUpdate = func(context : HttpContext.HttpContext, next : App.NextAsync) : async* App.HttpResponse {
                // Get or create session
                let sessionId = await* getOrCreateSessionId(context, config);

                // Attach session to the context
                context.session := ?buildSessionInterface(sessionId, config.store);

                // Continue with the middleware chain
                let response = await* next();

                // Set session cookie in response if needed
                addSessionCookie(response, context, config);
            };
        };
    };

    /// Generates a cryptographically secure random session ID
    /// Uses crypto-grade randomness to create a 128-bit (16-byte) session identifier
    /// - Returns: A hexadecimal string representation of the random session ID
    public func generateRandomId() : async* Text {
        let rand = Random.crypto();

        // Generate two 64-bit values (16 bytes total)
        let part1 = await* rand.nat64();
        let part2 = await* rand.nat64();

        let buffer = Buffer.Buffer<Nat8>(16);
        NatX.encodeNat64(buffer, part1, #msb);
        NatX.encodeNat64(buffer, part2, #msb);
        BaseX.toHex(buffer.vals(), { isUpper = false; prefix = #none });
    };

    /// Creates an in-memory session store with automatic cleanup of expired sessions
    /// This store is not persistent across canister upgrades
    /// - Returns: A SessionStore implementation using in-memory storage
    public func buildInMemoryStore() : SessionStore {
        let sessions = Map.empty<Text, SessionData>();
        func cleanupExpiredSessions() : () {
            let now = Time.now();
            Map.forEach(
                sessions,
                func(sessionId : Text, data : SessionData) : () {
                    if (data.expiresAt < now) {
                        Map.remove(sessions, Text.compare, sessionId);
                    };
                },
            );
        };
        {
            get = func(sessionId : Text) : ?SessionData {
                Map.get(sessions, Text.compare, sessionId);
            };
            set = func(sessionId : Text, data : SessionData) : () {
                cleanupExpiredSessions();
                Map.add(sessions, Text.compare, sessionId, data);
            };
            delete = func(sessionId : Text) : () {
                Map.remove(sessions, Text.compare, sessionId);
                cleanupExpiredSessions();
            };
        };
    };

    private func getSessionId(context : HttpContext.HttpContext, config : Config) : ?Text {
        context.getCookie(config.cookieName);
    };

    // Helper to get or create a session
    private func getOrCreateSessionId(context : HttpContext.HttpContext, config : Config) : async* Text {
        switch (getSessionId(context, config)) {
            case (?id) return id;
            case (null) {
                let now = Time.now();
                let sessionExp = now + Int.abs(config.idleTimeout * 1_000_000_000);
                let sessionId = await* config.idGenerator();
                context.log(#debug_, "Created new session: " # sessionId);
                let data = {
                    id = sessionId;
                    data = [];
                    createdAt = now;
                    lastAccessedAt = now;
                    expiresAt = sessionExp;
                };
                config.store.set(sessionId, data);
                data.id;
            };
        };
    };

    private func buildSessionInterface(sessionId : Text, store : SessionStore) : Session.Session {

        // Create session interface
        {
            id = sessionId;

            get = func(key : Text) : ?Text {
                let ?data = store.get(sessionId) else return null;
                // Find the key in the data array
                let ?entry = Array.find(data.data, func((k, _) : (Text, Text)) : Bool { k == key }) else return null;
                // Deserialize the value
                ?entry.1;
            };

            set = func(key : Text, value : Text) : () {
                let ?data = store.get(sessionId) else Runtime.trap("Session not found to set data: " # sessionId);

                // Remove existing key if present
                let filteredData = Array.filter(
                    data.data,
                    func((k, _) : (Text, Text)) : Bool {
                        k != key;
                    },
                );

                let newData = {
                    data with
                    data = Array.concat(filteredData, [(key, value)]);
                    lastAccessedAt = Time.now();
                };

                // Save back to storage
                store.set(data.id, newData);
            };

            remove = func(key : Text) : () {
                let ?data = store.get(sessionId) else Runtime.trap("Session not found to remove data: " # sessionId);

                let filteredData = Array.filter(
                    data.data,
                    func((k, _) : (Text, Text)) : Bool {
                        k != key;
                    },
                );

                let newData = {
                    data with
                    data = filteredData;
                    lastAccessedAt = Time.now();
                };

                // Save back to storage
                store.set(data.id, newData);
            };

            clear = func() : () {
                store.delete(sessionId);
            };
        };
    };

    // Helper to add session cookie to response
    private func addSessionCookie(
        response : App.HttpResponse,
        context : HttpContext.HttpContext,
        config : Config,
    ) : App.HttpResponse {
        let ?session = context.session else return response;
        let cookieValue = session.id;
        let cookieOptions = config.cookieOptions;

        let cookieStr = buildCookieString(config.cookieName, cookieValue, cookieOptions);

        // Add or replace Set-Cookie header
        let headers = List.fromArray<(Text, Text)>(response.headers);
        List.add(headers, ("Set-Cookie", cookieStr));

        {
            response with
            headers = List.toArray(headers);
        };
    };

    // Helper to build cookie string
    private func buildCookieString(
        name : Text,
        value : Text,
        options : CookieOptions,
    ) : Text {
        var cookieStr = name # "=" # value;

        // Add path
        cookieStr #= "; Path=" # options.path;

        // Add secure flag if needed
        if (options.secure) {
            cookieStr #= "; Secure";
        };

        // Add httpOnly flag if needed
        if (options.httpOnly) {
            cookieStr #= "; HttpOnly";
        };

        // Add SameSite if specified
        switch (options.sameSite) {
            case (?#strict) cookieStr #= "; SameSite=Strict";
            case (?#lax) cookieStr #= "; SameSite=Lax";
            case (?#none) cookieStr #= "; SameSite=None";
            case (null) {};
        };

        // Add MaxAge if specified
        switch (options.maxAge) {
            case (?maxAge) cookieStr #= "; Max-Age=" # Nat.toText(maxAge);
            case (null) {};
        };

        cookieStr;
    };

};
