import { test; suite } "mo:test";
import Logging "../src/Logging";
import Runtime "mo:new-base/Runtime";

suite(
    "Logging module tests",
    func() : () {

        test(
            "levelToText - converts all log levels to correct text",
            func() : () {
                let testCases = [
                    (#verbose, "VERBOSE"),
                    (#debug_, "DEBUG"),
                    (#info, "INFO"),
                    (#warning, "WARNING"),
                    (#error, "ERROR"),
                    (#fatal, "FATAL"),
                ];

                for ((level, expected) in testCases.vals()) {
                    let actual = Logging.levelToText(level);
                    if (actual != expected) {
                        Runtime.trap("levelToText failed for " # debug_show (level) # ": expected '" # expected # "', got '" # actual # "'");
                    };
                };
            },
        );

        test(
            "debugLogger - exists and has log function",
            func() : () {
                // Test that debugLogger exists and can be called
                // Note: We can't easily test Debug.print output in unit tests
                // but we can verify the logger interface works
                let testCases = [
                    (#info, "Test message"),
                    (#error, "Test error message"),
                    (#debug_, "Test debug message"),
                    (#verbose, "Test verbose message"),
                    (#warning, "Test warning message"),
                    (#fatal, "Test fatal message"),
                ];

                for ((level, message) in testCases.vals()) {
                    // Test passes if no runtime errors occur during logging
                    Logging.buildDebugLogger(#warning).log(level, message);
                };
            },
        );

        test(
            "Logger type - interface consistency",
            func() : () {
                // Test that we can create a custom logger matching the interface
                let customLogger : Logging.Logger = {
                    log = func(level : Logging.LogLevel, message : Text) {
                        // Custom implementation - just verify types match
                        let _ = Logging.levelToText(level);
                        let _ = message;
                    };
                };

                let testCases = [
                    (#verbose, "verbose message"),
                    (#debug_, "debug message"),
                    (#info, "info message"),
                    (#warning, "warning message"),
                    (#error, "error message"),
                    (#fatal, "fatal message"),
                ];

                for ((level, message) in testCases.vals()) {
                    // Test passes if no runtime errors occur during logging
                    customLogger.log(level, message);
                };
            },
        );
    },
);
