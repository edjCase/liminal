// import Pipeline "./Pipeline";
// import Array "mo:base/Array";
// import Text "mo:base/Text";
// import Buffer "mo:base/Buffer";
// import Nat16 "mo:base/Nat16";
// import Option "mo:base/Option";
// import Blob "mo:base/Blob";
// import CertifiedAssets "mo:certified-assets";
// import HttpContext "./HttpContext";
// import Types "./Types";
// import HttpTypes "./HttpTypes";
// import HttpMethod "HttpMethod";

// module {
//     public type Options = {
//         assets : CertifiedAssets.CertifiedAssets;
//         fallbackPath : ?Text;
//     };

//     public func use(data : Pipeline.PipelineData, options : Options) : Pipeline.PipelineData {
//         let newMiddleware = createMiddleware(options);
//         {
//             middleware = Array.append(data.middleware, [newMiddleware]);
//         };
//     };

//     public func createMiddleware(options : Options) : Pipeline.Middleware {
//         {
//             handleQuery = ?(
//                 func(context : HttpContext.HttpContext, next : Pipeline.Next) : ?Types.HttpResponse {
//                     let ?response = next() else return null;
//                     ?handleResponse(context, response, options);
//                 }
//             );
//             handleUpdate = func(context : HttpContext.HttpContext, next : Pipeline.NextAsync) : async* ?Types.HttpResponse {
//                 let ?response = await* next() else return null;
//                 ?handleResponse(context, response, options);
//             };
//         };
//     };

//     private func handleResponse(context : HttpContext.HttpContext, response : Types.HttpResponse, options : Options) : Types.HttpResponse {
//         let req : HttpTypes.QueryRequest = {
//             method = HttpMethod.toText(context.method);
//             url = context.request.url;
//             headers = context.request.headers;
//             body = context.request.body;
//             certificate_version = null; // TODO
//         };
//         let res : HttpTypes.QueryResponse = {
//             status_code = Nat16.fromNat(response.statusCode);
//             headers = response.headers;
//             body = Option.get(response.body, Blob.fromArray([]));
//             streaming_strategy = null;
//             upgrade = null;
//         };

//         switch (options.assets.get_certificate(req, res, null)) {
//             // Return certified response if successful
//             case (#ok(certified)) certified;

//             // Try fallback if configured
//             case (#err(_)) {
//                 response;
//             };
//         };
//     };
// };
