import ballerina/http;
import ballerina/time;
import ballerina/url;

// The server currently runs four listeners, one per service file: CRUD on
// 8081, query on 8082, scheduling on 8080, work orders on 8083. These are
// configurable rather than hard-coded so that when the team merges everything
// onto a single listener, this client needs a Config.toml and no code change.
// See Config.toml.example.
configurable string crudUrl = "http://localhost:8081";
configurable string queryUrl = "http://localhost:8082";
configurable string schedulingUrl = "http://localhost:8080";
configurable string workOrderUrl = "http://localhost:8083";

final http:Client crud = check new (crudUrl, timeout = 15);
final http:Client query = check new (queryUrl, timeout = 15);
final http:Client scheduling = check new (schedulingUrl, timeout = 15);
final http:Client workOrders = check new (workOrderUrl, timeout = 15);

// Path segments get percent encoded everywhere. Institution names are the
// primary key on the server, so "Namibia University of Science and Technology"
// travels in the path spaces and all.
function seg(string value) returns string|error {
    return url:encode(value, "UTF-8");
}

// ---- reads -----------------------------------------------------------------

function fetchAllAssets() returns Asset[]|error {
    return query->get("/assets");
}

function fetchByInstitution(string institution) returns Asset[]|error {
    return query->get("/assets/institution/" + check seg(institution));
}

function fetchBySite(string site) returns Asset[]|error {
    return query->get("/assets/site/" + check seg(site));
}

function fetchAsset(string tag) returns Asset|error {
    return crud->get("/assets/" + check seg(tag));
}

function fetchInstitutions() returns Institution[]|error {
    return query->get("/institutions");
}

function fetchOverdue() returns OverdueEntry[]|error {
    return scheduling->get("/assets/overdue");
}

function fetchMaintenance(string tag) returns MaintenanceStatus|error {
    return scheduling->get("/assets/" + check seg(tag) + "/maintenance");
}

function checkAvailability(string tag, string startDate, string endDate) returns Availability|error {
    string path = "/assets/" + check seg(tag) + "/schedules/availability"
        + "?startDate=" + check seg(startDate) + "&endDate=" + check seg(endDate);
    return scheduling->get(path);
}

// ---- writes ----------------------------------------------------------------

function createAsset(Asset asset) returns Asset|error {
    return crud->post("/assets", asset);
}

function replaceAsset(string tag, Asset asset) returns Asset|error {
    return crud->put("/assets/" + check seg(tag), asset);
}

function removeAsset(string tag) returns json|error {
    return crud->delete("/assets/" + check seg(tag));
}

function createInstitution(Institution institution) returns Institution|error {
    return query->post("/institutions", institution);
}

function deleteInstitution(string name) returns json|error {
    return query->delete("/institutions/" + check seg(name));
}

function addSchedule(string tag, Schedule schedule) returns Asset|error {
    return scheduling->post("/assets/" + check seg(tag) + "/schedules", schedule);
}

function removeSchedule(string tag, string scheduleId) returns json|error {
    return scheduling->delete("/assets/" + check seg(tag) + "/schedules/" + check seg(scheduleId));
}

function addComponent(string tag, Component component) returns Asset|error {
    return workOrders->post("/assets/" + check seg(tag) + "/components", component);
}

function openWorkOrder(string tag, WorkOrder wo) returns Asset|error {
    return workOrders->post("/assets/" + check seg(tag) + "/workorders", wo);
}

// ---- loaning and booking ---------------------------------------------------
//
// There is no loan endpoint on the server. The brief and the work allocation
// both ask this client for a loan/book view, so it is composed from three
// calls that do exist:
//
//   1. ask the scheduling service whether the dates are free
//   2. write a BOOKING schedule carrying startDate and endDate
//   3. put the asset back with its status changed
//
// Step 1 is advisory only. Nothing stops another client slipping in between
// steps 1 and 2, because the server offers no atomic reserve. That is a real
// limitation of the current API, not of this client, and it is written up in
// INTEGRATION-NOTES.md for whoever owns the scheduling service.

type LoanOutcome record {|
    boolean issued;
    string message;
    string scheduleId = "";
|};

function loanAsset(string tag, string borrower, string fromDate, string toDate) returns LoanOutcome|error {
    if toDate <= fromDate {
        return {issued: false, message: "the return date has to be after the collection date"};
    }

    Availability free = check checkAvailability(tag, fromDate, toDate);
    if !free.available {
        return {issued: false, message: string `${tag} is already held over ${fromDate} to ${toDate}`};
    }

    Asset current = check fetchAsset(tag);
    if current.status == "UNDER_MAINTENANCE" || current.status == "DISPOSED" {
        return {issued: false, message: string `${tag} is ${current.status} and cannot go out`};
    }

    string bookingId = nextBookingId();
    Schedule hold = {
        scheduleId: bookingId,
        'type: "BOOKING",
        dueDate: toDate,
        description: "Held for " + borrower,
        startDate: fromDate,
        endDate: toDate
    };
    Asset _ = check addSchedule(tag, hold);

    Asset updated = current.clone();
    updated.status = isSpace(tag) ? "OCCUPIED" : "LOANED_OUT";
    Asset _ = check replaceAsset(tag, updated);

    return {issued: true, message: string `${tag} issued to ${borrower} until ${toDate}`, scheduleId: bookingId};
}

function checkIn(string tag, string scheduleId) returns LoanOutcome|error {
    json _ = check removeSchedule(tag, scheduleId);

    Asset current = check fetchAsset(tag);
    Asset updated = current.clone();
    updated.status = "AVAILABLE";
    Asset _ = check replaceAsset(tag, updated);

    return {issued: false, message: tag + " is back on the shelf", scheduleId: scheduleId};
}

// Spaces read OCCUPIED, everything else reads LOANED_OUT. The asset tag is the
// only thing carrying the resource type, since the server record has no
// category field. A resourceType field on Asset would make this honest.
function isSpace(string tag) returns boolean {
    string upper = tag.toUpperAscii();
    return upper.includes("ROOM") || upper.includes("LAB") || upper.includes("HALL");
}

// The server does not mint schedule ids, so the client has to. Epoch seconds
// keep them unique within a run and readable on screen.
function nextBookingId() returns string {
    [int, decimal] now = time:utcNow();
    return "BK-" + (now[0] % 1000000).toString();
}

// ---- errors ----------------------------------------------------------------

// The services answer failures with {"message": "..."} and a 4xx. Without
// this the user would see "error in HTTP client" and learn nothing.
function explain(error e) returns string {
    if e is http:ClientRequestError || e is http:RemoteServerError {
        var detail = e.detail();
        anydata body = detail.body;
        if body is map<anydata> {
            anydata message = body["message"];
            if message is string {
                return string `${detail.statusCode}: ${message}`;
            }
        }
        return string `HTTP ${detail.statusCode}`;
    }
    if e is http:ClientError {
        return "cannot reach the service: " + e.message();
    }
    return e.message();
}
