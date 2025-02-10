import Text "mo:base/Text";
module {

    public type HttpMethod = {
        #get;
        #post;
        #put;
        #patch;
        #delete;
        #options;
    };

    public func toText(method : HttpMethod) : Text {
        switch (method) {
            case (#get) "GET";
            case (#post) "POST";
            case (#put) "PUT";
            case (#patch) "PATCH";
            case (#delete) "DELETE";
            case (#options) "OPTIONS";
        };
    };

    public func fromText(value : Text) : ?HttpMethod {
        switch (Text.toLowercase(value)) {
            case ("get") ?#get;
            case ("post") ?#post;
            case ("put") ?#put;
            case ("patch") ?#patch;
            case ("delete") ?#delete;
            case ("options") ?#options;
            case (_) null;
        };
    };
};
