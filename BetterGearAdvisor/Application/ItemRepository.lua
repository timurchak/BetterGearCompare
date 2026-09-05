local _, BGA = ...

BGA.Application = BGA.Application or {}

local Keys = BGA.Core.Keys
local Reasons = BGA.Core.ReasonCodes
local ItemSnapshot = BGA.Domain.ItemSnapshot

local ItemRepository = {}
ItemRepository.__index = ItemRepository
BGA.Application.ItemRepository = ItemRepository

local function noOp()
end

function ItemRepository.New(itemDataPort, clock, options)
    options = options or {}
    return setmetatable({
        itemDataPort = itemDataPort,
        clock = clock,
        timeoutSeconds = options.timeoutSeconds or 5,
        failureRetrySeconds = options.failureRetrySeconds or 1,
        entries = {},
        nextRequestID = 0,
        nextWaiterID = 0,
    }, ItemRepository)
end

function ItemRepository:_now()
    return self.clock:Now()
end

function ItemRepository:_dispatch(entry, result)
    local waiters = entry.waiters
    entry.waiters = {}
    for _, waiter in pairs(waiters) do
        if waiter.active then
            waiter.active = false
            waiter.callback(result)
        end
    end
end

function ItemRepository:_fail(entry, reason)
    if entry.state ~= "loading" and entry.state ~= "reading" then
        return
    end
    entry.state = "failed"
    entry.reasonCode = reason or Reasons.ITEM_DATA_FAILED
    entry.retryAfter = self:_now() + self.failureRetrySeconds
    local cancelLoad = entry.cancelLoad
    entry.cancelLoad = nil
    if cancelLoad then
        cancelLoad()
    end
    self:_dispatch(entry, { status = "failed", reasonCode = entry.reasonCode })
end

function ItemRepository:_complete(key, requestID, success, reasonCode)
    local entry = self.entries[key]
    if not entry or entry.requestID ~= requestID or entry.state ~= "loading" then
        return
    end
    if not success then
        self:_fail(entry, reasonCode or Reasons.ITEM_DATA_FAILED)
        return
    end

    entry.state = "reading"
    local readResult = self.itemDataPort:ReadResolved(entry.itemRef)
    if not readResult or readResult.status ~= "ready" then
        self:_fail(entry, readResult and readResult.reasonCode or Reasons.ITEM_DATA_FAILED)
        return
    end
    local snapshot, snapshotReason = ItemSnapshot.New(readResult.rawFields)
    if not snapshot then
        self:_fail(entry, snapshotReason)
        return
    end

    entry.state = "ready"
    entry.snapshot = snapshot
    entry.cancelLoad = nil
    self:_dispatch(entry, { status = "ready", snapshot = snapshot })
end

function ItemRepository:_start(key, itemRef)
    self.nextRequestID = self.nextRequestID + 1
    local requestID = self.nextRequestID
    local entry = {
        state = "loading",
        key = key,
        itemRef = itemRef,
        requestID = requestID,
        deadline = self:_now() + self.timeoutSeconds,
        waiters = {},
    }
    self.entries[key] = entry

    local cancelLoad = self.itemDataPort:Load(itemRef, function(success, reasonCode)
        self:_complete(key, requestID, success, reasonCode)
    end)
    if entry.state == "loading" then
        entry.cancelLoad = cancelLoad
    end
    return entry
end

function ItemRepository:Resolve(itemRef, waiterToken, callback)
    local key = Keys.ItemSnapshotKey(itemRef.fullLink, itemRef.itemGUID, itemRef.locationKey)
    local entry = self.entries[key]
    if entry and entry.state == "ready" then
        callback({ status = "ready", snapshot = entry.snapshot })
        return noOp
    end
    if entry and entry.state == "failed" then
        if self:_now() < entry.retryAfter then
            callback({ status = "failed", reasonCode = entry.reasonCode })
            return noOp
        end
        self.entries[key] = nil
        entry = nil
    end
    if not entry then
        entry = self:_start(key, itemRef)
    end

    self.nextWaiterID = self.nextWaiterID + 1
    local waiterID = self.nextWaiterID
    local waiter = { id = waiterID, token = waiterToken, callback = callback, active = true }
    entry.waiters[waiterID] = waiter

    -- A load callback is allowed to run synchronously. If it completed before
    -- this waiter was attached, deliver the already materialized result now.
    if entry.state == "ready" then
        entry.waiters[waiterID] = nil
        waiter.active = false
        callback({ status = "ready", snapshot = entry.snapshot })
        return noOp
    elseif entry.state == "failed" then
        entry.waiters[waiterID] = nil
        waiter.active = false
        callback({ status = "failed", reasonCode = entry.reasonCode })
        return noOp
    end

    return function()
        if not waiter.active then
            return
        end
        waiter.active = false
        entry.waiters[waiterID] = nil
        if entry.state == "loading" and next(entry.waiters) == nil then
            if entry.cancelLoad then
                entry.cancelLoad()
            end
            self.entries[key] = nil
        end
    end
end

function ItemRepository:Tick()
    local now = self:_now()
    for _, entry in pairs(self.entries) do
        if (entry.state == "loading" or entry.state == "reading") and now >= entry.deadline then
            self:_fail(entry, Reasons.ITEM_DATA_TIMEOUT)
        end
    end
end

function ItemRepository:InvalidateOwned(key)
    local entry = self.entries[key]
    if entry and entry.cancelLoad then
        entry.cancelLoad()
    end
    self.entries[key] = nil
end
