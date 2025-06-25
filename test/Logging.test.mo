import { test; suite } "mo:test";
import Logging "../src/Logging";

suite(
    "Logging module tests",
    func() : () {

        test(
            "levelToText - converts all log levels to correct text",
            func() : () {
                assert Logging.levelToText(#verbose) == "VERBOSE";
                assert Logging.levelToText(#debug_) == "DEBUG";
                assert Logging.levelToText(#info) == "INFO";
                assert Logging.levelToText(#warn) == "WARN";
                assert Logging.levelToText(#error) == "ERROR";
                assert Logging.levelToText(#fatal) == "FATAL";
            },
        );

        test(
            "debugLogger - exists and has log function",
            func() : () {
                // Test that debugLogger exists and can be called
                // Note: We can't easily test Debug.print output in unit tests
                // but we can verify the logger interface works
                Logging.debugLogger.log(#info, "Test message");
                Logging.debugLogger.log(#error, "Test error message");
                Logging.debugLogger.log(#debug_, "Test debug message");

                // Test passes if no runtime errors occur
                assert true;
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

                // Test all log levels work with custom logger
                customLogger.log(#verbose, "verbose message");
                customLogger.log(#debug_, "debug message");
                customLogger.log(#info, "info message");
                customLogger.log(#warn, "warn message");
                customLogger.log(#error, "error message");
                customLogger.log(#fatal, "fatal message");

                assert true;
            },
        );
    },
);
