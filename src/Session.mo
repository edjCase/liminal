module {

    public type Session = {
        id : Text;
        get : (key : Text) -> ?Text;
        set : (key : Text, value : Text) -> ();
        remove : (key : Text) -> ();
        clear : () -> ();
    };
};
