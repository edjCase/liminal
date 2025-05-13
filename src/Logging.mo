import Debug "mo:new-base/Debug";

module {
    public type Logger = {
        log : (level : LogLevel, message : Text) -> ();
    };

    public type LogLevel = {
        #verbose;
        #debug_;
        #info;
        #warn;
        #error;
        #fatal;
    };

    public func levelToText(level : LogLevel) : Text {
        switch (level) {
            case (#verbose) "VERBOSE";
            case (#debug_) "DEBUG";
            case (#info) "INFO";
            case (#warn) "WARN";
            case (#error) "ERROR";
            case (#fatal) "FATAL";
        };
    };

    public let debugLogger : Logger = {
        log = func(level : LogLevel, message : Text) {
            Debug.print("[" # levelToText(level) # "] " # message);
        };
    };

};
