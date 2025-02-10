import Text "mo:base/Text";
import HttpMethod "HttpMethod";

module {
    public type Header = (Text, Text);

    public type HttpRequest = {
        method : HttpMethod.HttpMethod;
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
