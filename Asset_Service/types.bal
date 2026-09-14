// Shared data models for the Library Resource Management System.

// The four resource states named in the specification, plus OCCUPIED for booked spaces.
public enum AssetStatus {
    AVAILABLE,
    LOANED_OUT,
    OCCUPIED,
    UNDER_MAINTENANCE,
    DISPOSED
}

public enum ScheduleType {
    MAINTENANCE,
    BOOKING
}

public enum WorkOrderStatus {
    OPEN,
    IN_PROGRESS,
    CLOSED
}

// The three resource categories the specification identifies.
public enum AssetCategory {
    BOOK,
    ELECTRONIC_RESOURCE,
    PHYSICAL_SPACE
}

// A single step within a work order, e.g. "replace screen".
public type Task record {|
    string taskId;
    string description;
    boolean completed?;
|};

// A replaceable part of a complex asset, e.g. a printer motor.
public type Component record {|
    string compId;
    string name;
    string description;
|};

// A repair job raised against a faulty asset.
public type WorkOrder record {|
    string orderId;
    WorkOrderStatus status;
    string description;
    Task[] tasks;
|};

// A servicing date or a room booking.
public type Schedule record {|
    string scheduleId;
    ScheduleType 'type;    // 'type escapes the reserved keyword; the JSON field is plain "type"
    string dueDate;        // ISO 8601, so dates compare correctly as plain strings
    string description;
|};

// Any tracked resource: a book, an electronic device or a physical space.
public type Asset record {|
    readonly string assetTag;   // readonly because the table indexes on this field
    string name;
    string description;
    AssetCategory category;
    string institution;
    string site;
    AssetStatus status;
    string dateAcquired;
    Component[] components;
    Schedule[] schedules;
    WorkOrder[] workOrders;
|};

// A registered institution and the campuses it operates.
public type Institution record {|
    readonly string code;
    string name;
    string[] sites;
|};

// The response body every endpoint returns on failure.
public type ErrorMessage record {|
    string message;
|};
