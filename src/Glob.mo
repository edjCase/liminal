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

    // Parse a character range like [1-3] and return the start and end characters
    private func parseCharRange(pattern : [Char], index : Nat) : ?(Char, Char, Nat) {
        if (index + 3 >= pattern.size()) {
            return null;
        };

        // Check for [c-c] pattern
        if (pattern[index] == '[' and pattern[index + 2] == '-' and pattern[index + 4] == ']') {
            return ?(pattern[index + 1], pattern[index + 3], 5);
        };

        null;
    };

    // Check if a character is within a range
    private func charInRange(c : Char, start : Char, end : Char) : Bool {
        let codePoint = Char.toNat32(c);
        let startPoint = Char.toNat32(start);
        let endPoint = Char.toNat32(end);
        return codePoint >= startPoint and codePoint <= endPoint;
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
            case (?(start, end, rangeLen)) {
                if (segmentIndex < segment.size() and charInRange(segment[segmentIndex], start, end)) {
                    return matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex + rangeLen);
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
