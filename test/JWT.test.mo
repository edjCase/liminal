import { test } "mo:test";
import Runtime "mo:new-base/Runtime";
import Blob "mo:new-base/Blob";
import JWT "../src/JWT";
import ECDSA "mo:ecdsa";
import Debug "mo:base/Debug";
import Base64 "mo:base64";

type TestCase = {
    token : Text;
    key : JWT.SignatureVerificationKey;
    audiences : [Text];
    issuer : ?Text;
    expected : JWT.Token;
};

test(
    "JWT",
    func() {
        let message = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImN0eSI6ImFwcGxpY2F0aW9uL2pzb24iLCJraWQiOiJ0ZXN0LWtleS1pZC0xMjMiLCJ4NWMiOlsiTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF1MVNVMUxmVkxQSENvek14SDJNbzRsZ09FZVB6Tm0wdFJnZUxlelY2ZmZBdDBndW5WVEx3N29uTFJucnEwL0l6Vzd5V1I3UWtybUJMN2pUS0VuNXUrcUtoYndLZkJzdElzK2JNWTJaa3AxOGduVHhLTHhvUzJ0RmN6R2tQTFBnaXpza3VlbU1naFJuaVdhb0xjeWVoa2QzcXFHRWx2Vy9WREw1QWFXVGcwbkxWa2pSbzl6KzQwUlF6dVZhRThBa0FGbXhaem93M3grVkpZS2RqeWtrSjBpVDl3Q1MwRFJUWHUyNjlWMjY0VmYvM2p2cmVkWmlLUmtnd2xMOXhOQXd4WEZnMHgvWEZ3MDA1VVdWUklrZGdjS1dUanBCUDJkUHdWWjRXV0MrOWFHVmQrR3luMW8wQ0xlbGY0ckVqR29YYkFBRWdBcWVHVXhyY0lsYmpYZmJjbXdJREFRQUIiXSwieDV1IjoiaHR0cHM6Ly9leGFtcGxlLmNvbS90ZXN0LWNlcnQiLCJjcml0IjpbImV4cCIsIm5iZiJdfQ.eyJzdWIiOiIxIiwibmFtZSI6Ik1lIiwiaWF0IjoxLCJpc3MiOiJodHRwczovL2V4YW1wbGUuY29tIiwiYXVkIjpbImh0dHBzOi8vZXhhbXBsZS5vcmciXSwiZXhwIjoyLCJuYmYiOjEuMSwianRpIjoiSlRJLTEyMyIsImN1c3RvbSI6InZhbHVlIn0";
        let messageBytes : Blob = Blob.fromArray(Base64.Base64(#v(Base64.V2), ?true).decode(message));
        Debug.print("Message: " # debug_show messageBytes);

        let signatureBytes : Blob = "\30\45\02\21\00\f3\c1\f9\d8\2f\cc\e3\b2\eb\1b\40\11\6c\24\93\57\1e\10\ff\d7\a5\6f\c2\2c\d2\bd\16\d2\0b\d7\56\75\02\20\21\ec\ea\b0\ae\80\84\bf\6d\60\39\14\71\26\f5\d0\fc\3b\4b\f3\2c\e6\f7\28\b1\0c\ff\62\80\20\6a\30";
        let signatureBase64 = Base64.Base64(#v(Base64.V2), ?true).encode(#bytes(Blob.toArray(signatureBytes)));
        Debug.print("Signature: " # signatureBase64);

        let publicKeyBytes : Blob = "\30\56\30\10\06\07\2a\86\48\ce\3d\02\01\06\05\2b\81\04\00\0a\03\42\00\04\2f\ba\80\9b\5a\b0\6f\71\9f\ac\50\81\8a\9d\df\60\26\a4\a9\5b\87\db\c3\70\15\ed\13\c0\05\7d\07\4c\9c\80\26\e6\34\55\09\98\33\10\f6\d7\98\86\f4\d2\73\c1\de\dc\a4\87\80\3e\b0\76\ff\67\a4\89\14\a2";
        let ?key = ECDSA.publicKeyFromBytes(publicKeyBytes.vals(), #der) else Runtime.trap("Error creating public key");
        Debug.print("X: " # debug_show key.x);
        Debug.print("Y: " # debug_show key.y);

        let cases : [TestCase] = [
            {
                token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KMUFsIDTnFmyG3nMiGM6H9FNFUROf3wh7SmqJp-QV30";
                key = #symmetric("\61\2d\73\74\72\69\6e\67\2d\73\65\63\72\65\74\2d\61\74\2d\6c\65\61\73\74\2d\32\35\36\2d\62\69\74\73\2d\6c\6f\6e\67");
                audiences = [];
                issuer = null;
                expected = {
                    header = [
                        ("alg", #string("HS256")),
                        ("typ", #string("JWT")),
                    ];
                    payload = [
                        ("sub", #string("1234567890")),
                        ("name", #string("John Doe")),
                        ("admin", #bool(true)),
                        ("iat", #number(#int(1516239022))),
                    ];
                    signature = {
                        algorithm = "HS256";
                        value = "\28\C5\05\B0\80\D3\9C\59\B2\1B\79\CC\88\63\3A\1F\D1\4D\15\44\4E\7F\7C\21\ED\29\AA\26\9F\90\57\7D";
                        message = "\7B\22\61\6C\67\22\3A\22\48\53\32\35\36\22\2C\22\74\79\70\22\3A\22\4A\57\54\22\7D\01\EC\89\CD\D5\88\88\E8\88\C4\C8\CC\D0\D4\D8\DC\E0\E4\C0\88\B0\89\B9\85\B5\94\88\E8\89\29\BD\A1\B8\81\11\BD\94\88\B0\89\85\91\B5\A5\B8\88\E9\D1\C9\D5\94\B0\89\A5\85\D0\88\E8\C4\D4\C4\D8\C8\CC\E4\C0\C8\C9\F4";
                    };
                };
            },
            {
                token = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImN0eSI6ImFwcGxpY2F0aW9uL2pzb24iLCJraWQiOiJ0ZXN0LWtleS1pZC0xMjMiLCJ4NWMiOlsiTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF1MVNVMUxmVkxQSENvek14SDJNbzRsZ09FZVB6Tm0wdFJnZUxlelY2ZmZBdDBndW5WVEx3N29uTFJucnEwL0l6Vzd5V1I3UWtybUJMN2pUS0VuNXUrcUtoYndLZkJzdElzK2JNWTJaa3AxOGduVHhLTHhvUzJ0RmN6R2tQTFBnaXpza3VlbU1naFJuaVdhb0xjeWVoa2QzcXFHRWx2Vy9WREw1QWFXVGcwbkxWa2pSbzl6KzQwUlF6dVZhRThBa0FGbXhaem93M3grVkpZS2RqeWtrSjBpVDl3Q1MwRFJUWHUyNjlWMjY0VmYvM2p2cmVkWmlLUmtnd2xMOXhOQXd4WEZnMHgvWEZ3MDA1VVdWUklrZGdjS1dUanBCUDJkUHdWWjRXV0MrOWFHVmQrR3luMW8wQ0xlbGY0ckVqR29YYkFBRWdBcWVHVXhyY0lsYmpYZmJjbXdJREFRQUIiXSwieDV1IjoiaHR0cHM6Ly9leGFtcGxlLmNvbS90ZXN0LWNlcnQiLCJjcml0IjpbImV4cCIsIm5iZiJdfQ.eyJzdWIiOiIxIiwibmFtZSI6Ik1lIiwiaWF0IjoxLCJpc3MiOiJodHRwczovL2V4YW1wbGUuY29tIiwiYXVkIjpbImh0dHBzOi8vZXhhbXBsZS5vcmciXSwiZXhwIjoyLCJuYmYiOjEuMSwianRpIjoiSlRJLTEyMyIsImN1c3RvbSI6InZhbHVlIn0.MEUCIQDzwfnYL8zjsusbQBFsJJNXHhD_16VvwizSvRbSC9dWdQIgIezqsK6AhL9tYDkUcSb10Pw7S_Ms5vcosQz_YoAgajA";
                key = #ecdsa(
                    ECDSA.PublicKey(
                        21_588_225_049_337_109_873_405_550_505_403_375_696_077_506_562_146_237_645_919_793_593_104_591_554_380,
                        70_787_229_275_941_322_822_918_359_021_784_182_473_371_425_197_247_842_842_574_720_404_293_992_125_602,
                        ECDSA.prime256v1Curve(),
                    )
                );
                audiences = [];
                issuer = null;
                expected = {
                    header = [
                        ("alg", #string("ES256")),
                        ("typ", #string("JWT")),
                        ("cty", #string("application/json")),
                        ("kid", #string("test-key-id-123")),
                        ("x5c", #array([#string("MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu1SU1LfVLPHCozMxH2Mo4lgOEePzNm0tRgeLezV6ffAt0gunVTLw7onLRnrq0/IzW7yWR7QkrmBL7jTKEn5u+qKhbwKfBstIs+bMY2Zkp18gnTxKLxoS2tFczGkPLPgizskuemMghRniWaoLcyehkd3qqGElvW/VDL5AaWTg0nLVkjRo9z+40RQzuVaE8AkAFmxZzow3x+VJYKdjykkJ0iT9wCS0DRTXu269V264Vf/3jvredZiKRkgwlL9xNAwxXFg0x/XFw005UWVRIkdgcKWTjpBP2dPwVZ4WWC+9aGVd+Gyn1o0CLelf4rEjGoXbAAEgAqeGUxrcIlbjXfbcmwIDAQAB")])),
                        ("x5u", #string("https://example.com/test-cert")),
                        ("crit", #array([#string("exp"), #string("nbf")])),
                    ];
                    payload = [
                        ("sub", #string("1")),
                        ("name", #string("Me")),
                        ("iat", #number(#int(1))),
                        ("iss", #string("https://example.com")),
                        ("aud", #array([#string("https://example.org")])),
                        ("exp", #number(#int(2))),
                        ("nbf", #number(#float(1.1))),
                        ("jti", #string("JTI-123")),
                        ("custom", #string("value")),
                    ];
                    signature = {
                        algorithm = "ES256";
                        value = "\30\45\02\21\00\f3\c1\f9\d8\2f\cc\e3\b2\eb\1b\40\11\6c\24\93\57\1e\10\ff\d7\a5\6f\c2\2c\d2\bd\16\d2\0b\d7\56\75\02\20\21\ec\ea\b0\ae\80\84\bf\6d\60\39\14\71\26\f5\d0\fc\3b\4b\f3\2c\e6\f7\28\b1\0c\ff\62\80\20\6a\30";
                        message = "\7B\22\61\6C\67\22\3A\22\45\53\32\35\36\22\2C\22\74\79\70\22\3A\22\4A\57\54\22\2C\22\63\74\79\22\3A\22\61\70\70\6C\69\63\61\74\69\6F\6E\2F\6A\73\6F\6E\22\2C\22\6B\69\64\22\3A\22\74\65\73\74\2D\6B\65\79\2D\69\64\2D\31\32\33\22\2C\22\78\35\63\22\3A\5B\22\4D\49\49\42\49\6A\41\4E\42\67\6B\71\68\6B\69\47\39\77\30\42\41\51\45\46\41\41\4F\43\41\51\38\41\4D\49\49\42\43\67\4B\43\41\51\45\41\75\31\53\55\31\4C\66\56\4C\50\48\43\6F\7A\4D\78\48\32\4D\6F\34\6C\67\4F\45\65\50\7A\4E\6D\30\74\52\67\65\4C\65\7A\56\36\66\66\41\74\30\67\75\6E\56\54\4C\77\37\6F\6E\4C\52\6E\72\71\30\2F\49\7A\57\37\79\57\52\37\51\6B\72\6D\42\4C\37\6A\54\4B\45\6E\35\75\2B\71\4B\68\62\77\4B\66\42\73\74\49\73\2B\62\4D\59\32\5A\6B\70\31\38\67\6E\54\78\4B\4C\78\6F\53\32\74\46\63\7A\47\6B\50\4C\50\67\69\7A\73\6B\75\65\6D\4D\67\68\52\6E\69\57\61\6F\4C\63\79\65\68\6B\64\33\71\71\47\45\6C\76\57\2F\56\44\4C\35\41\61\57\54\67\30\6E\4C\56\6B\6A\52\6F\39\7A\2B\34\30\52\51\7A\75\56\61\45\38\41\6B\41\46\6D\78\5A\7A\6F\77\33\78\2B\56\4A\59\4B\64\6A\79\6B\6B\4A\30\69\54\39\77\43\53\30\44\52\54\58\75\32\36\39\56\32\36\34\56\66\2F\33\6A\76\72\65\64\5A\69\4B\52\6B\67\77\6C\4C\39\78\4E\41\77\78\58\46\67\30\78\2F\58\46\77\30\30\35\55\57\56\52\49\6B\64\67\63\4B\57\54\6A\70\42\50\32\64\50\77\56\5A\34\57\57\43\2B\39\61\47\56\64\2B\47\79\6E\31\6F\30\43\4C\65\6C\66\34\72\45\6A\47\6F\58\62\41\41\45\67\41\71\65\47\55\78\72\63\49\6C\62\6A\58\66\62\63\6D\77\49\44\41\51\41\42\22\5D\2C\22\78\35\75\22\3A\22\68\74\74\70\73\3A\2F\2F\65\78\61\6D\70\6C\65\2E\63\6F\6D\2F\74\65\73\74\2D\63\65\72\74\22\2C\22\63\72\69\74\22\3A\5B\22\65\78\70\22\2C\22\6E\62\66\22\5D\7D\00\1E\C8\9C\DD\58\88\8E\88\8C\48\8B\08\9B\98\5B\59\48\8E\88\93\59\48\8B\08\9A\58\5D\08\8E\8C\4B\08\9A\5C\DC\C8\8E\88\9A\1D\1D\1C\1C\CE\8B\CB\D9\5E\18\5B\5C\1B\19\4B\98\DB\DB\48\8B\08\98\5D\59\08\8E\96\C8\9A\1D\1D\1C\1C\CE\8B\CB\D9\5E\18\5B\5C\1B\19\4B\9B\DC\99\C8\97\4B\08\99\5E\1C\08\8E\8C\8B\08\9B\98\99\88\8E\8C\4B\8C\4B\08\9A\9D\1A\48\8E\88\92\95\12\4B\4C\4C\8C\C8\8B\08\98\DD\5C\DD\1B\DB\48\8E\88\9D\98\5B\1D\59\48\9F";
                    };
                };
            },
        ];
        for (testCase in cases.vals()) {
            let token = testCase.token;
            let expected = testCase.expected;

            switch (JWT.parse(token)) {
                case (#err(err)) Runtime.trap("Error parsing token: " # err);
                case (#ok(actualToken)) {
                    if (actualToken != expected) {
                        Runtime.trap("\nExpected: " # debug_show (expected) # "\nActual:   " # debug_show (actualToken));
                    };
                    switch (
                        JWT.validate(
                            actualToken,
                            {
                                audience = if (testCase.audiences.size() > 0) #all(testCase.audiences) else #skip;
                                issuer = switch (testCase.issuer) {
                                    case (null) #skip;
                                    case (?issuer) #one(issuer);
                                };
                                expiration = true;
                                notBefore = true;
                                signature = #key(testCase.key);
                            },
                        )
                    ) {
                        case (#err(err)) Runtime.trap("Error validating token: " # err);
                        case (#ok(_)) {
                            // Token is valid
                        };
                    };
                };
            };
        };
    },
);
