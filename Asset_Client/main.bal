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
            "1"  => { result = viewAllAssets(); }
            "2"  => { result = viewByInstitution(); }
            "3"  => { result = viewBySite(); }
            "4"  => { result = overdueDashboard(); }
            "5"  => { result = loanOrBookAsset(); }
            "6"  => { result = returnLoanedAsset(); }
            "7"  => { result = scheduleManager(); }
            "8"  => { result = viewAssetDetail(); }
            "9"  => { result = addAsset(); }
            "10"  => { result = listInstitutions(); }
            "11" => { result = workOrderManager(); }
            "12" => { result = viewAllWorkOrders(); }
            "0"  => {
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
    io:println("   6. Return a loaned asset");
    io:println("   7. Schedule manager");
    io:println("   8. View one asset in detail");
    io:println("   9. Add a new asset");
    io:println("   10. List institutions");
    io:println("   11. Work Order Manager");
    io:println("   12. View all work orders       (global view)");
    io:println("   0. Exit");
    io:println("===================================================");
}

// ---- 1. GLOBAL VIEW --------------------------------------------------

function viewAllAssets() returns error? {
    Asset[] assets = check libraryApi->get("/assets");
    printAssetTable(assets, "ALL ASSETS ACROSS THE MINISTRY");
}

// ---- 2. CAMPUS VIEW --------------------------------------------------

function viewByInstitution() returns error? {
    io:println("\n  Shortcuts: NUST, UNAM, IUM");
    io:println("  Or type the full institution name.");
    string input = io:readln("  Institution name or code: ").trim();
    if input == "" {
        return error("Institution name cannot be blank");
    }

    string name = resolveInstitution(input);
    io:println("  Looking for: " + name);

    Asset[]|error assets = libraryApi->get("/assets/institution/" + urlEncode(name));
    if assets is error {
        io:println("\n  No assets found for '" + name + "'.");
        return;
    }
    printAssetTable(assets, "ASSETS AT " + name.toUpperAscii());
}
function viewBySite() returns error? {
    io:println("\n  Shortcuts: NUST-LIB, NUST-IL");
    io:println("  Or type the full site name.");
    string input = io:readln("  Site / campus: ").trim();
    if input == "" {
        return error("Site cannot be blank");
    }

    string site = resolveInstitution(input);
    io:println("  Looking for: " + site);

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

// ---- 5. LOANING & BOOKING --------------------------------------------

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

    boolean isSpace = asset?.category == "PHYSICAL_SPACE";
    string newStatus = isSpace ? "OCCUPIED" : "LOANED_OUT";
    string action = isSpace ? "Booking" : "Loan";

    string borrower = io:readln("  Borrower / booked by: ").trim();

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
// ---- 6. RETURN A LOANED ASSET ---------------------------------------

// ---- 6. RETURN A LOANED ASSET ----------------------------------------

function returnLoanedAsset() returns error? {
    io:println("\n--- RETURN LOANED ASSET -------------------------------");

    string tag = io:readln("  Asset tag to return: ").trim();
    if tag == "" {
        return error("Asset tag cannot be blank");
    }

    Asset|error asset = libraryApi->get("/assets/" + urlEncode(tag));
    if asset is error {
        io:println("\n  No asset with tag '" + tag + "'.");
        return;
    }

    if asset.status != "LOANED_OUT" && asset.status != "OCCUPIED" {
        io:println("\n  !! This asset is not on loan.");
        io:println("     Current status: " + asset.status);
        return;
    }

    io:println("\n  Found: " + asset.name);
    io:println("  Current status: " + asset.status);

    // Remove schedules only if there are any
    Schedule[] schedules = asset?.schedules ?: [];
    if schedules.length() > 0 {
        io:println("\n  Schedules on this asset:");
        foreach Schedule s in schedules {
            io:println("    " + s.scheduleId + " | " + s.'type + " | due " + s.dueDate +
                    " | " + s.description);
        }

        io:println("\n  Enter a schedule ID to remove it (or press Enter to keep them).");
        string scheduleId = io:readln("  Schedule ID: ").trim();

        if scheduleId != "" {
            Asset|error removeResult = libraryApi->delete(
                "/assets/" + urlEncode(tag) + "/schedules/" + urlEncode(scheduleId));
            if removeResult is error {
                io:println("\n  !! Could not remove schedule: " + removeResult.message());
            } else {
                io:println("\n  Schedule " + scheduleId + " removed.");
            }
        }
    } else {
        io:println("\n  No schedules found — nothing to remove.");
    }

    // ALWAYS reset status, even if there were no schedules
    record {|string status;|} statusChange = {status: "AVAILABLE"};
    Asset updated = check libraryApi->put(
        "/assets/" + urlEncode(tag) + "/status", statusChange);

    io:println("\n  ✅ " + updated.assetTag + " is now " + updated.status + ".");
}
// ---- 7. SCHEDULE MANAGER ---------------------------------------------

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

        // Reset the asset status back to AVAILABLE
        record {|string status;|} statusChange = {status: "AVAILABLE"};
        Asset updated = check libraryApi->put(
            "/assets/" + urlEncode(tag) + "/status", statusChange);
        io:println("  Asset status reset to: " + updated.status);

    } else {
        io:println("\n  Cancelled.");
    }
}   
// ---- 8. ASSET DETAIL -------------------------------------------------

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
            string done = w.status == "CLOSED" ? "[x]" : "[ ]";
            io:println("        " + done + "  Task ID: " + t.taskId + "  -  " + t.description);
        }
    }
}

