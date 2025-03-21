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
