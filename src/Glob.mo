import Text "mo:base/Text";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Path "Path";

module {
    public func match(path : Text, pattern : Text) : Bool {
        // Split path and pattern into segments
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

    // Recursive pattern matching for a single segment
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
            // Handle trailing stars
            if (patternIndex < pattern.size()) {
                return pattern[patternIndex] == '*' and matchSegmentRecursive(segment, pattern, segmentIndex, patternIndex + 1);
            };
            return false;
        };

        switch (pattern[patternIndex]) {
            case ('*') {
                // Star matches zero or more characters within the segment
                matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex) or matchSegmentRecursive(segment, pattern, segmentIndex, patternIndex + 1);
            };
            case ('?') {
                // Question mark matches exactly one character
                if (segmentIndex < segment.size()) {
                    matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex + 1);
                } else {
                    false;
                };
            };
            case (patternChar) {
                // Regular character must match exactly
                if (segmentIndex < segment.size() and segment[segmentIndex] == patternChar) {
                    matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex + 1);
                } else {
                    false;
                };
            };
        };
    };
};
