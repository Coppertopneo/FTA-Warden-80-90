local ADDON_NAME, FTA = ...

-- Follow The Arrow -> WardenGG bridge.
-- Exposes the current resolved FTA step/target as read-only data.

local Bridge = {}
Bridge.VERSION = "0.4.2-fta-satisfied"
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

local function getLiveObjective(questIDs, objectiveIndex)
    if not (FTA and FTA.Quest and FTA.Quest.IsInLog) then
        return nil, nil
    end

    local inLog, activeQID = FTA.Quest:IsInLog(questIDs)
    if not inLog or not activeQID then
        return nil, nil
    end

    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then
        return activeQID, nil
    end

    local objs = C_QuestLog.GetQuestObjectives(activeQID)
    if type(objs) ~= "table" or #objs == 0 then
        return activeQID, nil
    end

    local idx = tonumber(objectiveIndex) or 1
    local o = objs[idx]
    if type(o) ~= "table" then
        return activeQID, nil
    end

    return activeQID, {
        index = idx,
        text = o.text,
        type = o.type,
        finished = o.finished,
        numFulfilled = o.numFulfilled,
        numRequired = o.numRequired,
    }
end

local function idsContain(ids, wanted)
    wanted = tonumber(wanted)
    if not wanted or type(ids) ~= "table" then return false end
    for i = 1, #ids do
        if tonumber(ids[i]) == wanted then return true end
    end
    return false
end

local function segmentVisible(step, segIndex, seg, moduleId, stepIndex)
    if type(seg) ~= "table" then return false end

    local prereqIdx = seg.showAfter
    if type(prereqIdx) == "number" then
        prereqIdx = math.floor(prereqIdx)
        if prereqIdx >= 1 and type(step) == "table" and type(step.segments) == "table" then
            local prereq = step.segments[prereqIdx]
            if type(prereq) == "table"
                and FTA.Resolve
                and FTA.Resolve.IsSegmentSatisfied
                and FTA.Resolve:IsSegmentSatisfied(prereq, moduleId, stepIndex, prereqIdx) ~= true
            then
                return false
            end
        end
    end

    if seg.showWhenQuestInLog ~= nil then
        local qids = seg.showWhenQuestInLog
        if qids == true then qids = seg.questIDs end
        if qids and FTA.Quest and FTA.Quest.IsInLog then
            local inLog = FTA.Quest:IsInLog(qids)
            if inLog ~= true then return false end
        end
    end

    return true
end

local function liveObjectiveComplete(o)
    if type(o) ~= "table" then return false end
    if o.finished == true then return true end

    local have = tonumber(o.numFulfilled)
    local need = tonumber(o.numRequired)
    if have and need and need > 0 and have >= need then
        return true
    end

    return false
end

local function segmentRecord(segIndex, seg, moduleId, stepIndex)
    if type(seg) ~= "table" then return nil end

    local ids = questIDsCopy(seg.questIDs or seg.questID)
    local activeQID, liveObjective = getLiveObjective(ids, seg.objectiveIndex)

    local satisfied = false
    if FTA.Resolve and FTA.Resolve.IsSegmentSatisfied then
        local ok, v = pcall(
            FTA.Resolve.IsSegmentSatisfied,
            FTA.Resolve,
            seg,
            moduleId,
            stepIndex,
            segIndex
        )
        satisfied = ok and v == true
    end

    local mapIDs = nil
    if type(seg.mapID) == "table" then
        mapIDs = copyArray(seg.mapID)
    elseif type(seg.mapID) == "number" then
        mapIDs = { seg.mapID }
    end

    return {
        segmentIndex = segIndex,
        kind = seg.kind,
        key = seg.key,
        advance = seg.advance,
        questName = seg.questName,
        text = seg.text or seg.label or seg.title,
        questIDs = ids,
        activeQuestID = activeQID,
        objectiveIndex = seg.objectiveIndex,
        liveObjective = liveObjective,
        satisfied = satisfied,
        complete = satisfied or liveObjectiveComplete(liveObjective),
        gate = shallowCopy(seg.gate),
        target = (seg.x and seg.y) and {
            mapID = mapIDs and mapIDs[1] or nil,
            mapIDs = mapIDs,
            x = seg.x,
            y = seg.y,
            x01 = normalize01(seg.x),
            y01 = normalize01(seg.y),
            radius = seg.radius,
        } or nil,
    }
end

