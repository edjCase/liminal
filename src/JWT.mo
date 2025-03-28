import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Blob "mo:new-base/Blob";
import Nat "mo:new-base/Nat";
import Array "mo:new-base/Array";
import Float "mo:new-base/Float";
import Time "mo:new-base/Time";
import Option "mo:new-base/Option";
import Runtime "mo:new-base/Runtime";
import Debug "mo:new-base/Debug";
import Json "mo:json";
import Base64 "mo:base64";
import HMAC "mo:hmac";
import DER "./DER";
import ECDSA "mo:ecdsa";
import Curve "mo:ecdsa/curve";
import Sha256 "mo:sha2/Sha256";
import Bool "mo:base/Bool";

module {
    public type Header = {
        // Required field
        alg : Text; // Algorithm (required by JWT spec)

        // Common optional header fields
        typ : ?Text; // Token type (usually "JWT")
        cty : ?Text; // Content type
        kid : ?Text; // Key ID
        x5c : ?[Text]; // x.509 Certificate Chain
        x5u : ?Text; // x.509 Certificate Chain URL
        crit : ?[Text]; // Critical headers

        // Preserve all original fields
        raw : [(Text, Json.Json)];
    };

    public type Payload = {
        // Standard claims
        iss : ?Text; // Issuer
        sub : ?Text; // Subject
        aud : ?[Text]; // Audience (can be string or array)
        exp : ?Float; // Expiration Time (seconds since epoch)
        nbf : ?Float; // Not Before (seconds since epoch)
        iat : ?Float; // Issued at (seconds since epoch)
        jti : ?Text; // JWT ID

        // Preserve all original fields
        raw : [(Text, Json.Json)];
    };

    // Complete JWT Token
    public type Token = {
        header : Header;
        payload : Payload;
        signature : Blob;
        raw : Text;
    };

    public type ValidationOptions = {
        validateExpiration : Bool;
        validateNotBefore : Bool;
        validateSignature : Bool;
        audienceValidation : {
            #none;
            #one : Text;
            #any : [Text];
            #all : [Text];
        };
    };

    public func getHeaderValue(token : Token, key : Text) : ?Json.Json {
        let ?kv = Array.find(
            token.header.raw,
            func((k, _value) : (Text, Json.Json)) : Bool = k == key,
        ) else return null;
        ?kv.1;
    };

    public func getPayloadValue(token : Token, key : Text) : ?Json.Json {
        let ?kv = Array.find(
            token.payload.raw,
            func((k, _value) : (Text, Json.Json)) : Bool = k == key,
        ) else return null;
        ?kv.1;
    };

    public func validateExpiration(token : Token) : Bool {
        switch (token.payload.exp) {
            case (null) true; // No expiration claim, consider valid by default
            case (?expTime) Time.now() >= Float.toInt(expTime * 1_000_000_000);
        };
    };

    // Validate "not before" time
    public func validateNotBefore(token : Token) : Bool {
        switch (token.payload.nbf) {
            case (null) true; // No nbf claim, consider valid by default
            case (?nbfTime) Time.now() >= Float.toInt(nbfTime * 1_000_000_000);
        };
    };

    // Verify signature based on algorithm
    public func verifySignature(token : Token, key : Blob) : Result.Result<Bool, Text> {
        // Reconstruct the signing input (header.payload)
        let partsIter = Text.split(token.raw, #char('.'));
        let ?headerPart = partsIter.next() else return #err("Invalid JWT format - missing header part");
        let ?payloadPart = partsIter.next() else return #err("Invalid JWT format - missing payload part");
        let message = Text.encodeUtf8(headerPart # "." # payloadPart);

        // Verify based on algorithm
        type HashAlgorithm = {
            #sha256;
            // #sha384;
            // #sha512;
        };
        type Verifier = (hashAlgorithm : HashAlgorithm, message : Iter.Iter<Nat8>, key : Blob, signature : Blob) -> Result.Result<Bool, Text>;
        let (hashAlg, verifier) : (HashAlgorithm, Verifier) = switch (token.header.alg) {
            case ("HS256") (#sha256, verifyHmacSignature);
            // case ("HS384") verifyHmacSignature(#sha384, signingInput.vals(), key, token.signature);
            // case ("HS512") verifyHmacSignature(#sha512, signingInput.vals(), key, token.signature);
            case ("ES256") (#sha256, verifyEcdsaSignature);
            // case ("ES384") (#sha384, verifyEcdsaSignature);
            // case ("ES512") (#sha512, verifyEcdsaSignature);
            case ("none") return #err("Algorithm 'none' is not supported for security reasons");
            case (_) return #err("Unsupported algorithm: " # token.header.alg);
        };
        switch (verifier(hashAlg, message.vals(), key, token.signature)) {
            case (#err(e)) return #err("Failed to verify signature: " # debug_show (e));
            case (#ok(isValid)) #ok(isValid);
        };
    };

    // Comprehensive validation
    public func validate(token : Token, options : ValidationOptions, key : Blob) : Result.Result<(), Text> {
        // Check time-based claims if enabled
        if (options.validateExpiration and not validateExpiration(token)) {
            return #err("Token has expired");
        };

        if (options.validateNotBefore and not validateNotBefore(token)) {
            return #err("Token is not yet valid (nbf claim)");
        };

        // Check signature if key provided
        if (options.validateSignature) {
            switch (verifySignature(token, key)) {
                case (#err(e)) return #err(e);
                case (#ok(false)) return #err("Invalid signature");
                case (#ok(true)) {
                    // Signature valid, continue
                };
            };
        };

        // Check audience if specified
        switch (options.audienceValidation) {
            case (#none) {
                // No audience validation needed
            };
            case (#one(audience)) {
                // Check if audience matches
                switch (token.payload.aud) {
                    case (null) return #err("Token audience is missing");
                    case (?aud) {
                        // Array of audiences
                        // Check if the audience is in the array
                        if (Array.indexOf<Text>(audience, aud, Text.equal) == null) {
                            return #err("Token audience does not match expected audience");
                        };
                    };
                };
            };
            case (#any(audiences)) {
                switch (token.payload.aud) {
                    case (null) return #err("Token audience is missing");
                    case (?aud) {
                        // Check if any of the audiences match
                        let found = Array.any<Text>(
                            audiences,
                            func(a : Text) : Bool = Array.indexOf<Text>(a, aud, Text.equal) != null,
                        );
                        if (not found) {
                            return #err("Token audience does not match expected audience");
                        };
                    };
                };
            };
            case (#all(audiences)) {
                switch (token.payload.aud) {
                    case (null) return #err("Token audience is missing");
                    case (?aud) {
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

        let header = switch (parseHeader(headerJson)) {
            case (#err(e)) return #err(e);
            case (#ok(h)) h;
        };

        // TODO handle error from engine
        let payloadJson = switch (parseJsonObj(base64Engine.decode(parts[1]), "payload")) {
            case (#err(e)) return #err("Unable to decode payload: " # debug_show (e));
            case (#ok(payloadJson)) payloadJson;
        };

        let payload = switch (parsePayload(payloadJson)) {
            case (#err(e)) return #err(e);
            case (#ok(p)) p;
        };

        // Decode base64url signature to bytes
        let signatureBytes = Blob.fromArray(base64Engine.decode(parts[2])); // TODO handle error from engine

        #ok({
            header = header;
            payload = payload;
            signature = signatureBytes;
            raw = jwt;
        });
    };

    private func verifyEcdsaSignature(
        hashAlgorithm : Sha256.Algorithm,
        message : Iter.Iter<Nat8>,
        key : Blob,
        signature : Blob,
    ) : Result.Result<Bool, Text> {
        let ?publicKeyText = Text.decodeUtf8(key) else return #err("Unable to decode public key as UTF-8");
        let ?derPublicKey = DER.parsePublicKey(publicKeyText) else return #err("Failed to parse public key");
        if (derPublicKey.algorithm.oid != "1.2.840.10045.2.1") {
            return #err("Invalid public key algorithm OID: " # derPublicKey.algorithm.oid);
        };
        if (derPublicKey.algorithm.parameters != ?"1.2.840.10045.3.1.7") {
            return #err("Invalid public key algorithm parameters OID: " # Option.get(derPublicKey.algorithm.parameters, ""));
        };

        let curve = Curve.Curve(#prime256v1);
        let ?publicKey = ECDSA.deserializePublicKeyUncompressed(curve, Blob.fromArray(derPublicKey.key)) else {
            Debug.print("Failed to deserialize public key: " # debug_show (derPublicKey.key));
            Runtime.trap("Failed to deserialize public key");
        };
        let ?signatureRaw = ECDSA.deserializeSignatureRaw(signature) else return #ok(false);
        let normalizedSig = ECDSA.normalizeSignature(curve, signatureRaw);
        let messageHash = Sha256.fromIter(hashAlgorithm, message).vals();
        #ok(ECDSA.verify(curve, publicKey, messageHash, normalizedSig));
    };

    private func verifyHmacSignature(
        hashAlgorithm : HMAC.HashAlgorithm,
        message : Iter.Iter<Nat8>,
        key : Blob,
        signature : Blob,
    ) : Result.Result<Bool, Text> {
        // HMAC verification logic
        let hmac = HMAC.generate(
            Blob.toArray(key),
            message,
            hashAlgorithm,
        );
        #ok(Blob.equal(hmac, signature));
    };

    private func parseHeader(headerFields : [(Text, Json.Json)]) : Result.Result<Header, Text> {
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
                    raw = headerFields;
                });
            };
        };
    };

    private func parsePayload(payloadFields : [(Text, Json.Json)]) : Result.Result<Payload, Text> {
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
            raw = payloadFields;
        });
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
