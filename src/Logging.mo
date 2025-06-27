import Debug "mo:new-base/Debug";
import Nat "mo:new-base/Nat";

module {
    public type Logger = {
        log : (level : LogLevel, message : Text) -> ();
    };

    public func withLogScope(logger : Logger, scope : Text) : Logger {
        {
            log = func(level : LogLevel, message : Text) {
                let fullMessage = "(" # scope # ") " # message;
                logger.log(level, fullMessage);
            };
        };
    };

    public type LogLevel = {
        #verbose;
        #debug_;
        #info;
        #warning;
        #error;
        #fatal;
    };

    public func levelToText(level : LogLevel) : Text {
        switch (level) {
            case (#verbose) "VERBOSE";
            case (#debug_) "DEBUG";
            case (#info) "INFO";
            case (#warning) "WARNING";
            case (#error) "ERROR";
            case (#fatal) "FATAL";
        };
    };

    private func getLevelNat(level : LogLevel) : Nat {
        switch (level) {
            case (#verbose) 0;
            case (#debug_) 1;
            case (#info) 2;
            case (#warning) 3;
            case (#error) 4;
            case (#fatal) 5;
        };
    };

    public func buildDebugLogger(minLogLevel : LogLevel) : Logger = {
        log = func(level : LogLevel, message : Text) {

            if (getLevelNat(level) < getLevelNat(minLogLevel)) {
                return; // Skip logging if level is below minimum
            };
            let logLevelText = levelToText(level);
            let maxLogLevelLength = 7; // Length of longest log level text ("WARNING")
            let paddingSize : Nat = maxLogLevelLength - logLevelText.size();
            var padding = "";
            for (i in Nat.range(0, paddingSize)) {
                padding := padding # " ";
            };
            Debug.print("[" # levelToText(level) # "] " # padding # message);
        };

    };
};