local function getActionableSegments(step, moduleId, stepIndex)
    local out = {}
    if type(step) ~= "table" or type(step.segments) ~= "table" then return out end
    if not (FTA.Resolve and FTA.Resolve.IsSegmentSatisfied) then return out end

    for i, seg in ipairs(step.segments) do
        if type(seg) == "table"
            and seg.kind ~= "NOTE"
            and seg.kind ~= "CHAIN_START"
            and seg.kind ~= "IMAGE_POPUP"
            and seg.kind ~= "VIDEO_EMBED"
            and seg.kind ~= "MODULE_BUTTON"
            and seg.kind ~= "MODULE_CHOICE_ROW"
            and seg.kind ~= "CAMPAIGN_PROGRESS_CHOICE"
            and segmentVisible(step, i, seg, moduleId, stepIndex)
            and FTA.Resolve:IsSegmentSatisfied(seg, moduleId, stepIndex, i) ~= true
        then
            local r = segmentRecord(i, seg, moduleId, stepIndex)
            if r and r.complete ~= true then
                out[#out + 1] = r
            end
        end
    end
    return out
end

local function routeRequirement(step)
    if type(step) ~= "table" or type(step.arrow) ~= "table" then return nil end
    local seq = step.arrow
    if seq.mode ~= "SEQUENCE_CHAIN" or type(seq.nodes) ~= "table" then return nil end
    if not (FTA.StepEngine and FTA.StepEngine.GetChainIndex) then return nil end

    local key = seq.key or "STEPSEQ:DEFAULT"
    local idx = FTA.StepEngine:GetChainIndex(key)
    if type(idx) ~= "number" or idx < 1 then idx = 1 end
    if idx > #seq.nodes then return nil end

    local node = seq.nodes[idx]
    if type(node) ~= "table" then return nil end

    local reqIDs = nil
    local reqObj = nil
    local atLeast = nil
    local source = nil

    if type(node.gate) == "table" and node.gate.questID and node.gate.objectiveIndex then
        reqIDs = questIDsCopy(node.gate.questID)
        reqObj = node.gate.objectiveIndex
        atLeast = node.gate.atLeast
        source = "gate"
    elseif tostring(node.advance or "") == "OBJECTIVE" and node.objectiveIndex then
        reqIDs = questIDsCopy(node.questIDs or node.questID)
        reqObj = node.objectiveIndex
        source = "node"
    end

    return {
        mode = "SEQUENCE_CHAIN",
        key = key,
        chainIndex = idx,
        chainCount = #seq.nodes,
        advance = node.advance or "PROXIMITY",
        source = source,
        questIDs = reqIDs,
        objectiveIndex = reqObj,
        atLeast = atLeast,
        x = node.x,
        y = node.y,
        radius = node.radius or seq.radius,
        gate = shallowCopy(node.gate),
    }
end

local function chooseRecommendedSegment(actionable, req, fallback)
    if type(req) == "table"
        and type(req.questIDs) == "table"
        and req.objectiveIndex ~= nil
        and type(actionable) == "table"
    then
        for _, s in ipairs(actionable) do
            if s.complete ~= true and s.satisfied ~= true
                and tonumber(s.objectiveIndex) == tonumber(req.objectiveIndex)
                and type(s.questIDs) == "table"
            then
                for _, qid in ipairs(req.questIDs) do
                    if idsContain(s.questIDs, qid) then
                        return s
                    end
                end
            end
        end
    end

    if type(fallback) == "table" and fallback.complete ~= true and fallback.satisfied ~= true then
        return fallback
    end

    if type(actionable) == "table" then
        for _, s in ipairs(actionable) do
            if s.complete ~= true and s.satisfied ~= true then return s end
        end
    end

    return nil
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

        local activeQID, liveObjective = getLiveObjective(out.questIDs, out.objectiveIndex)
        out.activeQuestID = activeQID
        out.liveObjective = liveObjective

        out.actionableSegments = getActionableSegments(step, moduleId or mod.id, stepIndex)
        out.routeObjective = routeRequirement(step)
        out.recommendedSegment = chooseRecommendedSegment(
            out.actionableSegments,
            out.routeObjective,
            seg and segmentRecord(segIndex, seg, moduleId or mod.id, stepIndex) or nil
        )

        if FTA.Quest and FTA.Quest.IsReadyForTurnIn and out.questIDs then
            local ready = FTA.Quest:IsReadyForTurnIn(out.questIDs)
            out.readyForTurnIn = ready == true
        end

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

    local lo = d.liveObjective
    local objectiveText = "liveObj=-"
    if lo then
        objectiveText = string.format(
            "liveObj=%s/%s type=%s finished=%s text=%s",
            tostring(lo.numFulfilled or "-"),
            tostring(lo.numRequired or "-"),
            tostring(lo.type or "-"),
            tostring(lo.finished),
            tostring(lo.text or "-")
        )
    end

    local req = d.routeObjective
    local planText = "routeNeed=-"
    if req then
        planText = string.format(
            "chain=%s/%s routeNeed=%s:%s source=%s advance=%s",
            tostring(req.chainIndex or "-"),
            tostring(req.chainCount or "-"),
            joinIDs(req.questIDs),
            tostring(req.objectiveIndex or "-"),
            tostring(req.source or "-"),
            tostring(req.advance or "-")
        )
    end

    local rs = d.recommendedSegment
    local taskText = "task=-"
    if rs then
        taskText = string.format(
            "task=%s q=%s obj=%s complete=%s satisfied=%s text=%s",
            tostring(rs.questName or rs.kind or "-"),
            joinIDs(rs.questIDs),
            tostring(rs.objectiveIndex or "-"),
            tostring(rs.complete == true),
            tostring(rs.satisfied == true),
            tostring(rs.text or "-")
        )
    end

    return string.format(
        "route=%s module=%s step=%s seg=%s kind=%s quest=%s q=%s activeQ=%s obj=%s %s %s %s %s text=%s",
        tostring(d.routeId or "-"),
        tostring(d.moduleId or "-"),
        tostring(d.stepIndex or "-"),
        tostring(d.segmentIndex or "-"),
        tostring(d.kind or "-"),
        tostring(d.questName or "-"),
        joinIDs(d.questIDs),
        tostring(d.activeQuestID or "-"),
        tostring(d.objectiveIndex or "-"),
        targetText,
        objectiveText,
        planText,
        taskText,
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
