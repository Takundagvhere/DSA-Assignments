// Command-line client for the Library Resource Management API.

import ballerina/http;
import ballerina/io;

configurable string serverUrl = "http://localhost:9090/library";

final http:Client libraryApi = check new (serverUrl);

public function main() returns error? {
    io:println("\n  Connected to " + serverUrl);

    while true {
        printMenu();
        string choice = io:readln("  Choose an option: ");

        error? result = ();

        match choice.trim() {
            "1" => { result = viewAllAssets(); }
            "2" => { result = viewByInstitution(); }
            "3" => { result = viewBySite(); }
            "4" => { result = overdueDashboard(); }
            "5" => { result = loanOrBookAsset(); }
            "6" => { result = scheduleManager(); }
            "7" => { result = viewAssetDetail(); }
            "8" => { result = addAsset(); }
            "9" => { result = listInstitutions(); }
            "0" => {
                io:println("\n  Goodbye.\n");
                return;
            }
            _ => {
                io:println("\n  !! Invalid option. Enter a number from the menu.");
            }
        }

        if result is error {
            io:println("\n  !! " + result.message());
        }
    }
}

function printMenu() {
    io:println("\n===================================================");
    io:println("   LIBRARY & RESOURCE MANAGEMENT SYSTEM");
    io:println("   Ministry of Higher Education, Training & Innovation");
    io:println("===================================================");
    io:println("   1. View all assets            (global view)");
    io:println("   2. View assets by institution (campus view)");
    io:println("   3. View assets by site/campus");
    io:println("   4. Overdue dashboard");
    io:println("   5. Loan an asset / book a room");
    io:println("   6. Schedule manager");
    io:println("   7. View one asset in detail");
    io:println("   8. Add a new asset");
    io:println("   9. List institutions");
    io:println("   0. Exit");
    io:println("===================================================");
}

// ---- 2. GLOBAL VIEW --------------------------------------------------

function viewAllAssets() returns error? {
    Asset[] assets = check libraryApi->get("/assets");
    printAssetTable(assets, "ALL ASSETS ACROSS THE MINISTRY");
}

// ---- 3. CAMPUS VIEW --------------------------------------------------

function viewByInstitution() returns error? {
    io:println("\n  Example: Namibia University of Science and Technology");
    string name = io:readln("  Institution name: ").trim();
    if name == "" {
        return error("Institution name cannot be blank");
    }

    Asset[]|error assets = libraryApi->get("/assets/institution/" + urlEncode(name));
    if assets is error {
        io:println("\n  No assets found for '" + name + "'.");
        return;
    }
    printAssetTable(assets, "ASSETS AT " + name.toUpperAscii());
}

function viewBySite() returns error? {
    io:println("\n  Example: Main Campus - Library");
    string site = io:readln("  Site / campus: ").trim();
    if site == "" {
        return error("Site cannot be blank");
    }

    Asset[]|error assets = libraryApi->get("/assets/site/" + urlEncode(site));
    if assets is error {
        io:println("\n  No assets found at '" + site + "'.");
        return;
    }
    printAssetTable(assets, "ASSETS AT " + site.toUpperAscii());
}

// ---- 4. OVERDUE DASHBOARD --------------------------------------------

function overdueDashboard() returns error? {
    OverdueEntry[] overdue = check libraryApi->get("/assets/overdue");

    io:println("\n--- OVERDUE ITEMS -------------------------------------");
    if overdue.length() == 0 {
        io:println("  Nothing is overdue. All schedules are current.");
        return;
    }

    foreach OverdueEntry entry in overdue {
        io:println("");
        io:println("  " + entry.assetTag + "  |  " + entry.assetName);
        io:println("    Type     : " + entry.scheduleType);
        io:println("    Due      : " + entry.dueDate + "   (OVERDUE)");
        io:println("    Detail   : " + entry.description);
        io:println("    Location : " + entry.site);
        io:println("    Status   : " + entry.currentAssetStatus);
    }
    io:println("\n  " + overdue.length().toString() + " overdue item(s).");
}

// ---- 1. LOANING & BOOKING --------------------------------------------

