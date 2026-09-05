local BGA, Assert = ...

local function clock()
    local value = { now = 0 }
    function value:Now()
        return self.now
    end
    function value:Advance(seconds)
        self.now = self.now + seconds
    end
    return value
end

local function raw(itemRef, itemID)
    return {
        fullLink = itemRef.fullLink,
        itemID = itemID,
        itemGUID = itemRef.itemGUID,
        locationKey = itemRef.locationKey,
        inventoryType = "INVTYPE_FINGER",
        actualItemLevel = 300,
        itemClassID = 4,
        itemSubClassID = 0,
        statsComplete = true,
        stats = { strength = 0, crit = 10, haste = 10, mastery = 10, versatility = 10 },
        upgrade = { eligibility = false },
    }
end

local function port(mode)
    local value = { mode = mode or "manual", starts = 0, cancels = 0, callbacks = {}, reads = {} }
    function value:ReadResolved(itemRef)
        return { status = "ready", rawFields = self.reads[itemRef.fullLink] or raw(itemRef, tonumber(string.match(itemRef.fullLink, "item:(%d+)"))) }
    end
    function value:Load(itemRef, callback)
        self.starts = self.starts + 1
        self.callbacks[itemRef.fullLink] = callback
        if self.mode == "sync" then
            callback(true)
        end
        local active = true
        return function()
            if active then
                active = false
                self.cancels = self.cancels + 1
            end
        end
    end
    function value:Complete(link, success, reason)
        self.callbacks[link](success, reason)
    end
    return value
end

local function ref(id, guid, slot)
    return {
        fullLink = "item:" .. id .. "::::::::::::0:",
        itemGUID = guid,
        locationKey = "equipment:" .. slot,
    }
end

return {
    synchronous_cached_callback_is_delivered_once = function()
        local fakePort = port("sync")
        local repository = BGA.Application.ItemRepository.New(fakePort, clock())
        local publishes = 0
        repository:Resolve(ref(101, "a", 11), {}, function(result)
            publishes = publishes + 1
            Assert.Equal(result.status, "ready")
        end)
        Assert.Equal(publishes, 1)
        Assert.Equal(fakePort.starts, 1)
    end,

    two_waiters_coalesce_one_load = function()
        local fakePort = port("manual")
        local repository = BGA.Application.ItemRepository.New(fakePort, clock())
        local publishes = 0
        local itemRef = ref(101, "a", 11)
        repository:Resolve(itemRef, { view = 1 }, function() publishes = publishes + 1 end)
        repository:Resolve(itemRef, { view = 2 }, function() publishes = publishes + 1 end)
        Assert.Equal(fakePort.starts, 1)
        fakePort:Complete(itemRef.fullLink, true)
        Assert.Equal(publishes, 2)
    end,

    canceling_one_waiter_keeps_shared_load = function()
        local fakePort = port("manual")
        local repository = BGA.Application.ItemRepository.New(fakePort, clock())
        local first = 0
        local second = 0
        local itemRef = ref(101, "a", 11)
        local cancelFirst = repository:Resolve(itemRef, {}, function() first = first + 1 end)
        repository:Resolve(itemRef, {}, function() second = second + 1 end)
        cancelFirst()
        fakePort:Complete(itemRef.fullLink, true)
        Assert.Equal(first, 0)
        Assert.Equal(second, 1)
        Assert.Equal(fakePort.cancels, 0)
    end,

    duplicate_completion_is_idempotent = function()
        local fakePort = port("manual")
        local repository = BGA.Application.ItemRepository.New(fakePort, clock())
        local publishes = 0
        local itemRef = ref(101, "a", 11)
        repository:Resolve(itemRef, {}, function() publishes = publishes + 1 end)
        fakePort:Complete(itemRef.fullLink, true)
        fakePort:Complete(itemRef.fullLink, true)
        Assert.Equal(publishes, 1)
    end,

    timeout_is_typed_and_retryable = function()
        local fakeClock = clock()
        local fakePort = port("manual")
        local repository = BGA.Application.ItemRepository.New(fakePort, fakeClock, { timeoutSeconds = 5, failureRetrySeconds = 1 })
        local results = {}
        local itemRef = ref(101, "a", 11)
        repository:Resolve(itemRef, {}, function(result) results[#results + 1] = result end)
        fakeClock:Advance(5)
        repository:Tick()
        Assert.Equal(results[1].reasonCode, BGA.Core.ReasonCodes.ITEM_DATA_TIMEOUT)
        fakeClock:Advance(1)
        repository:Resolve(itemRef, {}, function(result) results[#results + 1] = result end)
        Assert.Equal(fakePort.starts, 2)
        fakePort:Complete(itemRef.fullLink, true)
        Assert.Equal(results[2].status, "ready")
    end,

    equipment_fanout_handles_all_synchronous_callbacks = function()
        local fakePort = port("sync")
        local itemRepository = BGA.Application.ItemRepository.New(fakePort, clock())
        local inventory = {}
        function inventory:CaptureEquippedRefs()
            return {
                equipmentRevision = 3,
                inventoryRevision = 4,
                materialEffectSignature = "fixture",
                refsBySlot = { [11] = ref(101, "a", 11), [12] = ref(102, "b", 12) },
            }
        end
        local equipment = BGA.Application.EquipmentRepository.New(inventory, itemRepository)
        local publishes = 0
        equipment:ResolveSnapshot({}, function(result)
            publishes = publishes + 1
            Assert.Equal(result.status, "ready")
            Assert.Equal(result.state.equipmentRevision, 3)
            Assert.Equal(result.state.aggregateStats.crit, 20)
        end)
        Assert.Equal(publishes, 1)
        Assert.Equal(fakePort.starts, 2)
    end,

    revisions_reject_old_tokens = function()
        local revisions = BGA.Application.Revisions.New()
        local token = revisions:Capture()
        Assert.True(revisions:Matches(token))
        revisions:Bump("equipment")
        Assert.Equal(revisions:Matches(token), false)
    end,
}
