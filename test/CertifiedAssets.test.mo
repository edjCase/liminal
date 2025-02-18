// import { test = testAsync; suite = suiteAsync } "mo:test/async";
// import Types "../src/Types";
// import Pipeline "../src/Pipeline";
// import Blob "mo:base/Blob";
// import Debug "mo:base/Debug";
// import CertifiedAssets "mo:certified-assets";
// import CertAssetsMiddleware "../src/CertifiedAssets";
// import HttpContext "../src/HttpContext";

// func getHeader(headers : [(Text, Text)], key : Text) : ?Text {
//     for ((k, v) in headers.vals()) {
//         if (k == key) return ?v;
//     };
//     null;
// };

// func createMockRequest(url : Text) : (HttpContext.HttpContext, Pipeline.NextAsync) {
//     let httpContext = HttpContext.HttpContext({
//         method = "GET";
//         url = url;
//         headers = [];
//         body = Blob.fromArray([]);
//     });
//     (
//         httpContext,
//         func() : async* ?Types.HttpResponse {
//             ?{
//                 statusCode = 200;
//                 headers = [];
//                 body = null;
//             };
//         },
//     );
// };

// await suiteAsync(
//     "Certified Assets Middleware Tests",
//     func() : async () {

//         await testAsync(
//             "adds certification headers to response",
//             func() : async () {
//                 let cert_store = CertifiedAssets.init_stable_store();
//                 let certs = CertifiedAssets.CertifiedAssets(?cert_store);

//                 // Certify an endpoint
//                 let endpoint = CertifiedAssets.Endpoint("/test", ?"test data").status(200);
//                 certs.certify(endpoint);

//                 let middleware = CertAssetsMiddleware.createMiddleware({
//                     assets = certs;
//                     fallbackPath = null;
//                 });

//                 let request = createMockRequest("/test");
//                 let ?response = await* middleware.handleUpdate(request) else Debug.trap("Response is null");

//                 assert (getHeader(response.headers, "IC-Certificate") != null);
//                 assert (getHeader(response.headers, "IC-CertificateExpression") != null);
//             },
//         );

//         await testAsync(
//             "uses fallback when configured",
//             func() : async () {
//                 let cert_store = CertifiedAssets.init_stable_store();
//                 let certs = CertifiedAssets.CertifiedAssets(?cert_store);

//                 // Certify a fallback endpoint
//                 let fallback = CertifiedAssets.Endpoint("/", ?"fallback data").status(200).is_fallback(true);
//                 certs.certify(fallback);

//                 let middleware = CertAssetsMiddleware.createMiddleware({
//                     assets = certs;
//                     fallbackPath = ?"/";
//                 });

//                 let request = createMockRequest("/unknown");
//                 let ?response = await* middleware.handleUpdate(request) else Debug.trap("Response is null");

//                 assert (getHeader(response.headers, "IC-Certificate") != null);
//                 assert (getHeader(response.headers, "IC-CertificateExpression") != null);
//             },
//         );

//         await testAsync(
//             "preserves response when certification fails",
//             func() : async () {
//                 let cert_store = CertifiedAssets.init_stable_store();
//                 let certs = CertifiedAssets.CertifiedAssets(?cert_store);

//                 let middleware = CertAssetsMiddleware.createMiddleware({
//                     assets = certs;
//                     fallbackPath = null;
//                 });

//                 let request = createMockRequest("/uncertified");
//                 let ?response = await* middleware.handleUpdate(request) else Debug.trap("Response is null");

//                 assert (response.statusCode == 200);
//                 assert (getHeader(response.headers, "IC-Certificate") == null);
//                 assert (getHeader(response.headers, "IC-CertificateExpression") == null);
//             },
//         );

//         await testAsync(
//             "handles null response from next",
//             func() : async () {
//                 let cert_store = CertifiedAssets.init_stable_store();
//                 let certs = CertifiedAssets.CertifiedAssets(?cert_store);

//                 let middleware = CertAssetsMiddleware.createMiddleware({
//                     assets = certs;
//                     fallbackPath = null;
//                 });

//                 let httpContext = HttpContext.HttpContext({
//                     method = "GET";
//                     url = "/test";
//                     headers = [];
//                     body = Blob.fromArray([]);
//                 });

//                 let next = func() : async* ?Types.HttpResponse {
//                     null;
//                 };

//                 let response = await* middleware.handleUpdate(httpContext, next);
//                 assert (response == null);
//             },
//         );
//     },
// );
