import Text "mo:new-base/Text";
import Int "mo:new-base/Int";
import NatX "mo:xtended-numbers/NatX";
module {
    public type QualityFactor = Nat;

    /// Parses a quality factor (q-value) from text as used in HTTP Accept headers.
    /// Quality factors range from 0.0 to 1.0 and are represented as integers from 0 to 1000.
    /// This allows for precise decimal representation without floating point arithmetic.
    ///
    /// ```motoko
    /// let q1 = QualityFactor.fromText("1.0");
    /// // q1 is ?1000
    ///
    /// let q2 = QualityFactor.fromText("0.8");
    /// // q2 is ?800
    ///
    /// let q3 = QualityFactor.fromText("0.123");
    /// // q3 is ?123
    ///
    /// let invalid = QualityFactor.fromText("1.5");
    /// // invalid is null (values > 1.0 are invalid)
    /// ```
    // Returns integer value between 0 and 1000, where 1000 is the highest quality
    public func fromText(text : Text) : ?Nat {
        let trimmed = Text.trim(text, #char(' '));

        // Handle empty string
        if (Text.size(trimmed) == 0) {
            return null;
        };

        // Split on decimal point
        let parts = Text.split(trimmed, #char('.'));
        let ?intPartText = parts.next() else return null; // Invalid format - no integer part
        let decimalPartTextOrNull = parts.next();
        let null = parts.next() else return null; // Invalid format - too many decimal points

        // Parse integer part
        switch (intPartText) {
            case ("" or "0") (); // Continue to decimal part
            case ("1") {
                // For integer part "1", decimal part must be 0 or missing
                switch (decimalPartTextOrNull) {
                    case (null or ?"" or ?"0" or ?"00" or ?"000") return ?1000;
                    case (_) return null; // Invalid - can't be greater than 1.0
                };
            };
            case (_) return null; // Has to be 0 or 1 or empty string
        };

        // If no decimal part, return early
        switch (decimalPartTextOrNull) {
            case (null or ?"" or ?"0") return ?0; // 0.0 or 0
            case (?decimalPartText) {
                let precision = Text.size(decimalPartText);

                // Convert decimal part to integer
                let decimalNat = switch (NatX.fromText(decimalPartText)) {
                    case (null) return null;
                    case (?val) val;
                };
                // Max precision is 3
                let precisionDiff : Int = 3 - precision;
                let value : Nat = if (precisionDiff == 0) {
                    // No change needed
                    decimalNat;
                } else if (precisionDiff > 0) {
                    // Add trailing zeros
                    decimalNat * Int.abs(Int.pow(10, precisionDiff));
                } else {
                    // Remove trailing values
                    decimalNat / Int.abs(Int.pow(10, Int.abs(precisionDiff)));
                };
                ?value;
            };
        };
    };
};
