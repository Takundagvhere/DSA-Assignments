import ballerina/io;

// Fixed width output, no ANSI colour. The lab machines run this through
// PowerShell and escape codes come out as literal garbage there.

function pad(string value, int width) returns string {
    if value.length() >= width {
        return width > 3 ? value.substring(0, width - 3) + ".. " : value.substring(0, width);
    }
    string padded = value;
    while padded.length() < width {
        padded += " ";
    }
    return padded;
}

function rule(int width) {
    string line = "";
    while line.length() < width {
        line += "-";
    }
    io:println(line);
}

function heading(string title) {
    io:println("");
    io:println("== " + title + " ==");
}

function printAssets(Asset[] assets) {
    if assets.length() == 0 {
        io:println("  (nothing to show)");
        return;
    }
    io:println(pad("ASSET TAG", 22) + pad("NAME", 30) + pad("SITE", 30) + "STATUS");
    rule(100);
    foreach Asset a in assets {
        io:println(pad(a.assetTag, 22) + pad(a.name, 30) + pad(a.site, 30) + a.status);
    }
    io:println(string `  ${assets.length()} record(s)`);
}

function printAsset(Asset a) {
    rule(62);
    io:println(a.assetTag + "  " + a.name);
    rule(62);
    io:println("  institution : " + a.institution);
    io:println("  site        : " + a.site);
    io:println("  status      : " + a.status);
    io:println("  acquired    : " + a.dateAcquired);
    if a.description != "" {
        io:println("  description : " + a.description);
    }

    Component[] components = a.components ?: [];
    if components.length() > 0 {
        io:println("  components  :");
        foreach Component c in components {
            io:println("      " + pad(c.compId, 10) + c.name);
        }
    }

    Schedule[] schedules = a.schedules ?: [];
    if schedules.length() > 0 {
        io:println("  schedules   :");
        foreach Schedule s in schedules {
            io:println("      " + pad(s.scheduleId, 12) + pad(s.'type, 14) + describeWindow(s));
        }
    }

    WorkOrder[] orders = a.workOrders ?: [];
    if orders.length() > 0 {
        io:println("  work orders :");
        foreach WorkOrder w in orders {
            io:println("      " + pad(w.orderId, 12) + pad(w.status, 14) + w.description);
            foreach Task t in w.tasks ?: [] {
                string mark = t.completed == true ? "[x] " : "[ ] ";
                io:println("          " + mark + pad(t.taskId, 8) + t.description);
            }
        }
    }
}

// A BOOKING row carries startDate and endDate; a MAINTENANCE row carries only
// dueDate and sends the other two back as null.
function describeWindow(Schedule s) returns string {
    string? begins = s?.startDate;
    string? ends = s?.endDate;
    if begins is string && ends is string {
        return begins + " to " + ends;
    }
    return "due " + s.dueDate;
}

function printOverdue(OverdueEntry[] entries) {
    if entries.length() == 0 {
        io:println("  Nothing overdue.");
        return;
    }
    io:println(pad("ASSET TAG", 22) + pad("SCHEDULE", 12) + pad("TYPE", 14)
        + pad("DUE", 12) + "SITE");
    rule(96);
    int total = 0;
    foreach OverdueEntry e in entries {
        foreach Schedule s in e.overdueSchedules {
            io:println(pad(e.assetTag, 22) + pad(s.scheduleId, 12) + pad(s.'type, 14)
                + pad(s.dueDate, 12) + e.site);
            total += 1;
        }
    }
    io:println(string `  ${total} schedule(s) past due across ${entries.length()} asset(s)`);
}

function printInstitutions(Institution[] institutions) {
    if institutions.length() == 0 {
        io:println("  (no institutions registered)");
        return;
    }
    foreach Institution i in institutions {
        io:println("  " + i.name);
        foreach string site in i.sites ?: [] {
            io:println("      - " + site);
        }
    }
}

function ask(string prompt) returns string {
    return io:readln(prompt + ": ").trim();
}

function askOptional(string prompt) returns string {
    return io:readln(prompt + " (blank to skip): ").trim();
}
