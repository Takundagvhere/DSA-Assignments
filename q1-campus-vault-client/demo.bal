import ballerina/io;

// Scripted run for the demo slot.
//
// The server starts with an empty register, so this seeds its own data first
// and then exercises the five views. Seeding is tolerant of a second run:
// if the records are already there the failures are reported and the demo
// carries on rather than stopping.
function runDemo() returns error? {
    string nust = "Namibia University of Science and Technology";
    string unam = "University of Namibia";

    heading("0. Seeding, because the register starts empty");
    seedInstitution({name: nust, sites: ["Main Campus", "Main Campus - Innovation Lab"]});
    seedInstitution({name: unam, sites: ["Main Campus", "Oshakati Campus"]});

    seedAsset({
        assetTag: "NUST-LIB-3DP-001",
        name: "Pro-Series 3D Printer",
        description: "High-precision laboratory printer for prototype development.",
        institution: nust,
        site: "Main Campus - Innovation Lab",
        status: "AVAILABLE",
        dateAcquired: "2024-03-10",
        components: [],
        schedules: [],
        workOrders: []
    });
    seedAsset({
        assetTag: "NUST-LIB-LAP-014",
        name: "Dell Latitude 5440",
        description: "Short loan laptop, issued for up to seven days.",
        institution: nust,
        site: "Main Campus",
        status: "AVAILABLE",
        dateAcquired: "2025-01-22",
        components: [],
        schedules: [],
        workOrders: []
    });
    seedAsset({
        assetTag: "NUST-MAIN-ROOM-004",
        name: "Group Study Room 4",
        description: "Six-seater discussion room on the first floor.",
        institution: nust,
        site: "Main Campus",
        status: "AVAILABLE",
        dateAcquired: "2019-08-01",
        components: [],
        schedules: [],
        workOrders: []
    });
    seedAsset({
        assetTag: "UNAM-OSH-TC-207",
        name: "HP t530 Thin Client",
        description: "Lab terminal, bench 7.",
        institution: unam,
        site: "Oshakati Campus",
        status: "AVAILABLE",
        dateAcquired: "2022-11-15",
        components: [],
        schedules: [],
        workOrders: []
    });

    heading("1. Global view - every asset the ministry owns");
    printAssets(check fetchAllAssets());

    heading("2. Campus view - by institution");
    printAssets(check fetchByInstitution(nust));

    heading("3. Campus view - by site");
    printAssets(check fetchBySite("Oshakati Campus"));

    heading("4. A maintenance window that has already passed");
    Asset|error scheduled = addSchedule("NUST-LIB-3DP-001", {
        scheduleId: "SCH-882",
        'type: "MAINTENANCE",
        dueDate: "2026-09-01",
        description: "Quarterly calibration and nozzle cleaning."
    });
    io:println(scheduled is error ? "  " + explain(scheduled) : "  schedule filed against the printer");

    heading("5. Overdue dashboard");
    printOverdue(check fetchOverdue());

    heading("6. Maintenance status for the printer");
    MaintenanceStatus status = check fetchMaintenance("NUST-LIB-3DP-001");
    io:println("  " + status.assetTag + " is " + status.status
        + (status.hasOverdueMaintenance ? ", maintenance overdue" : ", maintenance up to date"));

    heading("7. Are the room's dates free?");
    Availability before = check checkAvailability("NUST-MAIN-ROOM-004", "2026-10-05", "2026-10-07");
    io:println("  2026-10-05 to 2026-10-07: " + (before.available ? "free" : "already held"));

    heading("8. Book the room");
    LoanOutcome booked = check loanAsset("NUST-MAIN-ROOM-004", "220012345 S. Amutenya", "2026-10-05", "2026-10-07");
    io:println("  " + booked.message);
    io:println("  hold reference " + booked.scheduleId);

    heading("9. Someone else wants overlapping nights");
    LoanOutcome clash = check loanAsset("NUST-MAIN-ROOM-004", "219998888 T. Shipena", "2026-10-06", "2026-10-08");
    io:println("  " + clash.message);

    heading("10. Starting on the previous booking's end date is allowed");
    Availability adjacent = check checkAvailability("NUST-MAIN-ROOM-004", "2026-10-07", "2026-10-09");
    io:println("  2026-10-07 to 2026-10-09: " + (adjacent.available ? "free, the windows are half open" : "held"));

    heading("11. Backwards dates are refused before anything is written");
    LoanOutcome backwards = check loanAsset("NUST-LIB-LAP-014", "Someone", "2026-10-10", "2026-10-08");
    io:println("  " + backwards.message);

    heading("12. The room now reads OCCUPIED and carries the hold");
    printAsset(check fetchAsset("NUST-MAIN-ROOM-004"));

    heading("13. Check the room back in");
    LoanOutcome returned = check checkIn("NUST-MAIN-ROOM-004", booked.scheduleId);
    io:println("  " + returned.message);
    Asset after = check fetchAsset("NUST-MAIN-ROOM-004");
    io:println("  status is now " + after.status);

    heading("14. Schedule manager - add then remove");
    Asset|error added = addSchedule("NUST-LIB-LAP-014", {
        scheduleId: "SCH-903",
        'type: "SERVICE",
        dueDate: "2026-12-01",
        description: "Annual battery health check."
    });
    io:println(added is error ? "  " + explain(added) : "  added SCH-903");
    json|error dropped = removeSchedule("NUST-LIB-LAP-014", "SCH-903");
    io:println(dropped is error ? "  " + explain(dropped) : "  removed SCH-903");

    heading("15. Asking for an asset that does not exist");
    Asset|error missing = fetchAsset("NUST-LIB-LAP-999");
    io:println("  " + (missing is error ? explain(missing) : "found it, which is a bug"));

    heading("16. Registering a tag that is already taken");
    Asset|error duplicate = createAsset({
        assetTag: "NUST-LIB-LAP-014",
        name: "Duplicate",
        description: "",
        institution: nust,
        site: "Main Campus",
        status: "AVAILABLE",
        dateAcquired: "2025-01-22",
        components: [],
        schedules: [],
        workOrders: []
    });
    io:println("  " + (duplicate is error ? explain(duplicate) : "accepted, which is a bug"));

    io:println("");
    io:println("demo finished");
}

function seedInstitution(Institution institution) {
    Institution|error result = createInstitution(institution);
    io:println(result is error
        ? "  " + institution.name + " - " + explain(result)
        : "  registered " + institution.name);
}

function seedAsset(Asset asset) {
    Asset|error result = createAsset(asset);
    io:println(result is error
        ? "  " + asset.assetTag + " - " + explain(result)
        : "  registered " + asset.assetTag);
}
