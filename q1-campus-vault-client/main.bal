import ballerina/io;

// CampusVault command line client.
//
//   bal run              the menu
//   bal run -- demo      scripted walkthrough, no typing
//
// The five views the work allocation asks for are options 1 to 5. Options 6
// and 7 exist because a marker always asks to see one record in full and to
// see what happens when the request is wrong.
public function main(string... args) returns error? {
    if args.length() > 0 && args[0] == "demo" {
        return runDemo();
    }
    check menu();
}

function menu() returns error? {
    io:println("CampusVault - Distributed Library and Resource Management");
    io:println("query " + queryUrl + " | crud " + crudUrl);
    io:println("scheduling " + schedulingUrl + " | work orders " + workOrderUrl);

    Asset[]|error reachable = fetchAllAssets();
    if reachable is error {
        io:println("");
        io:println("Cannot reach the server (" + explain(reachable) + ").");
        io:println("Start it with 'bal run' from the Campus_Vault package first.");
        return;
    }

    while true {
        io:println("");
        io:println("  1  loan or book a resource      5  schedule manager");
        io:println("  2  global view                  6  look up one asset");
        io:println("  3  campus view                  7  register an asset");
        io:println("  4  overdue dashboard            8  institutions");
        io:println("  0  quit");

        match ask("choice") {
            "1" => {
                loanView();
            }
            "2" => {
                globalView();
            }
            "3" => {
                campusView();
            }
            "4" => {
                overdueView();
            }
            "5" => {
                scheduleView();
            }
            "6" => {
                detailView();
            }
            "7" => {
                registerView();
            }
            "8" => {
                institutionView();
            }
            "0" => {
                io:println("bye");
                return;
            }
            _ => {
                io:println("  no such option");
            }
        }
    }
}

// ---- 1. loan and book ------------------------------------------------------

function loanView() {
    io:println("  a) issue or book    b) check back in    c) check dates only");
    match ask("pick") {
        "a" => {
            string tag = ask("asset tag");
            string borrower = ask("borrower (student or staff number and name)");
            string fromDate = ask("from (yyyy-MM-dd)");
            string toDate = ask("to (yyyy-MM-dd)");

            LoanOutcome|error outcome = loanAsset(tag, borrower, fromDate, toDate);
            if outcome is error {
                io:println("  " + explain(outcome));
                return;
            }
            io:println("  " + outcome.message);
            if outcome.issued {
                io:println("  hold reference " + outcome.scheduleId + " (needed to check it back in)");
            }
        }
        "b" => {
            string tag = ask("asset tag");
            LoanOutcome|error outcome = checkIn(tag, ask("hold reference, e.g. BK-123456"));
            io:println(outcome is error ? "  " + explain(outcome) : "  " + outcome.message);
        }
        "c" => {
            string tag = ask("asset tag");
            Availability|error free = checkAvailability(tag, ask("from (yyyy-MM-dd)"), ask("to (yyyy-MM-dd)"));
            if free is error {
                io:println("  " + explain(free));
                return;
            }
            io:println(free.available ? "  free over those dates" : "  already held over those dates");
        }
        _ => {
            io:println("  no such option");
        }
    }
}

// ---- 2. global view --------------------------------------------------------

function globalView() {
    Asset[]|error assets = fetchAllAssets();
    if assets is error {
        io:println("  " + explain(assets));
        return;
    }
    printAssets(assets);
}

// ---- 3. campus view --------------------------------------------------------

function campusView() {
    Institution[]|error known = fetchInstitutions();
    if known is Institution[] && known.length() > 0 {
        io:println("  registered institutions:");
        printInstitutions(known);
    }

    io:println("  a) by institution    b) by site");
    Asset[]|error assets;
    if ask("pick") == "b" {
        assets = fetchBySite(ask("site, exactly as it is spelled above"));
    } else {
        assets = fetchByInstitution(ask("institution name, in full"));
    }

    if assets is error {
        io:println("  " + explain(assets));
        return;
    }
    printAssets(assets);
}

