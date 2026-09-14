// Client-side view of the server payloads; open records so added server fields do not break binding.

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
};

type Asset record {
    string assetTag;
    string name;
    string description;
    string category?;
    string institution;
    string site;
    string status;
    string dateAcquired;
    Component[] components?;
    Schedule[] schedules?;
    WorkOrder[] workOrders?;
};

type Institution record {
    string code;
    string name;
    string[] sites?;
};

// Shape returned by GET /assets/overdue - one row per overdue
type OverdueEntry record {
    string assetTag;
    string assetName;
    string institution;
    string site;
    string scheduleId;
    string scheduleType;
    string dueDate;
    string description;
    string currentAssetStatus;
};

// Shape returned by GET /assets/{tag}/availability
type Availability record {
    string assetTag;
    string assetName;
    string status;
    string requestedDate;
    boolean available;
    string reason;
};

// Standard error body from the server.
type ErrorBody record {
    string message?;
    string errorCode?;
    string timestamp?;
};
