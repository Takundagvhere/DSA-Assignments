// Business rules for work orders and their sub-tasks.

function findWorkOrderIndex(Asset asset, string orderId) returns int {
    foreach int i in 0 ..< asset.workOrders.length() {
        if asset.workOrders[i].orderId == orderId {
            return i;
        }
    }
    return -1;
}

// Opens a new work order on an asset.
public function openWorkOrder(string assetTag, WorkOrder wo) returns Asset|error {
    lock {
        if !assetDb.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetDb.get(assetTag);

        if findWorkOrderIndex(asset, wo.orderId) != -1 {
            return error("Work order '" + wo.orderId + "' already exists on asset '" + assetTag + "'",
                    errorCode = "DUPLICATE_WORKORDER");
        }

        WorkOrder newOrder = wo.clone();
        newOrder.status = OPEN; // always opens as OPEN regardless of payload
        asset.workOrders.push(newOrder);
        assetDb.put(asset);
        return asset;
    }
}

// Updates a work order's status and/or description.
public function updateWorkOrder(string assetTag, string orderId,
        WorkOrderStatus? newStatus, string? newDescription) returns Asset|error {
    lock {
        if !assetDb.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetDb.get(assetTag);

        int idx = findWorkOrderIndex(asset, orderId);
        if idx == -1 {
            return error("Work order '" + orderId + "' not found on asset '" + assetTag + "'",
                    errorCode = "WORKORDER_NOT_FOUND");
        }

        if asset.workOrders[idx].status == CLOSED {
            return error("Work order '" + orderId + "' is already closed and cannot be modified",
                    errorCode = "WORKORDER_ALREADY_CLOSED");
        }

        if newStatus is WorkOrderStatus {
            asset.workOrders[idx].status = newStatus;
        }
        if newDescription is string {
            asset.workOrders[idx].description = newDescription;
        }

        assetDb.put(asset);
        return asset;
    }
}

// Convenience wrapper: closes a work order outright.
public function closeWorkOrder(string assetTag, string orderId) returns Asset|error {
    return updateWorkOrder(assetTag, orderId, CLOSED, ());
}

// ---- Sub-task management ---------------------------------------------

public function addTask(string assetTag, string orderId, Task task) returns Asset|error {
    lock {
        if !assetDb.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetDb.get(assetTag);

        int idx = findWorkOrderIndex(asset, orderId);
        if idx == -1 {
            return error("Work order '" + orderId + "' not found on asset '" + assetTag + "'",
                    errorCode = "WORKORDER_NOT_FOUND");
        }
        if asset.workOrders[idx].status == CLOSED {
            return error("Cannot add a task to a closed work order",
                    errorCode = "WORKORDER_ALREADY_CLOSED");
        }

        foreach Task t in asset.workOrders[idx].tasks {
            if t.taskId == task.taskId {
                return error("Task '" + task.taskId + "' already exists on work order '" + orderId + "'",
                        errorCode = "DUPLICATE_TASK");
            }
        }

        asset.workOrders[idx].tasks.push(task.clone());
        assetDb.put(asset);
        return asset;
    }
}

// Marks a sub-task complete/incomplete, or removes it if remove = true.
public function updateTask(string assetTag, string orderId, string taskId,
        boolean? completed, boolean remove = false) returns Asset|error {
    lock {
        if !assetDb.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetDb.get(assetTag);

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

        assetDb.put(asset);
        return asset;
    }
}

public function removeTask(string assetTag, string orderId, string taskId) returns Asset|error {
    return updateTask(assetTag, orderId, taskId, (), remove = true);
}
