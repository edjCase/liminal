import { test } "mo:test";
import Runtime "mo:new-base/Runtime";
import Text "mo:new-base/Text";
import JWT "../src/JWT";
import ECDSA "mo:ecdsa";

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
                        message = "\65\79\4A\68\62\47\63\69\4F\69\4A\49\55\7A\49\31\4E\69\49\73\49\6E\52\35\63\43\49\36\49\6B\70\58\56\43\4A\39\2E\65\79\4A\7A\64\57\49\69\4F\69\49\78\4D\6A\4D\30\4E\54\59\33\4F\44\6B\77\49\69\77\69\62\6D\46\74\5A\53\49\36\49\6B\70\76\61\47\34\67\52\47\39\6C\49\69\77\69\59\57\52\74\61\57\34\69\4F\6E\52\79\64\57\55\73\49\6D\6C\68\64\43\49\36\4D\54\55\78\4E\6A\49\7A\4F\54\41\79\4D\6E\30";
                    };
                };
            },
            {
                token = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InRlc3Qta2V5LWlkLTEyMyIsImN0eSI6ImFwcGxpY2F0aW9uL2pzb24iLCJ4NWMiOlsiTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF1MVNVMUxmVkxQSENvek14SDJNbzRsZ09FZVB6Tm0wdFJnZUxlelY2ZmZBdDBndW5WVEx3N29uTFJucnEwL0l6Vzd5V1I3UWtybUJMN2pUS0VuNXUrcUtoYndLZkJzdElzK2JNWTJaa3AxOGduVHhLTHhvUzJ0RmN6R2tQTFBnaXpza3VlbU1naFJuaVdhb0xjeWVoa2QzcXFHRWx2Vy9WREw1QWFXVGcwbkxWa2pSbzl6KzQwUlF6dVZhRThBa0FGbXhaem93M3grVkpZS2RqeWtrSjBpVDl3Q1MwRFJUWHUyNjlWMjY0VmYvM2p2cmVkWmlLUmtnd2xMOXhOQXd4WEZnMHgvWEZ3MDA1VVdWUklrZGdjS1dUanBCUDJkUHdWWjRXV0MrOWFHVmQrR3luMW8wQ0xlbGY0ckVqR29YYkFBRWdBcWVHVXhyY0lsYmpYZmJjbXdJREFRQUIiXSwieDV1IjoiaHR0cHM6Ly9leGFtcGxlLmNvbS90ZXN0LWNlcnQiLCJjcml0IjpbImV4cCIsIm5iZiJdfQ.eyJzdWIiOiIxIiwibmFtZSI6Ik1lIiwiaWF0IjoxLCJpc3MiOiJodHRwczovL2V4YW1wbGUuY29tIiwiYXVkIjpbImh0dHBzOi8vZXhhbXBsZS5vcmciXSwiZXhwIjoyLCJuYmYiOjEuMSwianRpIjoiSlRJLTEyMyIsImN1c3RvbSI6InZhbHVlIn0.QeNBs5B4H9tr8EWCEVW65LRNdTePuxnUoNUZg96wP5o82M6rMei4DsdKuh2oyFpFWgA8U2XRXK1oW0s68sn4Yw";
                key = #ecdsa(
                    ECDSA.PublicKey(
                        88_901_251_030_692_689_791_368_522_421_773_354_572_762_654_817_252_927_261_413_865_469_233_718_935_271,
                        114_604_114_598_436_419_959_579_003_594_530_107_050_358_152_857_655_780_678_831_853_515_601_435_636_939,
                        ECDSA.prime256v1Curve(),
                    )
                );
                audiences = [];
                issuer = null;
                expected = {
                    header = [
                        ("alg", #string("ES256")),
                        ("typ", #string("JWT")),
                        ("kid", #string("test-key-id-123")),
                        ("cty", #string("application/json")),
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
                        value = "\41\E3\41\B3\90\78\1F\DB\6B\F0\45\82\11\55\BA\E4\B4\4D\75\37\8F\BB\19\D4\A0\D5\19\83\DE\B0\3F\9A\3C\D8\CE\AB\31\E8\B8\0E\C7\4A\BA\1D\A8\C8\5A\45\5A\00\3C\53\65\D1\5C\AD\68\5B\4B\3A\F2\C9\F8\63";
                        message = "\65\79\4A\68\62\47\63\69\4F\69\4A\46\55\7A\49\31\4E\69\49\73\49\6E\52\35\63\43\49\36\49\6B\70\58\56\43\49\73\49\6D\74\70\5A\43\49\36\49\6E\52\6C\63\33\51\74\61\32\56\35\4C\57\6C\6B\4C\54\45\79\4D\79\49\73\49\6D\4E\30\65\53\49\36\49\6D\46\77\63\47\78\70\59\32\46\30\61\57\39\75\4C\32\70\7A\62\32\34\69\4C\43\4A\34\4E\57\4D\69\4F\6C\73\69\54\55\6C\4A\51\6B\6C\71\51\55\35\43\5A\32\74\78\61\47\74\70\52\7A\6C\33\4D\45\4A\42\55\55\56\47\51\55\46\50\51\30\46\52\4F\45\46\4E\53\55\6C\43\51\32\64\4C\51\30\46\52\52\55\46\31\4D\56\4E\56\4D\55\78\6D\56\6B\78\51\53\45\4E\76\65\6B\31\34\53\44\4A\4E\62\7A\52\73\5A\30\39\46\5A\56\42\36\54\6D\30\77\64\46\4A\6E\5A\55\78\6C\65\6C\59\32\5A\6D\5A\42\64\44\42\6E\64\57\35\57\56\45\78\33\4E\32\39\75\54\46\4A\75\63\6E\45\77\4C\30\6C\36\56\7A\64\35\56\31\49\33\55\57\74\79\62\55\4A\4D\4E\32\70\55\53\30\56\75\4E\58\55\72\63\55\74\6F\59\6E\64\4C\5A\6B\4A\7A\64\45\6C\7A\4B\32\4A\4E\57\54\4A\61\61\33\41\78\4F\47\64\75\56\48\68\4C\54\48\68\76\55\7A\4A\30\52\6D\4E\36\52\32\74\51\54\46\42\6E\61\58\70\7A\61\33\56\6C\62\55\31\6E\61\46\4A\75\61\56\64\68\62\30\78\6A\65\57\56\6F\61\32\51\7A\63\58\46\48\52\57\78\32\56\79\39\57\52\45\77\31\51\57\46\58\56\47\63\77\62\6B\78\57\61\32\70\53\62\7A\6C\36\4B\7A\51\77\55\6C\46\36\64\56\5A\68\52\54\68\42\61\30\46\47\62\58\68\61\65\6D\39\33\4D\33\67\72\56\6B\70\5A\53\32\52\71\65\57\74\72\53\6A\42\70\56\44\6C\33\51\31\4D\77\52\46\4A\55\57\48\55\79\4E\6A\6C\57\4D\6A\59\30\56\6D\59\76\4D\32\70\32\63\6D\56\6B\57\6D\6C\4C\55\6D\74\6E\64\32\78\4D\4F\58\68\4F\51\58\64\34\57\45\5A\6E\4D\48\67\76\57\45\5A\33\4D\44\41\31\56\56\64\57\55\6B\6C\72\5A\47\64\6A\53\31\64\55\61\6E\42\43\55\44\4A\6B\55\48\64\57\57\6A\52\58\56\30\4D\72\4F\57\46\48\56\6D\51\72\52\33\6C\75\4D\57\38\77\51\30\78\6C\62\47\59\30\63\6B\56\71\52\32\39\59\59\6B\46\42\52\57\64\42\63\57\56\48\56\58\68\79\59\30\6C\73\59\6D\70\59\5A\6D\4A\6A\62\58\64\4A\52\45\46\52\51\55\49\69\58\53\77\69\65\44\56\31\49\6A\6F\69\61\48\52\30\63\48\4D\36\4C\79\39\6C\65\47\46\74\63\47\78\6C\4C\6D\4E\76\62\53\39\30\5A\58\4E\30\4C\57\4E\6C\63\6E\51\69\4C\43\4A\6A\63\6D\6C\30\49\6A\70\62\49\6D\56\34\63\43\49\73\49\6D\35\69\5A\69\4A\64\66\51\2E\65\79\4A\7A\64\57\49\69\4F\69\49\78\49\69\77\69\62\6D\46\74\5A\53\49\36\49\6B\31\6C\49\69\77\69\61\57\46\30\49\6A\6F\78\4C\43\4A\70\63\33\4D\69\4F\69\4A\6F\64\48\52\77\63\7A\6F\76\4C\32\56\34\59\57\31\77\62\47\55\75\59\32\39\74\49\69\77\69\59\58\56\6B\49\6A\70\62\49\6D\68\30\64\48\42\7A\4F\69\38\76\5A\58\68\68\62\58\42\73\5A\53\35\76\63\6D\63\69\58\53\77\69\5A\58\68\77\49\6A\6F\79\4C\43\4A\75\59\6D\59\69\4F\6A\45\75\4D\53\77\69\61\6E\52\70\49\6A\6F\69\53\6C\52\4A\4C\54\45\79\4D\79\49\73\49\6D\4E\31\63\33\52\76\62\53\49\36\49\6E\5A\68\62\48\56\6C\49\6E\30";
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
                                expiration = false;
                                notBefore = false;
                                signature = #key(testCase.key);
                            },
                        )
                    ) {
                        case (#err(err)) Runtime.trap("Error validating token\nToken\n" # token # "\nError\n" # err);
                        case (#ok(_)) {
                            // Token is valid
                        };
                    };
                };
            };
        };
    },
);
