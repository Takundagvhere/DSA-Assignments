// Business rules for adding and removing components on complex assets.

// Adds a sub-component to an existing asset.
public function addComponent(string assetTag, Component comp) returns Asset|error {
    lock {
        if !assetDb.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetDb.get(assetTag);

        foreach Component c in asset.components {
            if c.compId == comp.compId {
                return error("Component '" + comp.compId + "' already exists on asset '" + assetTag + "'",
                        errorCode = "DUPLICATE_COMPONENT");
            }
        }

        asset.components.push(comp);
        assetDb.put(asset);
        return asset;
    }
}

// Removes a component by compId.
public function removeComponent(string assetTag, string compId) returns Asset|error {
    lock {
        if !assetDb.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        Asset asset = assetDb.get(assetTag);

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
        assetDb.put(asset);
        return asset;
    }
}

// Lists components on an asset.
public function listComponents(string assetTag) returns Component[]|error {
    lock {
        if !assetDb.hasKey(assetTag) {
            return error("Asset '" + assetTag + "' not found", errorCode = "ASSET_NOT_FOUND");
        }
        return assetDb.get(assetTag).components.clone();
    }
}
