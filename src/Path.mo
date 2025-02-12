import Text "mo:base/Text";
import Iter "mo:base/Iter";
import IterTools "mo:itertools/Iter";

module {
    public type Path = [Segment];

    public type Segment = Text;

    public func parse(path : Text) : Path {
        path
        |> Text.split(_, #char('/'))
        |> Iter.filter(_, func(x : Text) : Bool { x != "" })
        |> Iter.toArray(_);
    };

    public func match(prefix : Path, path : Path) : ?Path {
        let prefixSize = prefix.size();
        let pathSize = path.size();
        if (prefixSize > pathSize) {
            return null;
        };
        let commonSize = IterTools.zip(prefix.vals(), path.vals())
        |> IterTools.takeWhile(
            _,
            func(pair : (Segment, Segment)) : Bool {
                let (prefixSegment, pathSegment) = pair;
                prefixSegment == pathSegment;
            },
        )
        |> Iter.size(_);
        if (commonSize == prefixSize) {
            let remainingPath = path.vals() |> IterTools.skip(_, commonSize) |> Iter.toArray(_);
            return ?remainingPath;
        };
        null; // No match
    };
};
