import { test } "mo:test";
import Runtime "mo:new-base/Runtime";
import JWT "../src/JWT";

type TestCase = {
    token : Text;
    key : Blob;
    audiences : [Text];
    expected : JWT.Token;
};

test(
    "JWT",
    func() {
        let cases : [TestCase] = [{
            token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KMUFsIDTnFmyG3nMiGM6H9FNFUROf3wh7SmqJp-QV30";
            key = "\61\2d\73\74\72\69\6e\67\2d\73\65\63\72\65\74\2d\61\74\2d\6c\65\61\73\74\2d\32\35\36\2d\62\69\74\73\2d\6c\6f\6e\67";
            audiences = [];
            expected = {
                header = {
                    alg = "HS256";
                    typ = ?"JWT";
                    cty = null;
                    kid = null;
                    x5c = null;
                    x5u = null;
                    crit = null;
                    raw = [
                        ("alg", #string("HS256")),
                        ("typ", #string("JWT")),
                    ];
                };
                payload = {
                    sub = ?"1234567890";
                    name = ?"John Doe";
                    iat = ?1516239022;
                    iss = null;
                    aud = null;
                    exp = null;
                    nbf = null;
                    jti = null;
                    raw = [
                        ("sub", #string("1234567890")),
                        ("name", #string("John Doe")),
                        ("admin", #bool(true)),
                        ("iat", #number(#int(1516239022))),
                    ];
                };
                signature = "\28\C5\05\B0\80\D3\9C\59\B2\1B\79\CC\88\63\3A\1F\D1\4D\15\44\4E\7F\7C\21\ED\29\AA\26\9F\90\57\7D";
                raw = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.KMUFsIDTnFmyG3nMiGM6H9FNFUROf3wh7SmqJp-QV30";
            };
        }];
        for (testCase in cases.vals()) {
            let token = testCase.token;
            let expected = testCase.expected;

            switch (JWT.parse(token)) {
                case (#err(err)) Runtime.trap("Error parsing token: " # err);
                case (#ok(result)) {
                    if (result != expected) {
                        Runtime.trap("\nExpected: " # debug_show (expected) # "\nActual:   " # debug_show (result));
                    };
                    switch (
                        JWT.validate(
                            result,
                            {
                                validateSignature = true;
                                audienceValidation = if (testCase.audiences.size() > 0) #all(testCase.audiences) else #none;
                                validateExpiration = true;
                                validateNotBefore = true;
                            },
                            testCase.key,
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