// ---- 9. ADD AN ASSET -------------------------------------------------

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

// ---- 10. INSTITUTIONS -------------------------------------------------

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

// ---- 11. WORK ORDER MANAGER ------------------------------------------

function workOrderManager() returns error? {
    io:println("\n--- WORK ORDER MANAGER -------------------------------");

    string tag = io:readln("  Asset tag (e.g. NUST-LIB-LAP-014): ").trim();
    if tag == "" {
        return error("Asset tag cannot be blank");
    }

    Asset|error asset = libraryApi->get("/assets/" + urlEncode(tag));
    if asset is error {
        io:println("\n  No asset with tag '" + tag + "'.");
        return;
    }

    io:println("\n  Found: " + asset.name + "  (status: " + asset.status + ")");

    WorkOrder[] existing = asset?.workOrders ?: [];
    io:println("\n  Existing work orders (" + existing.length().toString() + "):");
    if existing.length() == 0 {
        io:println("    (none)");
    } else {
        foreach WorkOrder w in existing {
            io:println("    " + w.orderId + " | " + w.status + " | " + w.description);
            Task[] tasks = w?.tasks ?: [];
            foreach Task t in tasks {
                string done = w.status == "CLOSED" ? "[x]" : "[ ]";
                io:println("        " + done + "  Task ID: " + t.taskId + "  -  " + t.description);
            }
        }
    }

    io:println("\n    a) Open a new work order");
    io:println("    b) Update a work order status");
    io:println("    c) Add a task to a work order");
    io:println("    d) Remove a task from a work order");
    io:println("    e) Close a work order");
    io:println("    x) Cancel");
    string action = io:readln("  Choose: ").trim().toLowerAscii();

    match action {
        "a" => { return openNewWorkOrder(tag); }
        "b" => { return updateExistingWorkOrder(tag, existing); }
        "c" => { return addTaskToWorkOrder(tag, existing); }
        "d" => { return removeTaskFromWorkOrder(tag, existing); }
        "e" => { return closeExistingWorkOrder(tag, existing); }
        _ => {
            io:println("\n  Cancelled.");
            return;
        }
    }
}

function openNewWorkOrder(string assetTag) returns error? {
    io:println("\n  --- NEW WORK ORDER ---");

    WorkOrder wo = {
        orderId: io:readln("    Order ID (e.g. WO-555): ").trim(),
        status: "OPEN",
        description: io:readln("    Description: ").trim(),
        tasks: []
    };

    if wo.orderId == "" {
        return error("Order ID is required");
    }

    Asset|error result = libraryApi->post(
        "/assets/" + urlEncode(assetTag) + "/workorders", wo);

    if result is error {
        io:println("\n  !! Could not open work order: " + result.message());
        return;
    }
    io:println("\n  Work order " + wo.orderId + " opened.");
}

function updateExistingWorkOrder(string assetTag, WorkOrder[] orders) returns error? {
    if orders.length() == 0 {
        return error("No work orders exist for this asset.");
    }

    string orderId = io:readln("\n    Order ID to update: ").trim();

    io:println("    New status:");
    io:println("      1. OPEN");
    io:println("      2. IN_PROGRESS");
    io:println("      3. CLOSED");
    string st = io:readln("    Choose (1-3): ").trim();

    string newStatus = st == "1" ? "OPEN" :
                       st == "2" ? "IN_PROGRESS" :
                       st == "3" ? "CLOSED" : "";

    if newStatus == "" {
        return error("Invalid status choice");
    }

    json payload = {
        "status": newStatus,
        "description": io:readln("    New description (or blank): ").trim()
    };

    Asset|error result = libraryApi->put(
        "/assets/" + urlEncode(assetTag) + "/workorders/" + urlEncode(orderId),
        payload);

    if result is error {
        io:println("\n  !! Could not update: " + result.message());
        return;
    }
    io:println("\n  Work order " + orderId + " updated to " + newStatus + ".");
}

