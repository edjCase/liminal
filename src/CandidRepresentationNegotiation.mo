import App "App";
import Xml "mo:xml/Xml";
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
import BaseX "mo:base-x-encoder";

module {

    public type Candid = App.Candid;
    public type ContentPreference = App.ContentPreference;

    public func defaultNegotiator(
        candid : Candid,
        contentPreference : ContentPreference,
    ) : ?HttpContext.CandidNegotiatedContent {

        label f for ({ type_; subType; parameters } in contentPreference.requestedTypes.vals()) {
            let normalizedType = type_ |> Text.trim(_, #char(' ')) |> Text.toLowercase(_);
            let normalizedSubType = subType |> Text.trim(_, #char(' ')) |> Text.toLowercase(_);
            let ?value : ?HttpContext.CandidNegotiatedContent = switch ((normalizedType, normalizedSubType)) {
                case ((normalizedType, "*")) toWildcard(normalizedType, candid, contentPreference.disallowedTypes);
                case (("application", "json")) ?toJson(candid);
                case (("application", "cbor")) ?toCbor(candid);
                case (("application", "candid")) ?toCandid(candid);
                case (("text", "xml") or ("application", "xml")) ?toXml(candid);
                case (_) continue f; // Not supported
            } else continue f;
            return ?value;
        };
        return null; // No supported content type found
    };

    func toJson(candid : Candid) : HttpContext.CandidNegotiatedContent {
        let jsonText = switch (Serde.JSON.fromCandid(candid)) {
            case (#err(e)) Runtime.trap("Failed to convert Candid to JSON. Error: " # e);
            case (#ok(json)) json;
        };
        return {
            body = Text.encodeUtf8(jsonText);
            contentType = "application/json";
        };
    };

    func toCbor(candid : Candid) : HttpContext.CandidNegotiatedContent {
        let options = {
            blob_contains_only_values = false;
            renameKeys = [];
            types = null;
            use_icrc_3_value_type = false;
        };
        let cborBlob = switch (Serde.CBOR.fromCandid(candid, options)) {
            case (#err(e)) Runtime.trap("Failed to convert Candid to CBOR. Error: " # e);
            case (#ok(cbor)) cbor;
        };
        return {
            body = cborBlob;
            contentType = "application/cbor";
        };
    };

    func toCandid(candid : Candid) : HttpContext.CandidNegotiatedContent {
        let candidBlob = switch (Serde.Candid.encode([candid], null)) {
            case (#err(e)) Runtime.trap("Failed to convert Candid to Candid. Error: " # e);
            case (#ok(candid)) candid;
        };
        return {
            body = candidBlob;
            contentType = "application/candid";
        };
    };

    func toXml(candid : Candid) : HttpContext.CandidNegotiatedContent {
        let xml = transpileCandidToXml(candid);
        {
            body = Blob.fromArray(Iter.toArray(Xml.serializeToBytes(xml)));
            contentType = "text/xml";
        };
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

    func toWildcard(normalizedType : Text, candid : Candid, disallowedTypes : [MimeType.RawMimeType]) : ?HttpContext.CandidNegotiatedContent {
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
                case (("application", "json")) return ?toJson(candid);
                case (("application", "cbor")) return ?toCbor(candid);
                case (("application", "candid")) return ?toCandid(candid);
                case (("text", "xml")) return ?toXml(candid);
                case (_) Prelude.nyi();
            };
        };
        return null;
    };
};