function loanOrBookAsset() returns error? {
    string tag = io:readln("\n  Asset tag to loan or book: ").trim();
    if tag == "" {
        return error("Asset tag cannot be blank");
    }

    Asset|error asset = libraryApi->get("/assets/" + urlEncode(tag));
    if asset is error {
        io:println("\n  No asset with tag '" + tag + "'.");
        return;
    }

    io:println("\n  Found: " + asset.name + "  (" + asset.status + ")");

    if asset.status != "AVAILABLE" {
        io:println("  !! Cannot proceed - this asset is currently " + asset.status + ".");
        return;
    }

    // Availability check against existing schedules for the date.
    string date = io:readln("  Date required (YYYY-MM-DD): ").trim();
    Availability|error check_ = libraryApi->get(
        "/assets/" + urlEncode(tag) + "/availability?checkDate=" + urlEncode(date));

    if check_ is error {
        io:println("  !! Could not check availability.");
        return;
    }
    if !check_.available {
        io:println("  !! Not available: " + check_.reason);
        return;
    }
    io:println("  Available on " + date + ".");

    // A physical space is OCCUPIED when booked; anything else is LOANED_OUT.
    boolean isSpace = asset?.category == "PHYSICAL_SPACE";
    string newStatus = isSpace ? "OCCUPIED" : "LOANED_OUT";
    string action = isSpace ? "Booking" : "Loan";

    string borrower = io:readln("  Borrower / booked by: ").trim();

    // Two steps: record the booking as a schedule, then change the status.
    Schedule booking = {
        scheduleId: "BK-" + tag + "-" + date,
        'type: "BOOKING",
        dueDate: date,
        description: action + " for " + borrower
    };
    Asset _ = check libraryApi->post("/assets/" + urlEncode(tag) + "/schedules", booking);

    record {|string status;|} statusChange = {status: newStatus};
    Asset updated = check libraryApi->put("/assets/" + urlEncode(tag) + "/status", statusChange);

    io:println("\n  " + action + " recorded.");
    io:println("  " + updated.assetTag + " is now " + updated.status + ".");
}

// ---- 5. SCHEDULE MANAGER ---------------------------------------------

function scheduleManager() returns error? {
    string tag = io:readln("\n  Asset tag: ").trim();

    Asset|error asset = libraryApi->get("/assets/" + urlEncode(tag));
    if asset is error {
        io:println("\n  No asset with tag '" + tag + "'.");
        return;
    }

    Schedule[] existing = asset?.schedules ?: [];
    io:println("\n  Current schedules for " + asset.name + ":");
    if existing.length() == 0 {
        io:println("    (none)");
    } else {
        foreach Schedule s in existing {
            io:println("    " + s.scheduleId + " | " + s.'type + " | due " + s.dueDate +
                    " | " + s.description);
        }
    }

    io:println("\n    a) Add a schedule");
    io:println("    d) Delete a schedule");
    io:println("    c) Cancel");
    string action = io:readln("  Choose: ").trim();

    if action == "a" {
        Schedule newSchedule = {
            scheduleId: io:readln("    Schedule ID (e.g. SCH-950): ").trim(),
            'type: io:readln("    Type (MAINTENANCE or BOOKING): ").trim().toUpperAscii(),
            dueDate: io:readln("    Due date (YYYY-MM-DD): ").trim(),
            description: io:readln("    Description: ").trim()
        };
        Asset _ = check libraryApi->post("/assets/" + urlEncode(tag) + "/schedules", newSchedule);
        io:println("\n  Schedule added.");

    } else if action == "d" {
        string scheduleId = io:readln("    Schedule ID to remove: ").trim();
        Asset _ = check libraryApi->delete(
            "/assets/" + urlEncode(tag) + "/schedules/" + urlEncode(scheduleId));
        io:println("\n  Schedule removed.");

    } else {
        io:println("\n  Cancelled.");
    }
}

// ---- 7. ASSET DETAIL -------------------------------------------------