function addTaskToWorkOrder(string assetTag, WorkOrder[] orders) returns error? {
    if orders.length() == 0 {
        return error("No work orders exist for this asset.");
    }

    string orderId = io:readln("\n    Work order ID to add a task to: ").trim();

    Task task = {
        taskId: io:readln("    Task ID (e.g. T2): ").trim(),
        description: io:readln("    Task description: ").trim(),
        completed: false
    };

    if task.taskId == "" {
        return error("Task ID is required");
    }

    Asset|error result = libraryApi->post(
        "/assets/" + urlEncode(assetTag) + "/workorders/" + urlEncode(orderId) + "/tasks",
        task);

    if result is error {
        io:println("\n  !! Could not add task: " + result.message());
        return;
    }
    io:println("\n  Task " + task.taskId + " added to work order " + orderId + ".");
}

function removeTaskFromWorkOrder(string assetTag, WorkOrder[] orders) returns error? {
    if orders.length() == 0 {
        return error("No work orders exist for this asset.");
    }

    string orderId = io:readln("\n    Work order ID: ").trim();
    string taskId  = io:readln("    Task ID to remove: ").trim();

    Asset|error result = libraryApi->delete(
        "/assets/" + urlEncode(assetTag) +
        "/workorders/" + urlEncode(orderId) +
        "/tasks/" + urlEncode(taskId));

    if result is error {
        io:println("\n  !! Could not remove task: " + result.message());
        return;
    }
    io:println("\n  Task " + taskId + " removed.");
}

function closeExistingWorkOrder(string assetTag, WorkOrder[] orders) returns error? {
    if orders.length() == 0 {
        return error("No work orders exist for this asset.");
    }

    string orderId = io:readln("\n    Work order ID to close: ").trim();

    json payload = {"status": "CLOSED"};

    Asset|error result = libraryApi->put(
        "/assets/" + urlEncode(assetTag) + "/workorders/" + urlEncode(orderId),
        payload);

    if result is error {
        io:println("\n  !! Could not close: " + result.message());
        return;
    }
    io:println("\n  Work order " + orderId + " closed.");
}

// ---- 12. VIEW ALL WORK ORDERS (GLOBAL VIEW) --------------------------

function viewAllWorkOrders() returns error? {
    Asset[] assets = check libraryApi->get("/assets");

    io:println("\n--- ALL WORK ORDERS ACROSS THE MINISTRY ----------------");

    int totalWorkOrders = 0;
    int openCount = 0;
    int inProgressCount = 0;
    int closedCount = 0;

    foreach Asset a in assets {
        WorkOrder[] orders = a?.workOrders ?: [];
        if orders.length() == 0 {
            continue;
        }

        io:println("\n  Asset: " + a.assetTag + "  |  " + a.name);
        io:println("  Site : " + a.site);

        foreach WorkOrder w in orders {
            totalWorkOrders += 1;

            if w.status == "OPEN" {
                openCount += 1;
            } else if w.status == "IN_PROGRESS" {
                inProgressCount += 1;
            } else if w.status == "CLOSED" {
                closedCount += 1;
            }

            io:println("    " + w.orderId + " | " + w.status + " | " + w.description);

            Task[] tasks = w?.tasks ?: [];
            foreach Task t in tasks {
                string done = w.status == "CLOSED" ? "[x]" : "[ ]";
                io:println("        " + done + "  Task ID: " + t.taskId + "  -  " + t.description);
            }
        }
    }

    io:println("\n-------------------------------------------------------");
    if totalWorkOrders == 0 {
        io:println("  No work orders found across any asset.");
    } else {
        io:println("  Total work orders : " + totalWorkOrders.toString());
        io:println("    OPEN            : " + openCount.toString());
        io:println("    IN_PROGRESS     : " + inProgressCount.toString());
        io:println("    CLOSED          : " + closedCount.toString());
    }
    io:println("-------------------------------------------------------");
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
// Translate short institution codes to full names.
// If the input isn't a known shortcut, it's returned unchanged.
function resolveInstitution(string input) returns string {
    string trimmed = input.trim().toUpperAscii();

    match trimmed {
        "NUST" => { return "Namibia University of Science and Technology"; }
        "UNAM" => { return "University of Namibia"; }
        "IUM"  => { return "International University of Management"; }
        "NUST-LIB" => { return "Main Campus - Library"; }
        "NUST-IL"  => { return "Main Campus - Innovation Lab"; }
        _ => { return input.trim(); }
    }
}
