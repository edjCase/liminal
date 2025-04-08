import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Base64 "mo:base64";
import ASN1 "mo:asn1";

module {

    public type AlgorithmIdentifier = {
        oid : [Nat]; // Main algorithm OID (e.g. "1.3.132.0.10")
        parameters : ASN1.ASN1Value; // Optional parameters
    };

    public type DerPublicKey = {
        key : [Nat8]; // The actual public key bytes
        algorithm : AlgorithmIdentifier;
    };

    public func parsePublicKey(key : Text) : ?DerPublicKey {

        // First normalize line endings
        let normalizedKey = Text.replace(key, #text("\r\n"), "\n");

        // Split and clean more carefully
        let lines = Iter.toArray(
            Iter.filter(
                Text.split(normalizedKey, #text("\n")),
                func(line : Text) : Bool {
                    let trimmed = Text.trim(line, #char(' '));
                    trimmed.size() > 0 and not Text.startsWith(trimmed, #text("-----"));
                },
            )
        );

        let derText = Text.join("", lines.vals());

        // Add debug output to check base64 content
        if (derText.size() == 0) return null;

        let base64Engine = Base64.Base64(#v(Base64.V2), ?true);
        let bytesArray = base64Engine.decode(derText);
        switch (ASN1.decodeDER(bytesArray.vals())) {
            case (#err(_)) return null;
            case (#ok(asn1Value)) switch (asn1Value) {
                case (#sequence(s)) {
                    if (s.size() != 2) return null;
                    let #sequence(innerSequence) = s[0] else return null;
                    if (innerSequence.size() != 2) return null;
                    let #oid(oid) = innerSequence[0] else return null;
                    let parameters = innerSequence[1];
                    let #bitString({ data = keyBytes; unusedBits = 0 }) = s[1] else return null;
                    ?{
                        key = keyBytes;
                        algorithm = {
                            oid = oid;
                            parameters = parameters;
                        };
                    };
                };
                case (_) return null;
            };
        }

    };
};
