// Client-side view of the CampusVault payloads.
//
// These mirror types.bal on the server but are declared open (record { },
// not record {| |}) because the two are separate packages compiled
// separately. If the server adds a field, this client keeps binding instead
// of failing. The one place that matters already: Schedule.startDate and
// endDate come back as null on MAINTENANCE rows, so they are nilable here.

type Component record {
    string compId;
    string name;
    string description;
};

type Task record {
    string taskId;
    string description;
    boolean completed?;
};

type WorkOrder record {
    string orderId;
    string status;
    string description;
    Task[] tasks?;
};

type Schedule record {
    string scheduleId;
    string 'type;
    string dueDate;
    string description;
    string? startDate?;
    string? endDate?;
};

type Asset record {
    string assetTag;
    string name;
    string description;
    string institution;
    string site;
    string status;
    string dateAcquired;
    Component[] components?;
    Schedule[] schedules?;
    WorkOrder[] workOrders?;
};

// Keyed by name on the server, not by a short code, so the campus filter has
// to URL-encode the whole institution name into the path.
type Institution record {
    string name;
    string[] sites?;
};

// Shape returned by GET /assets/overdue. Note it groups the offending
// schedules under the asset rather than returning one row per schedule.
type OverdueEntry record {
    string assetTag;
    string name;
    string institution;
    string site;
    Schedule[] overdueSchedules;
};

// GET /assets/{tag}/schedules/availability
type Availability record {
    string assetTag;
    string requestedStart;
    string requestedEnd;
    boolean available;
};

// GET /assets/{tag}/maintenance
type MaintenanceStatus record {
    string assetTag;
    string status;
    Schedule[] maintenanceSchedules;
    boolean hasOverdueMaintenance;
};
