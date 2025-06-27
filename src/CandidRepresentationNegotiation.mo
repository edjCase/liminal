import App "App";
import Xml "mo:xml";
import XmlElement "mo:xml/Element";
import Runtime "mo:new-base/Runtime";
import Blob "mo:new-base/Blob";
import Prelude "mo:base/Prelude";
import HttpContext "HttpContext";
import MimeType "MimeType";
import Text "mo:base/Text";
import Serde "mo:serde";
import Iter "mo:base/Iter";
import Nat "mo:new-base/Nat";
import Nat8 "mo:new-base/Nat8";
import Nat16 "mo:new-base/Nat16";
import Nat32 "mo:new-base/Nat32";
import Nat64 "mo:new-base/Nat64";
import Int "mo:new-base/Int";
import Int8 "mo:new-base/Int8";
import Int16 "mo:new-base/Int16";
import Int32 "mo:new-base/Int32";
import Int64 "mo:new-base/Int64";
import Buffer "mo:base/Buffer";
import Float "mo:new-base/Float";
import Principal "mo:new-base/Principal";
import Option "mo:new-base/Option";
import BaseX "mo:base-x-encoder";

module {

    public type Candid = App.Candid;
    public type ContentPreference = App.ContentPreference;

    public type CustomNegotiatorOptions = {
        toJsonOverride : ?((Candid) -> Blob);
        toCborOverride : ?((Candid) -> Blob);
        toCandidOverride : ?((Candid) -> Blob);
        toXmlOverride : ?((Candid) -> Blob);
        catchAll : ?CatchAllSerializer;
    };

    public type CatchAllSerializer = (candid : Candid, type_ : Text, subType : Text) -> ?HttpContext.CandidNegotiatedContent;

    /// Default content negotiator that supports JSON, CBOR, Candid, and XML formats.
    /// Automatically selects the best response format based on client Accept headers.
    /// Uses standard serialization functions for each supported format.
    ///
    /// ```motoko
    /// let app = Liminal.App({
    ///     candidRepresentationNegotiator = CandidRepresentationNegotiation.defaultNegotiator;
    ///     // other config
    /// });
    /// ```
    public func defaultNegotiator(
        candid : Candid,
        contentPreference : ContentPreference,
    ) : ?HttpContext.CandidNegotiatedContent {
        return customNegotiator(
            candid,
            contentPreference,
            toJsonFromCandid,
            toCborFromCandid,
            toCandidFromCandid,
            toXmlFromCandid,
            null,
        );
    };

    /// Builds a custom content negotiator with override functions for specific formats.
    /// Allows customization of serialization logic while maintaining content negotiation.
    ///
    /// ```motoko
    /// let customNegotiator = CandidRepresentationNegotiation.buildCustomNegotiator({
    ///     toJsonOverride = ?myCustomJsonSerializer;
    ///     toCborOverride = null;
    ///     toCandidOverride = null;
    ///     toXmlOverride = null;
    ///     catchAll = null;
    /// });
    /// ```
    public func buildCustomNegotiator(options : CustomNegotiatorOptions) : (Candid, ContentPreference) -> ?HttpContext.CandidNegotiatedContent {
        let toJson = Option.get(options.toJsonOverride, toJsonFromCandid);
        let toCbor = Option.get(options.toCborOverride, toCborFromCandid);
        let toCandid = Option.get(options.toCandidOverride, toCandidFromCandid);
        let toXml = Option.get(options.toXmlOverride, toXmlFromCandid);
        return func(candid : Candid, contentPreference : ContentPreference) : ?HttpContext.CandidNegotiatedContent {
            return customNegotiator(
                candid,
                contentPreference,
                toJson,
                toCbor,
                toCandid,
                toXml,
                options.catchAll,
            );
        };
    };

    /// Custom content negotiator with full control over serialization functions.
    /// Provides fine-grained control over how each content type is serialized.
    ///
    /// ```motoko
    /// let result = CandidRepresentationNegotiation.customNegotiator(
    ///     candidData,
    ///     contentPreference,
    ///     myJsonSerializer,
    ///     myCborSerializer,
    ///     myCandidSerializer,
    ///     myXmlSerializer,
    ///     ?myCatchAllHandler
    /// );
    /// ```
    public func customNegotiator(
        candid : Candid,
        contentPreference : ContentPreference,
        toJson : (Candid) -> Blob,
        toCbor : (Candid) -> Blob,
        toCandid : (Candid) -> Blob,
        toXml : (Candid) -> Blob,
        catchAll : ?CatchAllSerializer,
    ) : ?HttpContext.CandidNegotiatedContent {
        label f for ({ type_; subType; parameters } in contentPreference.requestedTypes.vals()) {
            let normalizedType = type_ |> Text.trim(_, #char(' ')) |> Text.toLowercase(_);
            let normalizedSubType = subType |> Text.trim(_, #char(' ')) |> Text.toLowercase(_);
            let ?value : ?HttpContext.CandidNegotiatedContent = switch ((normalizedType, normalizedSubType)) {
                case ((normalizedType, "*")) {
                    let value = toWildcard(
                        normalizedType,
                        candid,
                        contentPreference.disallowedTypes,
                        toJson,
                        toCbor,
                        toCandid,
                        toXml,
                    );
                    switch (value) {
                        case (null) switch (catchAll) {
                            case (null) continue f;
                            case (?catchAll) catchAll(candid, normalizedType, "*");
                        };
                        case (?value) ?value;
                    };
                };
                case (("application", "json")) ?toX(candid, toJson, "application/json");
                case (("application", "cbor")) ?toX(candid, toCbor, "application/cbor");
                case (("application", "candid")) ?toX(candid, toCandid, "application/candid");
                case (("text", "xml")) ?toX(candid, toXml, "text/xml");
                case (("application", "xml")) ?toX(candid, toXml, "application/xml");
                case (_) {
                    switch (catchAll) {
                        case (null) continue f;
                        case (?catchAll) catchAll(candid, normalizedType, normalizedSubType);
                    };
                }; // Not supported
            } else continue f;
            return ?value;
        };
        return null; // No supported content type found
    };

    func toX(candid : Candid, f : (Candid) -> Blob, contentType : Text) : HttpContext.CandidNegotiatedContent {
        let blob = f(candid);
        return {
            body = blob;
            contentType = contentType;
        };
    };

    func toJsonFromCandid(candid : Candid) : Blob {
        switch (Serde.JSON.fromCandid(candid)) {
            case (#err(e)) Runtime.trap("Failed to convert Candid to JSON. Error: " # e);
            case (#ok(json)) Text.encodeUtf8(json);
        };
    };

    func toCborFromCandid(candid : Candid) : Blob {
        let options = {
            blob_contains_only_values = false;
            renameKeys = [];
            types = null;
            use_icrc_3_value_type = false;
        };
        switch (Serde.CBOR.fromCandid(candid, options)) {
            case (#err(e)) Runtime.trap("Failed to convert Candid to CBOR. Error: " # e);
            case (#ok(cbor)) cbor;
        };
    };

    func toCandidFromCandid(candid : Candid) : Blob {
        switch (Serde.Candid.encode([candid], null)) {
            case (#err(e)) Runtime.trap("Failed to convert Candid to Candid. Error: " # e);
            case (#ok(candid)) candid;
        };
    };

    func toXmlFromCandid(candid : Candid) : Blob {
        let xml = transpileCandidToXml(candid);
        Blob.fromArray(Iter.toArray(Xml.toBytes(xml)));
    };

    func transpileCandidToXml(candid : Candid) : XmlElement.Element {
        {
            name = "root";
            attributes = [];
            children = #open(transpileCandidToElementChildren(candid));
        };
    };

    func transpileCandidToElementChildren(candid : Candid) : [XmlElement.ElementChild] {
        switch (candid) {
            case (#Empty) [];
            case (#Null) [];
            case (#Bool(b)) [#text(if (b) "true" else "false")];
            case (#Float(n)) [#text(Float.toText(n))];
            // Natural number types
            case (#Nat8(n)) [#text(Nat8.toText(n))];
            case (#Nat16(n)) [#text(Nat16.toText(n))];
            case (#Nat32(n)) [#text(Nat32.toText(n))];
            case (#Nat64(n)) [#text(Nat64.toText(n))];
            case (#Nat(n)) [#text(Nat.toText(n))];
            // Integer types
            case (#Int8(n)) [#text(Int8.toText(n))];
            case (#Int16(n)) [#text(Int16.toText(n))];
            case (#Int32(n)) [#text(Int32.toText(n))];
            case (#Int64(n)) [#text(Int64.toText(n))];
            case (#Int(n)) [#text(Int.toText(n))];
            // Binary data
            case (#Blob(blob)) [#text(BaseX.toHex(blob.vals(), { isUpper = true; prefix = #none }))];
            // Text data
            case (#Text(t)) [#text(t)];
            // Array of values
            case (#Array(arr)) {
                let childElements = Buffer.Buffer<XmlElement.ElementChild>(arr.size());

                for (item in arr.vals()) {
                    let itemChildren = transpileCandidToElementChildren(item);
                    childElements.add(#element({ name = "item"; attributes = []; children = #open(itemChildren) }));
                };

                Buffer.toArray(childElements);
            };
            // Record or Map (key-value pairs)
            case (#Record(records) or #Map(records)) {
                let childElements = Buffer.Buffer<XmlElement.ElementChild>(records.size());

                for ((key, val) in records.vals()) {
                    let itemChildren = transpileCandidToElementChildren(val);
                    childElements.add(#element({ name = key; attributes = []; children = #open(itemChildren) }));
                };
                Buffer.toArray(childElements);
            };
            case (#Tuple(tuple)) {
                let childElements = Buffer.Buffer<XmlElement.ElementChild>(tuple.size());

                for (val in tuple.vals()) {
                    let itemChildren = transpileCandidToElementChildren(val);
                    childElements.add(#element({ name = "item"; attributes = []; children = #open(itemChildren) }));
                };
                Buffer.toArray(childElements);
            };
            // Optional values
            case (#Option(option)) transpileCandidToElementChildren(option);
            // Principal IDs
            case (#Principal(p)) [#text(Principal.toText(p))];
            // Variant
            case (#Variant((key, value))) {
                let children = transpileCandidToElementChildren(value);
                [#element({ name = key; attributes = []; children = #open(children) })];
            };
        };
    };

    func toWildcard(
        normalizedType : Text,
        candid : Candid,
        disallowedTypes : [MimeType.RawMimeType],
        toJson : (Candid) -> Blob,
        toCbor : (Candid) -> Blob,
        toCandid : (Candid) -> Blob,
        toXml : (Candid) -> Blob,
    ) : ?HttpContext.CandidNegotiatedContent {
        type OutputMimeType = {
            type_ : Text;
            subType : Text;
        };
        let possibleContentTypes : [OutputMimeType] = switch (normalizedType) {
            case ("*") [
                {
                    type_ = "application";
                    subType = "json";
                },
                {
                    type_ = "application";
                    subType = "cbor";
                },
                {
                    type_ = "application";
                    subType = "candid";
                },
                {
                    type_ = "text";
                    subType = "xml";
                },
            ];
            case ("application") [
                {
                    type_ = "application";
                    subType = "json";
                },
                {
                    type_ = "application";
                    subType = "cbor";
                },
                {
                    type_ = "application";
                    subType = "candid";
                },
            ];
            case ("text") [{
                type_ = "text";
                subType = "xml";
            }];
            case (_) [];
        };
        label f for ({ type_; subType } in possibleContentTypes.vals()) {
            for (disallowedMimeType in disallowedTypes.vals()) {
                // Skip if disallowed
                if (disallowedMimeType.type_ == "*") {
                    continue f;
                };
                if (disallowedMimeType.type_ == type_) {
                    if (disallowedMimeType.subType == "*") {
                        continue f;
                    };
                    if (disallowedMimeType.subType == subType) {
                        continue f;
                    };
                };
            };
            // If allowed, return value
            switch ((type_, subType)) {
                case (("application", "json")) return ?toX(candid, toJson, "application/json");
                case (("application", "cbor")) return ?toX(candid, toCbor, "application/cbor");
                case (("application", "candid")) return ?toX(candid, toCandid, "application/candid");
                case (("text", "xml")) return ?toX(candid, toXml, "text/xml");
                case (("application", "xml")) return ?toX(candid, toXml, "application/xml");
                case (_) Prelude.unreachable();
            };
        };
        return null;
    };
};
