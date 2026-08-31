local ADDON_NAME, FTA = ...

-- Follow The Arrow -> WardenGG bridge.
-- Exposes the current resolved FTA step/target as read-only data.

local Bridge = {}
Bridge.VERSION = "0.2-nav-test"
Bridge.ADDON_NAME = ADDON_NAME

local function copyArray(t)
    if type(t) ~= "table" then return nil end
    local out = {}
    for i = 1, #t do out[i] = t[i] end
    return out
end

local function shallowCopy(t)
    if type(t) ~= "table" then return nil end
    local out = {}
    for k, v in pairs(t) do
        if type(v) ~= "table" then
            out[k] = v
        end
    end
    return out
end

local function normalize01(v)
    if type(v) ~= "number" then return nil end
    if v > 1 then return v / 100 end
    return v
end

local function questIDsCopy(v)
    if type(v) == "number" then return { v } end
    if type(v) == "table" then return copyArray(v) end
    return nil
end

function Bridge.Ping()
    return true, Bridge.VERSION
end

function Bridge.GetCurrent()
    if not FTA then
        return nil, "FTA namespace unavailable"
    end
    if not (FTA.StepEngine and FTA.StepEngine.GetCurrentStep) then
        return nil, "StepEngine unavailable"
    end
    if not (FTA.Resolve and FTA.Resolve.GetActiveSegment and FTA.Resolve.GetCurrentTarget) then
        return nil, "StepResolver unavailable"
    end

    local ok, result, err = pcall(function()
        local moduleId = FTA.StepEngine:GetActiveModuleId()
        local routeId = FTA.StepEngine.GetActiveRouteId and FTA.StepEngine:GetActiveRouteId() or nil
        local mod, stepIndex, step = FTA.StepEngine:GetCurrentStep()
        if not mod or not step then
            return nil, "No active Follow The Arrow step"
        end

        local segIndex, seg = FTA.Resolve:GetActiveSegment(mod, step, moduleId, stepIndex)
        local target = FTA.Resolve:GetCurrentTarget(mod, step)

        local out = {
            bridgeVersion = Bridge.VERSION,
            routeId = routeId,
            moduleId = moduleId or mod.id,
            moduleTitle = mod.title,
            stepIndex = stepIndex,
            stepText = step.text or step.title,
            segmentIndex = segIndex,
            kind = seg and seg.kind or nil,
            key = seg and seg.key or nil,
            advance = seg and seg.advance or nil,
            questName = seg and seg.questName or nil,
            text = seg and (seg.text or seg.label or seg.title) or nil,
            questIDs = seg and questIDsCopy(seg.questIDs or seg.questID) or nil,
            objectiveIndex = seg and seg.objectiveIndex or nil,
            gate = seg and shallowCopy(seg.gate) or nil,
            target = nil,
        }

        if target then
            local mapIDs = nil
            if type(target.mapIDs) == "table" then
                mapIDs = copyArray(target.mapIDs)
            elseif type(target.mapID) == "table" then
                mapIDs = copyArray(target.mapID)
            elseif type(target.mapID) == "number" then
                mapIDs = { target.mapID }
            end

            out.target = {
                mapID = type(target.mapID) == "number" and target.mapID or (mapIDs and mapIDs[1]) or nil,
                mapIDs = mapIDs,
                x = target.x,
                y = target.y,
                x01 = normalize01(target.x),
                y01 = normalize01(target.y),
                radius = target.radius,
                arriveBehavior = target.arriveBehavior,
                onArrive = shallowCopy(target.onArrive),
            }
        end

        return out, nil
    end)

    if not ok then
        return nil, tostring(result)
    end
    return result, err
end

local function joinIDs(ids)
    if type(ids) ~= "table" or #ids == 0 then return "-" end
    local p = {}
    for i = 1, #ids do p[i] = tostring(ids[i]) end
    return table.concat(p, ",")
end

function Bridge.FormatCurrent()
    local d, err = Bridge.GetCurrent()
    if not d then return "ERROR: " .. tostring(err) end

    local t = d.target
    local targetText = "no target"
    if t then
        targetText = string.format(
            "map=%s x=%.4f y=%.4f radius=%s",
            tostring(t.mapID),
            tonumber(t.x01) or -1,
            tonumber(t.y01) or -1,
            tostring(t.radius or "-")
        )
    end

    return string.format(
        "route=%s module=%s step=%s seg=%s kind=%s q=%s %s text=%s",
        tostring(d.routeId or "-"),
        tostring(d.moduleId or "-"),
        tostring(d.stepIndex or "-"),
        tostring(d.segmentIndex or "-"),
        tostring(d.kind or "-"),
        joinIDs(d.questIDs),
        targetText,
        tostring(d.text or d.stepText or "-")
    )
end

FTA.WGGBridge = Bridge
_G.FTA_WGG_Bridge = Bridge

SLASH_FTAWGG1 = "/ftawgg"
SlashCmdList.FTAWGG = function()
    if FTA and FTA.Print then
        FTA:Print("WGG bridge " .. Bridge.VERSION .. ": " .. Bridge.FormatCurrent())
    else
        print("[FTA-WGG] " .. Bridge.FormatCurrent())
    end
end
