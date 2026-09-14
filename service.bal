// REST endpoints for the Library Resource Management System.

import ballerina/http;
import ballerina/log;

service /library on new http:Listener(9090) {

    function init() {
        seedData();
        log:printInfo("Library service started with " +
                assetDb.length().toString() + " assets across " +
                institutionDb.length().toString() + " institutions.");
    }

    // Asset CRUD - Role 2

    // POST /library/assets
    resource function post assets(@http:Payload Asset newAsset)
            returns http:Created|http:Conflict|http:BadRequest {
        lock {
            if newAsset.assetTag.trim() == "" {
                return badRequest("assetTag is required", "MISSING_FIELD");
            }
            if assetDb.hasKey(newAsset.assetTag) {
                return <http:Conflict>{
                    body: {message: "Asset '" + newAsset.assetTag + "' already exists"}
                };
            }
            assetDb.put(newAsset);
            return <http:Created>{body: newAsset};
        }
    }

    // GET /library/assets/{assetTag}
    resource function get assets/[string assetTag]() returns Asset|http:NotFound {
        lock {
            if !assetDb.hasKey(assetTag) {
                return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
            }
            return assetDb.get(assetTag).clone();
        }
    }

    // PUT /library/assets/{assetTag}
    resource function put assets/[string assetTag](@http:Payload Asset updated)
            returns Asset|http:NotFound|http:BadRequest {
        lock {
            if !assetDb.hasKey(assetTag) {
                return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
            }
            if updated.assetTag != assetTag {
                return badRequest("assetTag in body must match the assetTag in the URL");
            }
            assetDb.put(updated);
            return updated.clone();
        }
    }

    // DELETE /library/assets/{assetTag}
    resource function delete assets/[string assetTag]() returns Asset|http:NotFound {
        lock {
            Asset? removed = assetDb.removeIfHasKey(assetTag);
            if removed is () {
                return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
            }
            return removed.clone();
        }
    }

    // Filtering and institution management - Role 3

    // GET /library/assets
    resource function get assets() returns Asset[] {
        lock {
            return assetDb.toArray().clone();
        }
    }

    // GET /library/assets/institution/{name}
    resource function get assets/institution/[string name]()
            returns Asset[]|http:NotFound {
        lock {
            Asset[] result = from Asset a in assetDb
                where a.institution == name
                select a;
            if result.length() == 0 {
                return <http:NotFound>{
                    body: {message: "No assets found for institution: " + name}
                };
            }
            return result.clone();
        }
    }

    // GET /library/assets/site/{siteName}
    resource function get assets/site/[string siteName]()
            returns Asset[]|http:NotFound {
        lock {
            Asset[] result = from Asset a in assetDb
                where a.site == siteName
                select a;
            if result.length() == 0 {
                return <http:NotFound>{
                    body: {message: "No assets found for site: " + siteName}
                };
            }
            return result.clone();
        }
    }

    // GET /library/institutions
    resource function get institutions() returns Institution[] {
        lock {
            return institutionDb.toArray().clone();
        }
    }

    // POST /library/institutions
    resource function post institutions(@http:Payload Institution newInst)
            returns http:Created|http:Conflict|http:BadRequest {
        lock {
            if newInst.code.trim() == "" {
                return badRequest("Institution code is required", "MISSING_FIELD");
            }
            if institutionDb.hasKey(newInst.code) {
                return <http:Conflict>{
                    body: {message: "Institution '" + newInst.code + "' already exists"}
                };
            }
            institutionDb.put(newInst);
            return <http:Created>{body: newInst};
        }
    }

    // DELETE /library/institutions/{code}
    resource function delete institutions/[string code]()
            returns Institution|http:NotFound {
        lock {
            Institution? removed = institutionDb.removeIfHasKey(code);
            if removed is () {
                return <http:NotFound>{body: {message: "Institution not found: " + code}};
            }
            return removed.clone();
        }
    }

    // Schedules, overdue checks and availability - Role 4

    // POST /library/assets/{assetTag}/schedules
    resource function post assets/[string assetTag]/schedules(@http:Payload Schedule newSchedule)
            returns http:Created|http:NotFound|http:BadRequest {
        lock {
            if !assetDb.hasKey(assetTag) {
                return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
            }
            Asset asset = assetDb.get(assetTag);

            foreach Schedule existing in asset.schedules {
                if existing.scheduleId == newSchedule.scheduleId {
                    return badRequest("Schedule '" + newSchedule.scheduleId + "' already exists",
                            "DUPLICATE_SCHEDULE");
                }
            }

            asset.schedules.push(newSchedule);
            assetDb.put(asset);
            return <http:Created>{body: asset.clone()};
        }
    }

    // DELETE /library/assets/{assetTag}/schedules/{scheduleId}
    resource function delete assets/[string assetTag]/schedules/[string scheduleId]()
            returns Asset|http:NotFound {
        lock {
            if !assetDb.hasKey(assetTag) {
                return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
            }
            Asset asset = assetDb.get(assetTag);

            int removeIndex = -1;
            foreach int i in 0 ..< asset.schedules.length() {
                if asset.schedules[i].scheduleId == scheduleId {
                    removeIndex = i;
                    break;
                }
            }
            if removeIndex == -1 {
                return <http:NotFound>{body: {message: "Schedule not found: " + scheduleId}};
            }

            _ = asset.schedules.remove(removeIndex);
            assetDb.put(asset);
            return asset.clone();
        }
    }

    // GET /library/assets/overdue        (optional ?currentDate=YYYY-MM-DD)
    resource function get assets/overdue(string? currentDate) returns json {
        string today = currentDate ?: todayString();
        lock {
            json[] overdueList = [];
            foreach Asset asset in assetDb {
                foreach Schedule schedule in asset.schedules {
                    if schedule.dueDate < today {
                        overdueList.push({
                            "assetTag": asset.assetTag,
                            "assetName": asset.name,
                            "institution": asset.institution,
                            "site": asset.site,
                            "scheduleId": schedule.scheduleId,
                            "scheduleType": schedule.'type,
                            "dueDate": schedule.dueDate,
                            "description": schedule.description,
                            "currentAssetStatus": asset.status
                        });
                    }
                }
            }
            return overdueList.clone();
        }
    }

    // PUT /library/assets/{assetTag}/status
    resource function put assets/[string assetTag]/status(
            @http:Payload record {| AssetStatus status; |} payload)
            returns Asset|http:NotFound {
        lock {
            if !assetDb.hasKey(assetTag) {
                return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
            }
            Asset asset = assetDb.get(assetTag);
            asset.status = payload.status;
            assetDb.put(asset);
            return asset.clone();
        }
    }

    // GET /library/assets/{assetTag}/availability?checkDate=YYYY-MM-DD
    resource function get assets/[string assetTag]/availability(string checkDate)
            returns json|http:NotFound {
        lock {
            if !assetDb.hasKey(assetTag) {
                return <http:NotFound>{body: {message: "Asset not found: " + assetTag}};
            }
            Asset asset = assetDb.get(assetTag);

            boolean isScheduledOnDate = false;
            foreach Schedule schedule in asset.schedules {
                if schedule.dueDate == checkDate {
                    isScheduledOnDate = true;
                    break;
                }
            }

            boolean isAvailable = (asset.status == AVAILABLE) && !isScheduledOnDate;

            json result = {
                "assetTag": asset.assetTag,
                "assetName": asset.name,
                "status": asset.status,
                "requestedDate": checkDate,
                "available": isAvailable,
                "reason": isAvailable ? "Asset is available." :
                    (isScheduledOnDate ? "Asset has an active schedule on this date." :
                    "Asset status is " + asset.status)
            };
            return result.clone();
        }
    }

    // Components, work orders and tasks - Role 5

    // POST /library/assets/{assetTag}/components
    resource function post assets/[string assetTag]/components(@http:Payload Component comp)
            returns Asset|http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {
        Asset|error result = addComponent(assetTag, comp);
        if result is error {
            return toErrorResponse(result);
        }
        return result;
    }

    // GET /library/assets/{assetTag}/components
    resource function get assets/[string assetTag]/components()
            returns Component[]|http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {
        Component[]|error result = listComponents(assetTag);
        if result is error {
            return toErrorResponse(result);
        }
        return result;
    }

    // DELETE /library/assets/{assetTag}/components/{compId}
    resource function delete assets/[string assetTag]/components/[string compId]()
            returns Asset|http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {
        Asset|error result = removeComponent(assetTag, compId);
        if result is error {
            return toErrorResponse(result);
        }
        return result;
    }

    // POST /library/assets/{assetTag}/workorders
    resource function post assets/[string assetTag]/workorders(@http:Payload WorkOrder wo)
            returns Asset|http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {
        Asset|error result = openWorkOrder(assetTag, wo);
        if result is error {
            return toErrorResponse(result);
        }
        return result;
    }

    // PUT /library/assets/{assetTag}/workorders/{orderId}
    resource function put assets/[string assetTag]/workorders/[string orderId](
            @http:Payload record {| WorkOrderStatus status?; string description?; |} payload)
            returns Asset|http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {
        Asset|error result = updateWorkOrder(assetTag, orderId,
                payload?.status, payload?.description);
        if result is error {
            return toErrorResponse(result);
        }
        return result;
    }

    // POST /library/assets/{assetTag}/workorders/{orderId}/tasks
    resource function post assets/[string assetTag]/workorders/[string orderId]/tasks(
            @http:Payload Task task)
            returns Asset|http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {
        Asset|error result = addTask(assetTag, orderId, task);
        if result is error {
            return toErrorResponse(result);
        }
        return result;
    }

    // DELETE /library/assets/{assetTag}/workorders/{orderId}/tasks/{taskId}
    resource function delete assets/[string assetTag]/workorders/[string orderId]/tasks/[string taskId]()
            returns Asset|http:BadRequest|http:NotFound|http:Conflict|http:InternalServerError {
        Asset|error result = removeTask(assetTag, orderId, taskId);
        if result is error {
            return toErrorResponse(result);
        }
        return result;
    }
}
