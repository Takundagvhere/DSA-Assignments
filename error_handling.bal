// Maps internal error codes to HTTP status codes so every endpoint fails the same way.

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
    "DUPLICATE_WORKORDER": "BAD_REQUEST",
    "DUPLICATE_TASK": "BAD_REQUEST",
    "DUPLICATE_SCHEDULE": "BAD_REQUEST",
    "INVALID_STATUS": "BAD_REQUEST",
    "VALIDATION_ERROR": "BAD_REQUEST",
    "MISSING_FIELD": "BAD_REQUEST",

    "WORKORDER_ALREADY_CLOSED": "CONFLICT",
    "ASSET_ALREADY_EXISTS": "CONFLICT",
    "INSTITUTION_ALREADY_EXISTS": "CONFLICT"
};

function buildApiError(error err) returns ApiError {
    string code = "INTERNAL_ERROR";
    var detail = err.detail();
    var rawCode = detail["errorCode"];
    if rawCode is string {
        code = rawCode;
    }
    return {
        errorCode: code,
        message: err.message(),
        timestamp: time:utcToString(time:utcNow())
    };
}

// Every resource function returns this union on the error path.
public function toErrorResponse(error err)
        returns http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {

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

// For bad input that never reaches the logic layer.
public function badRequest(string message, string errorCode = "VALIDATION_ERROR")
        returns http:BadRequest {
    return {
        body: {
            errorCode: errorCode,
            message: message,
            timestamp: time:utcToString(time:utcNow())
        }
    };
}
