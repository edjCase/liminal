import Text "mo:base/Text";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Path "Path";

module {
    public func match(path : Text, pattern : Text) : Bool {
        let pathSegments = Path.parse(path);
        let patternSegments = Path.parse(pattern);

        matchSegments(pathSegments, patternSegments, 0, 0);
    };

    private func matchSegments(
        pathSegments : [Text],
        patternSegments : [Text],
        pathIndex : Nat,
        patternIndex : Nat,
    ) : Bool {
        if (pathIndex == pathSegments.size() and patternIndex == patternSegments.size()) {
            return true;
        };

        if (pathIndex >= pathSegments.size() or patternIndex >= patternSegments.size()) {
            return false;
        };

        let currentPattern = patternSegments[patternIndex];
        let currentPath = pathSegments[pathIndex];

        // Handle "**" pattern specially
        if (currentPattern == "**") {
            return matchSegments(pathSegments, patternSegments, pathIndex, patternIndex + 1) or matchSegments(pathSegments, patternSegments, pathIndex + 1, patternIndex);
        };

        if (matchSegment(currentPath, currentPattern)) {
            return matchSegments(pathSegments, patternSegments, pathIndex + 1, patternIndex + 1);
        };

        false;
    };

    private func matchSegment(segment : Text, pattern : Text) : Bool {
        let segmentChars = segment.chars() |> Iter.toArray(_);
        let patternChars = pattern.chars() |> Iter.toArray(_);
        matchSegmentRecursive(segmentChars, patternChars, 0, 0);
    };

    // Represents a character range pattern
    private type CharRange = {
        start : Char;
        end : Char;
        negated : Bool;
        length : Nat;
    };

    // Parse a character range like [1-3] or [!1-3] and return the details
    private func parseCharRange(pattern : [Char], index : Nat) : ?CharRange {
        if (index + 3 >= pattern.size()) {
            return null;
        };

        if (pattern[index] != '[') {
            return null;
        };

        var pos = index + 1;
        var negated = false;

        // Check for negation
        if (pos < pattern.size() and pattern[pos] == '!') {
            negated := true;
            pos += 1;
        };

        // Need at least 3 more characters for start-end]
        if (pos + 3 >= pattern.size()) {
            return null;
        };

        let start = pattern[pos];
        if (pattern[pos + 1] != '-') {
            return null;
        };
        let end = pattern[pos + 2];
        if (pattern[pos + 3] != ']') {
            return null;
        };

        ?{
            start = start;
            end = end;
            negated = negated;
            length = pos + 4 - index;
        };
    };

    // Check if a character is within a range
    private func charInRange(c : Char, range : CharRange) : Bool {
        let codePoint = Char.toNat32(c);
        let startPoint = Char.toNat32(range.start);
        let endPoint = Char.toNat32(range.end);
        let inRange = codePoint >= startPoint and codePoint <= endPoint;
        return if (range.negated) { not inRange } else { inRange };
    };

    private func matchSegmentRecursive(
        segment : [Char],
        pattern : [Char],
        segmentIndex : Nat,
        patternIndex : Nat,
    ) : Bool {
        if (segmentIndex == segment.size() and patternIndex == pattern.size()) {
            return true;
        };

        if (segmentIndex > segment.size() or patternIndex >= pattern.size()) {
            if (patternIndex < pattern.size()) {
                return pattern[patternIndex] == '*' and matchSegmentRecursive(segment, pattern, segmentIndex, patternIndex + 1);
            };
            return false;
        };

        // Check for character range
        switch (parseCharRange(pattern, patternIndex)) {
            case (?range) {
                if (segmentIndex < segment.size() and charInRange(segment[segmentIndex], range)) {
                    return matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex + range.length);
                };
                return false;
            };
            case null {
                switch (pattern[patternIndex]) {
                    case ('*') {
                        matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex) or matchSegmentRecursive(segment, pattern, segmentIndex, patternIndex + 1);
                    };
                    case ('?') {
                        if (segmentIndex < segment.size()) {
                            matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex + 1);
                        } else {
                            false;
                        };
                    };
                    case (patternChar) {
                        if (segmentIndex < segment.size() and segment[segmentIndex] == patternChar) {
                            matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex + 1);
                        } else {
                            false;
                        };
                    };
                };
            };
        };
    };
};
