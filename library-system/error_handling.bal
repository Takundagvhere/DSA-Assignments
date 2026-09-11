// Centralized error handling for the library-system API.
// Logic functions return `error("message", errorCode = "SOME_CODE")`;
// resource functions call toErrorResponse(err) to get a consistent
// HTTP response shape across all endpoints.

import ballerina/http;
import ballerina/time;

public type ApiError record {|
    string errorCode;
    string message;
    string timestamp;
|};

// Maps internal error codes to HTTP status categories.
final map<string> ERROR_CODE_TO_CATEGORY = {
    "ASSET_NOT_FOUND": "NOT_FOUND",
    "COMPONENT_NOT_FOUND": "NOT_FOUND",
    "WORKORDER_NOT_FOUND": "NOT_FOUND",
    "TASK_NOT_FOUND": "NOT_FOUND",
    "SCHEDULE_NOT_FOUND": "NOT_FOUND",
    "INSTITUTION_NOT_FOUND": "NOT_FOUND",

    "DUPLICATE_COMPONENT": "BAD_REQUEST",
    "DUPLICATE_ASSET_TAG": "BAD_REQUEST",
    "INVALID_STATUS": "BAD_REQUEST",
    "VALIDATION_ERROR": "BAD_REQUEST",
    "MISSING_FIELD": "BAD_REQUEST",

    "WORKORDER_ALREADY_CLOSED": "CONFLICT",
    "ASSET_ALREADY_EXISTS": "CONFLICT"
};

isolated function buildApiError(error err) returns ApiError {
    string code = "INTERNAL_ERROR";
    anydata detail = err.detail();
    if detail is map<anydata> && detail.hasKey("errorCode") {
        anydata rawCode = detail["errorCode"];
        if rawCode is string {
            code = rawCode;
        }
    }
    return {
        errorCode: code,
        message: err.message(),
        timestamp: time:utcToString(time:utcNow())
    };
}

// Every resource function returns this union type on the error path.
public isolated function toErrorResponse(error err) returns http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {
    ApiError apiErr = buildApiError(err);
    string category = ERROR_CODE_TO_CATEGORY[apiErr.errorCode] ?: "INTERNAL_ERROR";

    match category {
        "NOT_FOUND" => {
            return <http:NotFound>{body: apiErr};
        }
        "BAD_REQUEST" => {
            return <http:BadRequest>{body: apiErr};
        }
        "CONFLICT" => {
            return <http:Conflict>{body: apiErr};
        }
        _ => {
            return <http:InternalServerError>{body: apiErr};
        }
    }
}

// Convenience helper for bad-input cases that don't come from the
// logic layer (e.g. malformed path params).
public isolated function badRequest(string message, string errorCode = "VALIDATION_ERROR") returns http:BadRequest {
    return {
        body: {
            errorCode: errorCode,
            message: message,
            timestamp: time:utcToString(time:utcNow())
        }
    };
}

// Catch-all wrapper that guarantees a clean 500 JSON body instead of a
// raw panic trace, for any logic function of shape () -> Asset|error.
public isolated function safeCall(isolated function () returns Asset|error fn)
        returns Asset|http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {
    Asset|error result = fn();
    if result is error {
        return toErrorResponse(result);
    }
    return result;
}
