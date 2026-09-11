// Component management for complex assets (e.g. a printer's motor).
// Pure business logic — no http: types here; resource functions in
// service.bal call these and translate errors via error_handling.bal.

// Adds a sub-component to an existing asset. Fails if the asset doesn't
// exist or if a component with the same compId is already present.
public isolated function addComponent(string assetTag, Component comp) returns Asset|error {
    lock {
        if !assetTable.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetTable.get(assetTag).clone();

        foreach Component c in asset.components {
            if c.compId == comp.compId {
                return error("Component '" + comp.compId + "' already exists on asset '" + assetTag + "'",
                        errorCode = "DUPLICATE_COMPONENT");
            }
        }

        asset.components.push(comp.clone());
        assetTable.put(asset);
        return asset.clone();
    }
}

// Removes a component by compId from an asset.
public isolated function removeComponent(string assetTag, string compId) returns Asset|error {
    lock {
        if !assetTable.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetTable.get(assetTag).clone();

        int removeIdx = -1;
        foreach int i in 0 ..< asset.components.length() {
            if asset.components[i].compId == compId {
                removeIdx = i;
                break;
            }
        }
        if removeIdx == -1 {
            return error("Component '" + compId + "' not found on asset '" + assetTag + "'",
                    errorCode = "COMPONENT_NOT_FOUND");
        }

        _ = asset.components.remove(removeIdx);
        assetTable.put(asset);
        return asset.clone();
    }
}

// Lists components on an asset — handy for the client's asset detail view.
public isolated function listComponents(string assetTag) returns Component[]|error {
    lock {
        if !assetTable.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        return assetTable.get(assetTag).components.clone();
    }
}
