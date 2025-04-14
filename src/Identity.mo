import JWT "mo:jwt";

module {

    public type IdentityKind = {
        #jwt : JWT.Token;
    };

    public type Identity = {
        kind : IdentityKind;
        getId : () -> ?Text;
        isAuthenticated : () -> Bool;
    };

    public type IdentityRequirement = {
        #authenticated;
        #custom : (identity : Identity) -> Bool; // Custom validator
    };
};
