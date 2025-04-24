import Text "mo:new-base/Text";
import Blob "mo:base/Blob";
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
        streamingStrategy : ?StreamingStrategy;
    };

    public type StreamingToken = Blob;

    public type CallbackStreamingStrategy = {
        callback : StreamingCallback;
        token : StreamingToken;
    };

    public type StreamingStrategy = {
        #callback : CallbackStreamingStrategy;
    };

    public type StreamingCallback = shared query (StreamingToken) -> async StreamingCallbackResponse;

    public type StreamingCallbackResponse = {
        body : Blob;
        token : ?StreamingToken;
    };

};