function viewAssetDetail() returns error? {
    string tag = io:readln("\n  Asset tag: ").trim();

    Asset|error asset = libraryApi->get("/assets/" + urlEncode(tag));
    if asset is error {
        io:println("\n  No asset with tag '" + tag + "'.");
        return;
    }

    io:println("\n--- " + asset.assetTag + " ----------------------------------");
    io:println("  Name        : " + asset.name);
    io:println("  Description : " + asset.description);
    io:println("  Category    : " + (asset?.category ?: "-"));
    io:println("  Institution : " + asset.institution);
    io:println("  Site        : " + asset.site);
    io:println("  Status      : " + asset.status);
    io:println("  Acquired    : " + asset.dateAcquired);

    Component[] comps = asset?.components ?: [];
    io:println("\n  Components (" + comps.length().toString() + "):");
    foreach Component c in comps {
        io:println("    " + c.compId + " | " + c.name + " - " + c.description);
    }

    Schedule[] scheds = asset?.schedules ?: [];
    io:println("\n  Schedules (" + scheds.length().toString() + "):");
    foreach Schedule s in scheds {
        io:println("    " + s.scheduleId + " | " + s.'type + " | due " + s.dueDate);
    }

    WorkOrder[] orders = asset?.workOrders ?: [];
    io:println("\n  Work orders (" + orders.length().toString() + "):");
    foreach WorkOrder w in orders {
        io:println("    " + w.orderId + " | " + w.status + " | " + w.description);
        Task[] tasks = w?.tasks ?: [];
        foreach Task t in tasks {
            string done = (t?.completed ?: false) ? "[x]" : "[ ]";
            io:println("        " + done + " " + t.taskId + " - " + t.description);
        }
    }
}

// ---- 8. ADD AN ASSET -------------------------------------------------

function addAsset() returns error? {
    io:println("\n--- NEW ASSET ----------------------------------------");

    Asset newAsset = {
        assetTag: io:readln("  Asset tag (e.g. NUST-LIB-LAP-099): ").trim(),
        name: io:readln("  Name: ").trim(),
        description: io:readln("  Description: ").trim(),
        category: io:readln("  Category (BOOK / ELECTRONIC_RESOURCE / PHYSICAL_SPACE): ")
                    .trim().toUpperAscii(),
        institution: io:readln("  Institution: ").trim(),
        site: io:readln("  Site / campus: ").trim(),
        status: "AVAILABLE",
        dateAcquired: io:readln("  Date acquired (YYYY-MM-DD): ").trim(),
        components: [],
        schedules: [],
        workOrders: []
    };

    if newAsset.assetTag == "" {
        return error("Asset tag is required");
    }

    Asset|error created = libraryApi->post("/assets", newAsset);
    if created is error {
        io:println("\n  !! Could not create - the tag may already exist.");
        return;
    }
    io:println("\n  Created " + created.assetTag + ".");
}

// ---- 9. INSTITUTIONS -------------------------------------------------

function listInstitutions() returns error? {
    Institution[] institutions = check libraryApi->get("/institutions");

    io:println("\n--- REGISTERED INSTITUTIONS ---------------------------");
    foreach Institution inst in institutions {
        io:println("\n  " + inst.code + " - " + inst.name);
        string[] sites = inst?.sites ?: [];
        foreach string s in sites {
            io:println("      " + s);
        }
    }
    io:println("\n  " + institutions.length().toString() + " institution(s).");
}

// ---- Helpers ---------------------------------------------------------

function printAssetTable(Asset[] assets, string heading) {
    io:println("\n--- " + heading + " ---");
    if assets.length() == 0 {
        io:println("  No assets found.");
        return;
    }
    io:println("");
    foreach Asset a in assets {
        io:println("  " + pad(a.assetTag, 20) + pad(a.name, 34) +
                pad(a.status, 18) + a.site);
    }
    io:println("\n  " + assets.length().toString() + " asset(s).");
}

function pad(string text, int width) returns string {
    string result = text;
    while result.length() < width {
        result = result + " ";
    }
    return result + " ";
}

// Percent-encodes spaces so institution and site names work in a path.
function urlEncode(string input) returns string {
    string result = "";
    int i = 0;
    while i < input.length() {
        string c = input.substring(i, i + 1);
        result = result + (c == " " ? "%20" : c);
        i += 1;
    }
    return result;
}
