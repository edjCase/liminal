module {
    public type Header = (Text, Text);

    public type UpdateRequest = {
        url : Text;
        method : Text;
        headers : [Header];
        body : Blob;
    };

    public type QueryRequest = UpdateRequest and {
        certificate_version : ?Nat16;
    };

    public type UpdateResponse = {
        status_code : Nat16;
        headers : [Header];
        body : Blob;
        streaming_strategy : ?StreamingStrategy;
    };

    public type QueryResponse = UpdateResponse and {
        upgrade : ?Bool;
    };

    public type StreamingToken = Blob;

    public type CallbackStreamingStrategy = {
        callback : StreamingCallback;
        token : StreamingToken;
    };

    public type StreamingStrategy = {
        #Callback : CallbackStreamingStrategy;
    };

    public type StreamingCallback = shared query (StreamingToken) -> async StreamingCallbackResponse;

    public type StreamingCallbackResponse = {
        body : Blob;
        token : ?StreamingToken;
    };
};
