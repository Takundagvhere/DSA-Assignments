// Work order management for faulty resources, including sub-tasks
// (e.g. "replace screen").
//
// Lifecycle: OPEN -> IN_PROGRESS -> CLOSED

final string[] VALID_WO_STATUSES = ["OPEN", "IN_PROGRESS", "CLOSED"];

isolated function findWorkOrderIndex(Asset asset, string orderId) returns int {
    foreach int i in 0 ..< asset.workOrders.length() {
        if asset.workOrders[i].orderId == orderId {
            return i;
        }
    }
    return -1;
}

// Opens a new work order on an asset for a faulty resource.
public isolated function openWorkOrder(string assetTag, WorkOrder wo) returns Asset|error {
    lock {
        if !assetTable.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetTable.get(assetTag).clone();

        if findWorkOrderIndex(asset, wo.orderId) != -1 {
            return error("Work order '" + wo.orderId + "' already exists on asset '" + assetTag + "'",
                    errorCode = "DUPLICATE_COMPONENT");
        }

        WorkOrder newOrder = wo.clone();
        newOrder.status = "OPEN"; // always opens as OPEN regardless of payload
        asset.workOrders.push(newOrder);
        assetTable.put(asset);
        return asset.clone();
    }
}

// Updates a work order's status and/or description.
// Enforces the OPEN -> IN_PROGRESS -> CLOSED lifecycle and rejects
// edits to an already-CLOSED order (that's what makes closing final).
public isolated function updateWorkOrder(string assetTag, string orderId, string? newStatus, string? newDescription)
        returns Asset|error {
    lock {
        if !assetTable.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetTable.get(assetTag).clone();

        int idx = findWorkOrderIndex(asset, orderId);
        if idx == -1 {
            return error("Work order '" + orderId + "' not found on asset '" + assetTag + "'",
                    errorCode = "WORKORDER_NOT_FOUND");
        }

        if asset.workOrders[idx].status == "CLOSED" {
            return error("Work order '" + orderId + "' is already closed and cannot be modified",
                    errorCode = "WORKORDER_ALREADY_CLOSED");
        }

        if newStatus is string {
            if VALID_WO_STATUSES.indexOf(newStatus) is () {
                return error("Invalid work order status '" + newStatus + "'. Must be one of: OPEN, IN_PROGRESS, CLOSED",
                        errorCode = "INVALID_STATUS");
            }
            asset.workOrders[idx].status = newStatus;
        }
        if newDescription is string {
            asset.workOrders[idx].description = newDescription;
        }

        assetTable.put(asset);
        return asset.clone();
    }
}

// Convenience wrapper: closes a work order outright.
public isolated function closeWorkOrder(string assetTag, string orderId) returns Asset|error {
    return updateWorkOrder(assetTag, orderId, "CLOSED", ());
}

// ---- Sub-task management ------------------------------------------------

// Adds a sub-task to an existing (non-closed) work order.
public isolated function addTask(string assetTag, string orderId, Task task) returns Asset|error {
    lock {
        if !assetTable.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetTable.get(assetTag).clone();

        int idx = findWorkOrderIndex(asset, orderId);
        if idx == -1 {
            return error("Work order '" + orderId + "' not found on asset '" + assetTag + "'",
                    errorCode = "WORKORDER_NOT_FOUND");
        }
        if asset.workOrders[idx].status == "CLOSED" {
            return error("Cannot add a task to a closed work order", errorCode = "WORKORDER_ALREADY_CLOSED");
        }

        foreach Task t in asset.workOrders[idx].tasks {
            if t.taskId == task.taskId {
                return error("Task '" + task.taskId + "' already exists on work order '" + orderId + "'",
                        errorCode = "DUPLICATE_COMPONENT");
            }
        }

        asset.workOrders[idx].tasks.push(task.clone());
        assetTable.put(asset);
        return asset.clone();
    }
}

// Marks a sub-task complete/incomplete, or removes it entirely if remove=true.
public isolated function updateTask(string assetTag, string orderId, string taskId, boolean? completed,
        boolean remove = false) returns Asset|error {
    lock {
        if !assetTable.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetTable.get(assetTag).clone();

        int woIdx = findWorkOrderIndex(asset, orderId);
        if woIdx == -1 {
            return error("Work order '" + orderId + "' not found on asset '" + assetTag + "'",
                    errorCode = "WORKORDER_NOT_FOUND");
        }

        int taskIdx = -1;
        foreach int i in 0 ..< asset.workOrders[woIdx].tasks.length() {
            if asset.workOrders[woIdx].tasks[i].taskId == taskId {
                taskIdx = i;
                break;
            }
        }
        if taskIdx == -1 {
            return error("Task '" + taskId + "' not found on work order '" + orderId + "'",
                    errorCode = "TASK_NOT_FOUND");
        }

        if remove {
            _ = asset.workOrders[woIdx].tasks.remove(taskIdx);
        } else if completed is boolean {
            asset.workOrders[woIdx].tasks[taskIdx].completed = completed;
        }

        assetTable.put(asset);
        return asset.clone();
    }
}

public isolated function removeTask(string assetTag, string orderId, string taskId) returns Asset|error {
    return updateTask(assetTag, orderId, taskId, (), remove = true);
}
