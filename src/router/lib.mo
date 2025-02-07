import Types "../types";

module {

    public type QueryRequestHandler = (req : Types.QueryRequest) -> Types.QueryResponse;

    public class Router() = this {

        public func get(path : Text, handler : QueryRequestHandler) : Router {
            this;
        };
    };
};
