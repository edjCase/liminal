import { test; suite; expect } "mo:test";
import Bool "mo:base/Bool";
import Glob "../src/Glob";

suite(
    "Glob tests",
    func() {

        let toRegexCases : [(Text, Text, Bool)] = [

            ("hello.txt", "*.txt", true),
            ("hello.txt", "h*.txt", true),
            ("hello.txt", "h????.txt", true),
            ("a.txt", "?.txt", true),
            ("hello.dat", "*.txt", false),
            ("hello.txt", "h*z.txt", false),
            ("abc", "*", true),
            ("abc", "a*", true),
            ("abc", "*c", true),
            ("abc", "a*c", true),
            ("abbc", "a*c", true),
            ("a/b/c", "a/*/c", true),
            ("abc", "a?c", true),
            ("abbc", "a??c", true),

            // Exact matches
            ("/index.html", "/index.html", true),
            ("/index.html", "/index.htm", false),

            // Basic wildcards
            ("file.txt", "*.txt", true),
            ("file.jpg", "*.txt", false),
            ("/path/to/file.txt", "*.txt", false),
            ("/path/to/file.txt", "**/*.txt", true),

            // Directory wildcards
            ("/foo/bar/baz", "/foo/*/baz", true),
            ("/foo/bar/qux/baz", "/foo/*/baz", false),
            ("/foo/bar/baz", "/foo/**/baz", true),
            ("/foo/bar/qux/baz", "/foo/**/baz", true),

            // Multiple wildcards
            ("abc.test.txt", "*.*.txt", true),
            ("abc.test.jpg", "*.*.txt", false),
            ("/root/*/a/*/b", "/root/*/a/*/b", true),
            ("/root/x/a/y/b", "/root/*/a/*/b", true),
            ("/root/x/a/y/c", "/root/*/a/*/b", false),

            // Character classes
            ("file1.txt", "file[1-3].txt", true),
            ("file4.txt", "file[1-3].txt", false),
            ("file1.txt", "file[!1-3].txt", false),
            ("file4.txt", "file[!1-3].txt", true),

            // Complex patterns
            ("/home/user/docs/file.txt", "/**/docs/**/*.txt", true),
            ("/home/user/documents/file.txt", "/**/docs/**/*.txt", false),
            ("/a/b/c/d/e/f/g/h.txt", "/**/*.txt", true),
            ("/a/b/c/d/e/f/g/h.jpg", "/**/*.txt", false),

            // Edge cases
            ("/.hidden", "/.*", true),
            ("/path/to/.hidden", "/**/*", true),
            ("/path/with spaces/file.txt", "/path/with spaces/*.txt", true),
            ("/path/with spaces/file.txt", "/path/with\\ spaces/*.txt", true),

            // Special characters
            ("/path/[bracket]/file.txt", "/path/\\[bracket\\]/*.txt", true),
            ("/path/(paren)/file.txt", "/path/\\(paren\\)/*.txt", true),
            ("/path/+plus+/file.txt", "/path/\\+plus\\+/*.txt", true),

            // Nested patterns
            ("/a/b/c/d/file.txt", "/a/**/d/*.txt", true),
            ("/a/b/c/e/file.txt", "/a/**/d/*.txt", false),
            ("/a/b/c/d/e/f/file.txt", "/a/**/d/**/*.txt", true),

            // Root directory patterns
            ("/.config", "/.config", true),
            ("/.config/file", "/.config/*", true),
            ("/.config/dir/file", "/.config/**", true),

            // Mixed case sensitivity (assuming case-sensitive)
            ("/path/File.txt", "/path/file.txt", false),
            ("/path/File.txt", "/path/[Ff]ile.txt", true),

            // Boundaries and anchors
            ("file.txt", "file.*", true),
            ("file.txt.bak", "file.*", true),

            // Multiple character ranges
            ("x1y", "x[1-3]y", true),
            ("x2y", "x[1-3]y", true),
            ("x4y", "x[1-3]y", false),
            ("file2.txt", "file[1-3].txt", true),
            ("file3.txt", "file[1-3].txt", true),

            // Character sets
            ("fileA.txt", "file[ABC].txt", true),
            ("fileD.txt", "file[ABC].txt", false),
            ("test.txt", "t[e]st.txt", true),
            ("tast.txt", "t[e]st.txt", false),

            // Negated character sets
            ("fileD.txt", "file[!ABC].txt", true),
            ("fileA.txt", "file[!ABC].txt", false),
            ("tist.txt", "t[!e]st.txt", true),
            ("test.txt", "t[!e]st.txt", false),

            // Combined ranges and sets
            ("file1.log", "file[1-3ABC].log", true),
            ("fileA.log", "file[1-3ABC].log", true),
            ("fileD.log", "file[1-3ABC].log", false),

            // Multiple character classes in pattern
            ("test1A.txt", "test[1-3][A-C].txt", true),
            ("test2B.txt", "test[1-3][A-C].txt", true),
            ("test4A.txt", "test[1-3][A-C].txt", false),
            ("test1D.txt", "test[1-3][A-C].txt", false),

            // Escaped characters in character classes
            ("file[.txt", "file\\[.txt", true),
            ("file].txt", "file\\].txt", true),
            ("file-.txt", "file\\-.txt", true),

            // Complex character class combinations
            ("fileA-1.txt", "file[A-C]-[1-3].txt", true),
            ("file-2.txt", "file-[1-3].txt", true),
            ("fileD-4.txt", "file[A-C]-[1-3].txt", false),

            // Character classes with special characters
            ("file$.txt", "file[\\!@#$%].txt", true),
            ("file&.txt", "file[\\!@#$%].txt", false),

            // Adjacent character classes
            ("aXb", "a[X-Z][a-c]", true),
            ("aXd", "a[X-Z][a-c]", false),

            // Character classes with wildcards
            ("testA123.txt", "test[A-C]*[0-9].txt", true),
            ("testB456.txt", "test[A-C]*[0-9].txt", true),
            ("testD123.txt", "test[A-C]*[0-9].txt", false),

            // Character classes at path boundaries
            ("/[test]/file.txt", "/\\[test\\]/file.txt", true),
            ("/[abc]/file.txt", "/\\[abc\\]/file.txt", true),

            // Mixed wildcards and character classes
            ("file123.txt", "file[1-3]*[1-3].txt", true),
            ("file1ABC3.txt", "file[1-3]*[1-3].txt", true),
            ("file4ABC3.txt", "file[1-3]*[1-3].txt", false),

            // Nested directory character classes
            ("/a/[b]/c", "/a/\\[b\\]/c", true),
            ("/a/[xyz]/c", "/a/\\[xyz\\]/c", true),
            ("/a/[b]/[c]", "/a/\\[b\\]/\\[c\\]", true),

            // Complex combinations
            ("testA1B2C3.txt", "test[A-C][1-3][A-C][1-3][A-C][1-3].txt", true),
            ("testA1B2D3.txt", "test[A-C][1-3][A-C][1-3][A-C][1-3].txt", false),
            ("test123ABC.txt", "test[1-3]*[A-C].txt", true),
            ("test456ABC.txt", "test[1-3]*[A-C].txt", false),

            // Empty and special directory patterns
            ("", "", true),
            ("", "*", true),
            (".", ".", true),
            ("..", "..", true),
            ("./path", "./path", true),
            ("../path", "../path", true),
            ("foo/./bar", "foo/./bar", true),
            ("foo/../bar", "foo/../bar", true),
            ("///path///file.txt", "/path/file.txt", true),
            ("path/", "path", true),
            ("path/", "path/", true),
            ("path//file.txt", "path/file.txt", true),

            // Multiple asterisk patterns
            ("abc", "***", true),
            ("abc/def", "*/**", true),
            ("abc/def", "**/*", true),
            ("abc/def/ghi", "**/**/**", true),

            // Character class edge cases
            ("x", "[]", false), // empty character class
            ("a", "[a]", true), // single character class
            ("2", "[3-1]", false), // invalid range
            ("á", "[à-ç]", true), // unicode range
            ("b", "[a-zA-Z]", true), // overlapping ranges
            ("B", "[a-zA-Z]", true),
            ("\u{0100}", "[\u{0000}-\u{1000}]", true), // unicode escape sequences

            // Long paths and patterns
            ("/very/very/very/very/very/very/very/very/very/very/long/path/file.txt", "/**/*.txt", true),
            ("/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p", "/a/**/p", true),
            ("file.txt", "[a-z][a-z][a-z][a-z].[t][x][t]", true),

            // Error cases (implementation dependent - may need to handle these specifically)
            ("file.txt", "[unterminated", false),
            ("file.txt", "\\", false),
            ("file.txt", "[a-]", false),
            ("file.txt", "[z-a]", false),

            // Performance test cases
            ("aaaaaaaaaaaaaaaaaa", "a*a*a*a*a*a*a*a", true),
            ("aaaaaaaaaaaaaaaaaa", "*a*a*a*a*a*a*a*", true),
            ("bbbbbbbbbaaaaaaaaa", "*a*a*a*a*a*a*a*", true),
            ("/a/a/a/a/a/a/a/a/a/b", "/**/a/**", true),
            ("/a/a/a/a/a/a/a/a/a/b", "/a/**/a/**/a/**/b", true),

            // Complex combinations of multiple features
            ("path/to/[file]/with/{brace}/and/(paren).txt", "path/to/\\[file\\]/with/\\{brace\\}/and/\\(paren\\).txt", true),
            ("./.hidden/../../file.txt", "**/*file.txt", true),
            ("C:/Program Files (x86)/App/file.txt", "C:/Program Files (*)/App/*.txt", true),
            ("file-[bracketed]-{braced}-(parens).txt", "file-\\[*\\]-\\{*\\}-\\(*\\).txt", true),

            // Symbolic link related (if supported by implementation)
            ("symlink", "symlink", true),
            ("symlink/file.txt", "symlink/*.txt", true),
            ("real/path/through/symlink/file.txt", "**/file.txt", true),

            // Mixed case with special characters
            ("File[1].{txt}", "File\\[*\\].\\{txt\\}", true),
            ("PATH/To/FILE.txt", "[Pp][Aa][Tt][Hh]/[Tt][Oo]/[Ff][Ii][Ll][Ee].[Tt][Xx][Tt]", true),

            // Zero-width patterns
            ("", "?*", false),
            ("", "*?", false),
            ("", "**?", false),
            ("", "?**", false),
        ];

        for ((path, globPattern, expected) in toRegexCases.vals()) {
            test(
                "match - Path: '" # path # "', Glob: '" # globPattern # "' - Expected: " # Bool.toText(expected),
                func() {
                    expect.bool(Glob.match(path, globPattern)).equal(expected);
                },
            );
        };
    },
);
