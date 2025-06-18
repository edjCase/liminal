import RouteContext "mo:liminal/RouteContext";
import Liminal "mo:liminal";
import Iter "mo:new-base/Iter";
import Text "mo:new-base/Text";
import Nat "mo:new-base/Nat";
import FileUpload "mo:liminal/FileUpload";

module {

    let formHtml = "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>File Upload</title>
</head>
<body>
    <form action=\"/api/upload\" method=\"POST\" enctype=\"multipart/form-data\">
        <div class=\"form-group\">
            <label for=\"file\">Select file to upload:</label>
            <input type=\"file\" id=\"file\" name=\"file\">
        </div>
        <button type=\"submit\" class=\"btn\">Upload File</button>
    </form>
</body>
</html>";

    public func getUploadFormHtml(routeContext : RouteContext.RouteContext) : Liminal.HttpResponse {
        // Return the HTML form for file upload
        routeContext.buildResponse(#ok, #html(formHtml));
    };

    public func handleUpload<system>(routeContext : RouteContext.RouteContext) : Liminal.HttpResponse {
        let files = routeContext.getUploadedFiles();

        if (files.size() == 0) {
            return routeContext.buildResponse(
                #badRequest,
                #error(#message("No files were uploaded")),
            );
        };

        // Process each uploaded file
        let responseData = files.vals()
        |> Iter.map(
            _,
            func(file : FileUpload.UploadedFile) : Text {
                "Received file: " # file.filename #
                " (Size: " # Nat.toText(file.size) #
                " bytes, Type: " # file.contentType # ")";
            },
        )
        |> Text.join("\n", _);

        // Return success response
        routeContext.buildResponse(#ok, #text(responseData));
    };
};
