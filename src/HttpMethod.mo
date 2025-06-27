import Text "mo:new-base/Text";
module {

    public type HttpMethod = {
        #get;
        #post;
        #put;
        #patch;
        #delete;
        #head;
        #options;
    };

    /// Converts an HttpMethod enum to its string representation.
    /// Returns the HTTP method name in uppercase (e.g., "GET", "POST").
    ///
    /// ```motoko
    /// let method = #post;
    /// let methodText = HttpMethod.toText(method);
    /// // methodText is "POST"
    /// ```
    public func toText(method : HttpMethod) : Text {
        switch (method) {
            case (#get) "GET";
            case (#post) "POST";
            case (#put) "PUT";
            case (#patch) "PATCH";
            case (#delete) "DELETE";
            case (#head) "HEAD";
            case (#options) "OPTIONS";
        };
    };

    /// Parses a string into an HttpMethod enum.
    /// The parsing is case-insensitive. Returns null for unrecognized methods.
    ///
    /// ```motoko
    /// let method1 = HttpMethod.fromText("GET");
    /// // method1 is ?#get
    ///
    /// let method2 = HttpMethod.fromText("post");
    /// // method2 is ?#post
    ///
    /// let invalid = HttpMethod.fromText("INVALID");
    /// // invalid is null
    /// ```
    public func fromText(value : Text) : ?HttpMethod {
        switch (Text.toLower(value)) {
            case ("get") ?#get;
            case ("post") ?#post;
            case ("put") ?#put;
            case ("patch") ?#patch;
            case ("delete") ?#delete;
            case ("head") ?#head;
            case ("options") ?#options;
            case (_) null;
        };
    };
};
