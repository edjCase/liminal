module {
    public type Header = (Text, Text);

    public type HttpMethod = {
        #get;
        #post;
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
