import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Blob "mo:new-base/Blob";
import Nat "mo:new-base/Nat";
import Array "mo:new-base/Array";
import Float "mo:new-base/Float";
import Time "mo:new-base/Time";
import Debug "mo:new-base/Debug";
import Json "mo:json";
import Base64 "mo:base64";
import HMAC "mo:hmac";
import ECDSA "mo:ecdsa";
import Sha256 "mo:sha2/Sha256";
import Bool "mo:base/Bool";

module {

    // Complete JWT Token
    public type Token = {
        header : [(Text, Json.Json)];
        payload : [(Text, Json.Json)];
        signature : SignatureInfo;
    };

    public type SignatureInfo = {
        algorithm : Text;
        value : Blob;
        message : Blob;
    };

    public type ValidationOptions = {
        expiration : Bool;
        notBefore : Bool;
        issuer : IssuerValidationKind;
        signature : SignatureValidationKind;
        audience : AudienceValidationKind;
    };

    public type AudienceValidationKind = {
        #skip;
        #one : Text;
        #any : [Text];
        #all : [Text];
    };

    public type IssuerValidationKind = {
        #skip;
        #one : Text;
        #any : [Text];
    };

    public type SignatureValidationKind = {
        #skip;
        #key : SignatureVerificationKey;
        #keys : [SignatureVerificationKey];
        #resolver : (issuer : ?Text) -> Iter.Iter<SignatureVerificationKey>;
    };

    public type SignatureVerificationKeyKind = {
        #symmetric;
        #ecdsa;
    };

    public type SignatureVerificationKey = {
        #symmetric : Blob;
        #ecdsa : ECDSA.PublicKey;
    };

    public type StandardHeader = {
        // Required field
        alg : Text; // Algorithm (required by JWT spec)

        // Common optional header fields
        typ : ?Text; // Token type (usually "JWT")
        cty : ?Text; // Content type
        kid : ?Text; // Key ID
        x5c : ?[Text]; // x.509 Certificate Chain
        x5u : ?Text; // x.509 Certificate Chain URL
        crit : ?[Text]; // Critical headers
    };

    public type StandardPayload = {
        // Standard claims
        iss : ?Text; // Issuer
        sub : ?Text; // Subject
        aud : ?[Text]; // Audience (can be string or array)
        exp : ?Float; // Expiration Time (seconds since epoch)
        nbf : ?Float; // Not Before (seconds since epoch)
        iat : ?Float; // Issued at (seconds since epoch)
        jti : ?Text; // JWT ID
    };

    public func parseStandardHeader(headerFields : [(Text, Json.Json)]) : Result.Result<StandardHeader, Text> {
        var algValue : ?Text = null;
        var typValue : ?Text = null;
        var ctyValue : ?Text = null;
        var kidValue : ?Text = null;
        var x5cValue : ?[Text] = null;
        var x5uValue : ?Text = null;
        var critValue : ?[Text] = null;

        for ((key, value) in headerFields.vals()) {
            switch (key) {
                case ("alg") {
                    switch (value) {
                        case (#string(v)) { algValue := ?v };
                        case (_) return #err("Invalid JWT: 'alg' must be a string value");
                    };
                };
                case ("typ") {
                    switch (value) {
                        case (#string(v)) { typValue := ?v };
                        case (_) return #err("Invalid JWT: 'typ' must be a string value");
                    };
                };
                case ("cty") {
                    switch (value) {
                        case (#string(v)) { ctyValue := ?v };
                        case (_) return #err("Invalid JWT: 'cty' must be a string value");
                    };
                };
                case ("kid") {
                    switch (value) {
                        case (#string(v)) { kidValue := ?v };
                        case (_) return #err("Invalid JWT: 'kid' must be a string value");
                    };
                };
                case ("x5u") {
                    switch (value) {
                        case (#string(v)) { x5uValue := ?v };
                        case (_) return #err("Invalid JWT: 'x5u' must be a string value");
                    };
                };
                case ("x5c") {
                    switch (value) {
                        case (#array(arr)) {
                            let strArray = Array.filterMap<Json.Json, Text>(
                                arr,
                                func(item) {
                                    switch (item) {
                                        case (#string(s)) ?s;
                                        case (_) null;
                                    };
                                },
                            );
                            if (strArray.size() == arr.size()) {
                                x5cValue := ?strArray;
                            } else {
                                return #err("Invalid JWT: 'x5c' must be an array of strings");
                            };
                        };
                        case (_) return #err("Invalid JWT: 'x5c' must be an array");
                    };
                };
                case ("crit") {
                    switch (value) {
                        case (#array(arr)) {
                            let strArray = Array.filterMap<Json.Json, Text>(
                                arr,
                                func(item) {
                                    switch (item) {
                                        case (#string(s)) ?s;
                                        case _ null;
                                    };
                                },
                            );
                            if (strArray.size() == arr.size()) {
                                critValue := ?strArray;
                            } else {
                                return #err("Invalid JWT: 'crit' must be an array of strings");
                            };
                        };
                        case (_) return #err("Invalid JWT: 'crit' must be an array");
                    };
                };
                case (_) {
                    // Other fields don't need special handling
                };
            };
        };

        // Ensure required fields are present
        switch (algValue) {
            case (null) return #err("Invalid JWT: Missing required 'alg' field");
            case (?alg) {
                return #ok({
                    alg = alg;
                    typ = typValue;
                    cty = ctyValue;
                    kid = kidValue;
                    x5c = x5cValue;
                    x5u = x5uValue;
                    crit = critValue;
                });
            };
        };
    };

    public func parseStandardPayload(payloadFields : [(Text, Json.Json)]) : Result.Result<StandardPayload, Text> {
        var issValue : ?Text = null;
        var subValue : ?Text = null;
        var audValue : ?[Text] = null;
        var expValue : ?Float = null;
        var nbfValue : ?Float = null;
        var iatValue : ?Float = null;
        var jtiValue : ?Text = null;

        for ((key, value) in payloadFields.vals()) {
            switch (key) {
                case ("iss") {
                    switch (value) {
                        case (#string(v)) { issValue := ?v };
                        case (_) return #err("Invalid JWT: 'iss' must be a string value");
                    };
                };
                case ("sub") {
                    switch (value) {
                        case (#string(v)) { subValue := ?v };
                        case (_) return #err("Invalid JWT: 'sub' must be a string value");
                    };
                };
                case ("aud") {
                    switch (value) {
                        case (#string(v)) { audValue := ?[v] };
                        case (#array(arr)) {
                            let strArray = Array.filterMap<Json.Json, Text>(
                                arr,
                                func(item) {
                                    switch (item) {
                                        case (#string(s)) ?s;
                                        case _ null;
                                    };
                                },
                            );
                            if (strArray.size() == arr.size()) {
                                audValue := ?strArray;
                            } else {
                                return #err("Invalid JWT: 'aud' must be a string or array of strings");
                            };
                        };
                        case (_) return #err("Invalid JWT: 'aud' must be a string or array");
                    };
                };
                case ("exp") {
                    switch (value) {
                        case (#number(#float(v))) {
                            expValue := ?v;
                        };
                        case (#number(#int(v))) {
                            expValue := ?Float.fromInt(v);
                        };
                        case (_) return #err("Invalid JWT: 'exp' must be a number");
                    };
                };
                case ("nbf") {
                    switch (value) {
                        case (#number(#float(v))) {
                            nbfValue := ?v;
                        };
                        case (#number(#int(v))) {
                            nbfValue := ?Float.fromInt(v);
                        };
                        case (_) return #err("Invalid JWT: 'nbf' must be a number");
                    };
                };
                case ("iat") {
                    switch (value) {
                        case (#number(#float(v))) {
                            iatValue := ?v;
                        };
                        case (#number(#int(v))) {
                            iatValue := ?Float.fromInt(v);
                        };
                        case (_) return #err("Invalid JWT: 'iat' must be a number");
                    };
                };
                case ("jti") {
                    switch (value) {
                        case (#string(v)) { jtiValue := ?v };
                        case (_) return #err("Invalid JWT: 'jti' must be a string value");
                    };
                };
                case (_) {
                    // Other fields don't need special handling
                };
            };
        };

        // No required fields in payload, so we can return the processed object
        return #ok({
            iss = issValue;
            sub = subValue;
            aud = audValue;
            exp = expValue;
            nbf = nbfValue;
            iat = iatValue;
            jti = jtiValue;
        });
    };

    // Comprehensive validation
    public func validate(token : Token, options : ValidationOptions) : Result.Result<(), Text> {
        // Check time-based claims if enabled
        if (options.expiration and not validateExpiration(token)) {
            return #err("Token has expired");
        };

        if (options.notBefore and not validateNotBefore(token)) {
            return #err("Token is not yet valid (nbf claim)");
        };

        // Check signature if key provided
        switch (verifySignature(token, options.signature)) {
            case (#err(e)) return #err(e);
            case (#ok(false)) return #err("Invalid signature");
            case (#ok(true)) {
                // Signature valid, continue
            };
        };

        let aud : [Text] = switch (getPayloadValue(token, "aud")) {
            case (null or ?#null_) [];
            case (?#string(aud)) [aud];
            case (?#array(audArray)) {
                let strArray = Array.filterMap<Json.Json, Text>(
                    audArray,
                    func(item) {
                        switch (item) {
                            case (#string(s)) ?s;
                            case (_) null;
                        };
                    },
                );
                if (strArray.size() == audArray.size()) {
                    strArray;
                } else {
                    return #err("Invalid JWT: 'aud' must be a string or array of strings");
                };
            };
            case (_) return #err("Invalid JWT: 'aud' must be a string or array");
        };
        // Check audience if specified
        switch (options.audience) {
            case (#skip) (); // No audience validation needed
            case (#one(audience)) {
                // Check if audience matches
                if (Array.indexOf<Text>(audience, aud, Text.equal) == null) {
                    return #err("Token audience does not match expected audience");
                };
            };
            case (#any(audiences)) {
                // Check if any of the audiences match
                let found = Array.any<Text>(
                    audiences,
                    func(a : Text) : Bool = Array.indexOf<Text>(a, aud, Text.equal) != null,
                );
                if (not found) {
                    return #err("Token audience does not match expected audience");
                };
            };
            case (#all(audiences)) {
                // Check if all audiences match
                let found = Array.all<Text>(
                    audiences,
                    func(a) : Bool = Array.indexOf<Text>(a, aud, Text.equal) != null,
                );
                if (not found) {
                    return #err("Token audience does not match expected audience");
                };
            };
        };

        // All validations passed
        return #ok;
    };

    public func parse(jwt : Text) : Result.Result<Token, Text> {
        // Split JWT into parts
        let parts = Text.split(jwt, #char('.')) |> Iter.toArray(_);

        if (parts.size() != 3) {
            return #err("Invalid JWT format - expected 3 parts, found " # Nat.toText(parts.size()));
        };
        let base64Engine = Base64.Base64(#v(Base64.V2), ?true);
        // TODO handle error from engine
        let headerJson = switch (parseJsonObj(base64Engine.decode(parts[0]), "header")) {
            case (#err(e)) return #err("Unable to decode header: " # debug_show (e));
            case (#ok(headerJson)) headerJson;
        };
        let signatureAlgorithm = switch (getValue(headerJson, "alg")) {
            case (null) return #err("Invalid JWT: Missing 'alg' field in header");
            case (?#string(alg)) alg;
            case (_) return #err("Invalid JWT: 'alg' must be a string");
        };

        // TODO handle error from engine
        let payloadJson = switch (parseJsonObj(base64Engine.decode(parts[1]), "payload")) {
            case (#err(e)) return #err("Unable to decode payload: " # debug_show (e));
            case (#ok(payloadJson)) payloadJson;
        };

        // Decode base64url signature to bytes
        let signatureBytes = Blob.fromArray(base64Engine.decode(parts[2])); // TODO handle error from engine
        let messageBytes = Blob.fromArray(base64Engine.decode(parts[0] # "." # parts[1])); // TODO handle error from engine

        Debug.print("Message: " # debug_show (messageBytes));

        #ok({
            header = headerJson;
            payload = payloadJson;
            signature = {
                algorithm = signatureAlgorithm;
                value = signatureBytes;
                message = messageBytes;
            };
        });
    };

    public func getHeaderValue(token : Token, key : Text) : ?Json.Json {
        getValue(token.header, key);
    };

    public func getPayloadValue(token : Token, key : Text) : ?Json.Json {
        getValue(token.payload, key);
    };

    private func getValue(a : [(Text, Json.Json)], key : Text) : ?Json.Json {
        for ((k, v) in a.vals()) {
            if (k == key) return ?v;
        };
        return null;
    };

    private func validateExpiration(token : Token) : Bool {

        switch (getPayloadValue(token, "exp")) {
            case (null or ?#null_) true; // No expiration claim, consider valid by default
            case (?#number(#float(expTime))) Time.now() < Float.toInt(expTime * 1_000_000_000);
            case (?#number(#int(expTime))) Time.now() < (expTime * 1_000_000_000);
            case (_) false; // Invalid type for expiration claim
        };
    };

    // Validate "not before" time
    private func validateNotBefore(token : Token) : Bool {
        switch (getPayloadValue(token, "nbf")) {
            case (null or ?#null_) true; // No nbf claim, consider valid by default
            case (?#number(#float(nbfTime))) Time.now() >= Float.toInt(nbfTime * 1_000_000_000);
            case (?#number(#int(nbfTime))) Time.now() >= (nbfTime * 1_000_000_000);
            case (_) false; // Invalid type for expiration claim
        };
    };

    // Verify signature based on algorithm
    private func verifySignature(token : Token, signatureValidationKind : SignatureValidationKind) : Result.Result<Bool, Text> {
        let keyResolver = switch (signatureValidationKind) {
            case (#skip) return #ok(true);
            case (#key(key)) func(_ : ?Text) : Iter.Iter<SignatureVerificationKey> = Iter.singleton(key);
            case (#keys(keys)) func(_ : ?Text) : Iter.Iter<SignatureVerificationKey> = keys.vals();
            case (#resolver(resolver)) resolver;
        };

        // Verify based on algorithm
        type HashAlgorithm = {
            #sha256;
            // #sha384;
            // #sha512;
        };
        let issuer = switch (getPayloadValue(token, "iss")) {
            case (null or ?#null_) null;
            case (?#string(iss)) ?iss;
            case (_) return #err("Invalid JWT: 'iss' must be a string");
        };
        let keys = keyResolver(issuer);
        let verifySignatureWithKey = switch (token.signature.algorithm) {
            case ("HS256") func(key : SignatureVerificationKey) : Bool {
                let #symmetric(symmetricKey) = key else return false;
                verifyHmacSignature(#sha256, token.signature.message.vals(), symmetricKey, token.signature.value);
            };
            // TODO
            // case ("HS384")
            // case ("HS512")
            case ("ES256" or "ES256K") func(key : SignatureVerificationKey) : Bool {
                let #ecdsa(ecdsaKey) = key else return false;
                verifyEcdsaSignature(#sha256, token.signature.message.vals(), ecdsaKey, token.signature.value);
            };
            // TODO
            // case ("ES384")
            // case ("ES512")
            case ("none") return #err("Algorithm 'none' is not supported for security reasons");
            case (_) return #err("Unsupported algorithm: " # token.signature.algorithm);
        };
        label f for (key in keys) {
            let isValid = verifySignatureWithKey(key);
            if (isValid) return #ok(true);
        };
        return #ok(false);
    };

    private func verifyEcdsaSignature(
        hashAlgorithm : Sha256.Algorithm,
        message : Iter.Iter<Nat8>,
        publicKey : ECDSA.PublicKey,
        signature : Blob,
    ) : Bool {
        let ?sig = ECDSA.signatureFromBytes(signature.vals(), publicKey.curve, #raw) else return false;
        let hash = switch (hashAlgorithm) {
            case (#sha256) Sha256.fromIter(#sha256, message);
            case (#sha224) Sha256.fromIter(#sha224, message);
        };
        publicKey.verify(hash.vals(), sig);
    };

    private func verifyHmacSignature(
        hashAlgorithm : HMAC.HashAlgorithm,
        message : Iter.Iter<Nat8>,
        key : Blob,
        signature : Blob,
    ) : Bool {
        // HMAC verification logic
        let hmac = HMAC.generate(
            Blob.toArray(key),
            message,
            hashAlgorithm,
        );
        Blob.equal(hmac, signature);
    };

    private func parseJsonObj(
        jsonBytes : [Nat8],
        label_ : Text,
    ) : Result.Result<[(Text, Json.Json)], Text> {
        let ?jsonText = Text.decodeUtf8(Blob.fromArray(jsonBytes)) else {
            return #err("Unable to decode " # label_ # " as UTF-8");
        };

        switch (Json.parse(jsonText)) {
            case (#err(e)) return #err("Unable to decode " # label_ # " as JSON: " # debug_show (e));
            case (#ok(json)) switch (Json.getAsObject(json, "")) {
                case (#err(e)) return #err("Invalid " # label_ # " JSON: " # debug_show (e));
                case (#ok(jsonObj)) #ok(jsonObj);
            };
        };
    };
};
