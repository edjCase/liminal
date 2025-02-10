module {
    public type Header = (Text, Text);

    public type HttpMethod = {
        #get;
        #post;
        #put;
        #delete;
        #options;
    };

    module HttpMethod {
        public func toText(method : HttpMethod) : Text {
            switch (method) {
                case (#get) "GET";
                case (#post) "POST";
                case (#put) "PUT";
                case (#delete) "DELETE";
                case (#options) "OPTIONS";
            };
        };
    };

    public type HttpRequest = {
        method : HttpMethod;
        url : Text;
        headers : [Header];
        body : Blob;
    };

    public type HttpStatusCode = Nat;

    public type HttpResponse = {
        statusCode : HttpStatusCode;
        headers : [Header];
        body : ?Blob;
    };
};
