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
            // ("", "*", true),
            ("", "?", false),

            // Exact matches
            ("/index.html", "/index.html", true),
            ("/index.html", "/index.htm", false),
            ("", "", true),

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
            ("file.txt", ".*\\.txt", true),
            ("file.txt.bak", "file.*", true),
        ];

        for ((path, globPattern, expected) in toRegexCases.vals()) {
            test(
                "match - Path: '" # path # "', Glob: '" # globPattern # "'",
                func() {
                    expect.bool(Glob.match(path, globPattern)).equal(expected);
                },
            );
        };
    },
);