// ---- 4. overdue dashboard --------------------------------------------------

function overdueView() {
    OverdueEntry[]|error entries = fetchOverdue();
    if entries is error {
        io:println("  " + explain(entries));
        return;
    }
    printOverdue(entries);

    string tag = askOptional("asset tag for a full maintenance status");
    if tag == "" {
        return;
    }
    MaintenanceStatus|error status = fetchMaintenance(tag);
    if status is error {
        io:println("  " + explain(status));
        return;
    }
    io:println("  " + status.assetTag + " is " + status.status
        + (status.hasOverdueMaintenance ? ", with maintenance overdue" : ", maintenance up to date"));
    foreach Schedule s in status.maintenanceSchedules {
        io:println("      " + pad(s.scheduleId, 12) + "due " + s.dueDate + "  " + s.description);
    }
}

// ---- 5. schedule manager ---------------------------------------------------

function scheduleView() {
    string tag = ask("asset tag");
    io:println("  a) add a servicing schedule    b) remove a schedule    c) list them");
    match ask("pick") {
        "a" => {
            Schedule draft = {
                scheduleId: ask("schedule id, e.g. SCH-903"),
                'type: ask("type (MAINTENANCE / SERVICE)").toUpperAscii(),
                dueDate: ask("due date (yyyy-MM-dd)"),
                description: ask("description")
            };
            Asset|error result = addSchedule(tag, draft);
            if result is error {
                io:println("  " + explain(result));
                return;
            }
            printAsset(result);
        }
        "b" => {
            json|error result = removeSchedule(tag, ask("schedule id"));
            io:println(result is error ? "  " + explain(result) : "  removed");
        }
        "c" => {
            Asset|error asset = fetchAsset(tag);
            if asset is error {
                io:println("  " + explain(asset));
                return;
            }
            Schedule[] schedules = asset.schedules ?: [];
            if schedules.length() == 0 {
                io:println("  (no schedules on this asset)");
                return;
            }
            foreach Schedule s in schedules {
                io:println("      " + pad(s.scheduleId, 12) + pad(s.'type, 14) + describeWindow(s));
            }
        }
        _ => {
            io:println("  no such option");
        }
    }
}

// ---- 6, 7, 8 ---------------------------------------------------------------

function detailView() {
    Asset|error asset = fetchAsset(ask("asset tag"));
    if asset is error {
        io:println("  " + explain(asset));
        return;
    }
    printAsset(asset);
}

function registerView() {
    Asset draft = {
        assetTag: ask("asset tag, e.g. NUST-LIB-LAP-021"),
        name: ask("name"),
        description: askOptional("description"),
        institution: ask("institution name, in full"),
        site: ask("site"),
        status: "AVAILABLE",
        dateAcquired: ask("date acquired (yyyy-MM-dd)"),
        components: [],
        schedules: [],
        workOrders: []
    };
    Asset|error created = createAsset(draft);
    io:println(created is error ? "  rejected - " + explain(created) : "  registered " + created.assetTag);
}

function institutionView() {
    io:println("  a) list    b) add    c) remove");
    match ask("pick") {
        "a" => {
            Institution[]|error list = fetchInstitutions();
            if list is error {
                io:println("  " + explain(list));
                return;
            }
            printInstitutions(list);
        }
        "b" => {
            Institution draft = {name: ask("full institution name"), sites: []};
            string sites = askOptional("sites, comma separated");
            if sites != "" {
                string[] parts = [];
                foreach string part in re `,`.split(sites) {
                    parts.push(part.trim());
                }
                draft.sites = parts;
            }
            Institution|error added = createInstitution(draft);
            io:println(added is error ? "  rejected - " + explain(added) : "  added " + added.name);
        }
        "c" => {
            json|error removed = deleteInstitution(ask("institution name"));
            io:println(removed is error ? "  " + explain(removed) : "  removed");
        }
        _ => {
            io:println("  no such option");
        }
    }
}
