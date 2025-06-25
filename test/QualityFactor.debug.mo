import { test } "mo:test";
import QualityFactor "../src/QualityFactor";

test(
    "QualityFactor.fromText - basic functionality test",
    func() : () {
        // Test a simple case that should work
        switch (QualityFactor.fromText("0.5")) {
            case (?result) {
                // Just print what we get to understand the behavior
                assert result >= 0; // Basic check
            };
            case (null) assert false; // Should not be null
        };
    },
);
