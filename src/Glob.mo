import Text "mo:base/Text";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Path "Path";

module Module {

    public class CompiledGlob(pattern : Text) {
        let compiledPattern : CompiledPattern = compilePattern(pattern);
        public func match(path : Text) : Bool {
            matchCompiled(path, compiledPattern);
        };
    };

    public func match(path : Text, pattern : Text) : Bool {
        // Handle negation patterns
        if (Text.startsWith(pattern, #text("!"))) {
            let positivePattern = Text.trimStart(pattern, #char('!'));
            // Return true if the path does NOT match the positive pattern
            return not matchPositive(path, positivePattern);
        };

        matchPositive(path, pattern);
    };

    private type CompiledPattern = {
        pattern : Text;
        isNegated : Bool;
        expandedPatterns : [Text];
    };

    private func compilePattern(pattern : Text) : CompiledPattern {
        // Handle negation patterns
        let isNegated = Text.startsWith(pattern, #text("!"));
        let cleanPattern = if (isNegated) {
            Text.trimStart(pattern, #char('!'));
        } else {
            pattern;
        };

        // Pre-expand brace patterns for better performance
        let expandedPatterns = expandBracePattern(cleanPattern);

        {
            pattern = cleanPattern;
            isNegated = isNegated;
            expandedPatterns = expandedPatterns;
        };
    };

    private func matchCompiled(path : Text, compiled : CompiledPattern) : Bool {
        // If pattern is negated, invert the match result
        if (compiled.isNegated) {
            return not matchPositive(path, compiled.pattern);
        };

        // Try matching against each expanded pattern
        for (expandedPattern in compiled.expandedPatterns.vals()) {
            if (matchSingle(path, expandedPattern)) {
                return true;
            };
        };
        false;
    };

    private func matchPositive(path : Text, pattern : Text) : Bool {
        let expandedPatterns = expandBracePattern(pattern);

        // Try matching against each expanded pattern
        for (expandedPattern in expandedPatterns.vals()) {
            if (matchSingle(path, expandedPattern)) {
                return true;
            };
        };
        false;
    };

    private func matchSingle(path : Text, pattern : Text) : Bool {
        // Special case: if pattern is "*" and path is empty, return true
        if (pattern == "*" and path == "") {
            return true;
        };

        // Special case: if path is empty and pattern contains '?', return false
        if (path == "" and Text.contains(pattern, #char('?'))) {
            return false;
        };

        let pathSegments = Path.parse(path);
        let patternSegments = Path.parse(pattern);

        // Check if pattern ends with slash (indicating directory)
        let patternEndsWithSlash = Text.endsWith(pattern, #text "/");
        if (patternEndsWithSlash) {
            // If pattern ends with slash but path doesn't represent a directory, return false
            if (not Text.endsWith(path, #text "/") and path != "") {
                return false;
            };
        };

        // Only enforce absolute path matching if pattern doesn't start with **
        let pathIsAbsolute = Text.startsWith(path, #text "/");
        let patternIsAbsolute = Text.startsWith(pattern, #text "/");

        // If pattern starts with **, allow mixing absolute and relative paths
        if (patternSegments.size() > 0 and patternSegments[0] == "**") {
            return matchSegments(pathSegments, patternSegments, 0, 0);
        };

        // Otherwise, enforce absolute/relative path consistency
        if (pathIsAbsolute != patternIsAbsolute) {
            return false;
        };

        matchSegments(pathSegments, patternSegments, 0, 0);
    };

    private func expandBracePattern(pattern : Text) : [Text] {
        let chars = Iter.toArray(pattern.chars());
        if (not hasBraces(chars)) {
            return [pattern];
        };

        var result : [Text] = [];
        var current = "";
        var braceContent = "";
        var inBrace = false;
        var depth = 0;
        var i = 0;

        label w while (i < chars.size()) {
            let c = chars[i];

            // Handle escaped characters
            if (c == '\\' and i + 1 < chars.size()) {
                let nextChar = chars[i + 1];
                current #= Char.toText(c) # Char.toText(nextChar);
                i += 2;
                continue w;
            };

            switch (c) {
                case ('{') {
                    if (depth == 0) {
                        inBrace := true;
                    } else if (inBrace) {
                        braceContent #= Char.toText(c);
                    };
                    depth += 1;
                };
                case ('}') {
                    depth -= 1;
                    if (depth == 0 and inBrace) {
                        // Process the brace content
                        let options = splitOptions(braceContent);
                        var expanded : [Text] = [];
                        for (opt in options.vals()) {
                            let prefix = current;
                            let newPatterns = expandBracePattern(opt);
                            for (p in newPatterns.vals()) {
                                expanded := Array.append(expanded, [prefix # p]);
                            };
                        };
                        result := Array.append(result, expanded);
                        current := "";
                        braceContent := "";
                        inBrace := false;
                    } else if (inBrace) {
                        braceContent #= Char.toText(c);
                    };
                };
                case (c) {
                    if (inBrace) {
                        braceContent #= Char.toText(c);
                    } else {
                        current #= Char.toText(c);
                    };
                };
            };
            i += 1;
        };

        if (current != "") {
            result := Array.append(result, [current]);
        };

        if (result.size() == 0) {
            return [pattern];
        };
        result;
    };

    private func hasBraces(chars : [Char]) : Bool {
        var depth = 0;
        var i = 0;
        label w while (i < chars.size()) {
            let c = chars[i];

            // Skip escaped characters
            if (c == '\\' and i + 1 < chars.size()) {
                i += 2;
                continue w;
            };

            switch (c) {
                case ('{') { depth += 1 };
                case ('}') {
                    depth -= 1;
                    if (depth == 0) { return true };
                };
                case (_) {};
            };
            i += 1;
        };
        false;
    };

    private func splitOptions(content : Text) : [Text] {
        let chars = Iter.toArray(content.chars());
        var result : [Text] = [];
        var current = "";
        var depth = 0;

        for (c in chars.vals()) {
            switch (c) {
                case ('{') {
                    depth += 1;
                    current #= Char.toText(c);
                };
                case ('}') {
                    depth -= 1;
                    current #= Char.toText(c);
                };
                case (',') {
                    if (depth == 0) {
                        result := Array.append(result, [current]);
                        current := "";
                    } else {
                        current #= Char.toText(c);
                    };
                };
                case (c) {
                    current #= Char.toText(c);
                };
            };
        };

        if (current != "") {
            result := Array.append(result, [current]);
        };
        result;
    };

    private func matchSegments(
        pathSegments : [Text],
        patternSegments : [Text],
        pathIndex : Nat,
        patternIndex : Nat,
    ) : Bool {
        let pathLength = pathSegments.size();
        let patternLength = patternSegments.size();

        // Special case: if both path and pattern are empty, return true
        if (pathLength == 0 and patternLength == 0) {
            return true;
        };

        // If we've matched all path segments
        if (pathIndex == pathLength) {
            // If we've also matched all pattern segments, it's a match
            if (patternIndex == patternLength) {
                return true;
            };
            // If there's exactly one pattern segment left and it's **, it's a match
            if (patternIndex == (patternLength - 1 : Nat) and patternSegments[patternIndex] == "**") {
                return true;
            };
            return false;
        };

        // If we've matched all pattern segments but still have path segments, no match
        if (patternIndex >= patternLength) {
            return false;
        };

        let currentPattern = patternSegments[patternIndex];
        let currentPath = pathSegments[pathIndex];

        // Handle "**" pattern specially
        if (currentPattern == "**") {
            // Match zero or more path segments
            return matchSegments(pathSegments, patternSegments, pathIndex + 1, patternIndex) or matchSegments(pathSegments, patternSegments, pathIndex, patternIndex + 1);
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
    private type CharSet = {
        ranges : [(Char, Char)];
        chars : [Char];
        negated : Bool;
        length : Nat;
    };

    private func parseCharSet(pattern : [Char], index : Nat) : ?CharSet {
        if (index >= pattern.size() or pattern[index] != '[') {
            return null;
        };

        var pos = index + 1;
        var negated = false;

        // Check for negation
        if (pos < pattern.size() and pattern[pos] == '!') {
            negated := true;
            pos += 1;
        };

        var ranges : [(Char, Char)] = [];
        var chars : [Char] = [];
        var tempChars : [var Char] = [var];
        var length = 0;

        label l loop {
            if (pos >= pattern.size()) {
                break l;
            };

            let c = pattern[pos];
            if (c == ']' and pos > index + 1) {
                // Convert tempChars to immutable array
                chars := Array.tabulate<Char>(length, func(i) { tempChars[i] });
                // Include the closing bracket in length
                return ?{
                    ranges = ranges;
                    chars = chars;
                    negated = negated;
                    length = pos + 1 - index;
                };
            };

            // Check for range pattern
            if (pos + 2 < pattern.size() and pattern[pos + 1] == '-' and pattern[pos + 2] != ']') {
                let start = c;
                let end = pattern[pos + 2];
                ranges := Array.append(ranges, [(start, end)]);
                pos += 3;
                continue l;
            };

            // Add to character set
            let newChars = Array.tabulateVar<Char>(
                length + 1,
                func(i) {
                    if (i < length) { tempChars[i] } else { c };
                },
            );
            tempChars := newChars;
            length += 1;
            pos += 1;
        };

        null;
    };

    private func charMatchesCharSet(c : Char, charSet : CharSet) : Bool {
        // Check if character matches any range
        for ((start, end) in charSet.ranges.vals()) {
            let codePoint = Char.toNat32(c);
            let startPoint = Char.toNat32(start);
            let endPoint = Char.toNat32(end);
            if (codePoint >= startPoint and codePoint <= endPoint) {
                return if (charSet.negated) false else true;
            };
        };

        // Check if character matches any individual char
        for (setChar in charSet.chars.vals()) {
            if (c == setChar) {
                return if (charSet.negated) false else true;
            };
        };

        // No match found
        if (charSet.negated) true else false;
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

        // Early return if we have a ? pattern but no more characters in segment
        if (patternIndex < pattern.size() and pattern[patternIndex] == '?' and segmentIndex >= segment.size()) {
            return false;
        };

        if (segmentIndex > segment.size() or patternIndex >= pattern.size()) {
            if (patternIndex < pattern.size()) {
                return pattern[patternIndex] == '*' and matchSegmentRecursive(segment, pattern, segmentIndex, patternIndex + 1);
            };
            return false;
        };

        // Handle escaped characters
        if (patternIndex + 1 < pattern.size() and pattern[patternIndex] == '\\') {
            let nextChar = pattern[patternIndex + 1];
            // Check if the next character is a special character that needs escaping
            switch (nextChar) {
                case (
                    '\\' or '[' or ']' or '{' or '}' or '*' or '?' or ' ' or
                    '(' or ')' or '|' or ',' or '-' or '!' or '^' or '$' or '.' or '+' or
                    '#' or '@' or ';' or '&' or '~' or ':'
                ) {
                    if (segmentIndex < segment.size() and segment[segmentIndex] == nextChar) {
                        return matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex + 2);
                    };
                    return false;
                };
                case (_) {
                    // If it's not a special character, treat backslash literally
                    if (segmentIndex < segment.size() and segment[segmentIndex] == '\\') {
                        return matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex + 1);
                    };
                    return false;
                };
            };
        };

        // Check for character set or range
        switch (parseCharSet(pattern, patternIndex)) {
            case (?charSet) {
                if (segmentIndex < segment.size() and charMatchesCharSet(segment[segmentIndex], charSet)) {
                    return matchSegmentRecursive(segment, pattern, segmentIndex + 1, patternIndex + charSet.length);
                };
                return false;
            };
            case (null) {
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
