local _, BGA = ...

BGA.Application = BGA.Application or {}

local Result = BGA.Core.Result
local Reasons = BGA.Core.ReasonCodes

local EvaluationCoordinator = {}
EvaluationCoordinator.__index = EvaluationCoordinator
BGA.Application.EvaluationCoordinator = EvaluationCoordinator

function EvaluationCoordinator.New(dependencies)
    return setmetatable({
        revisions = dependencies.revisions,
        itemRepository = dependencies.itemRepository,
        equipmentRepository = dependencies.equipmentRepository,
        characterPort = dependencies.characterPort,
        evaluator = dependencies.evaluator,
        evaluationCache = dependencies.evaluationCache,
        artifactManifest = dependencies.artifactManifest,
        capabilityManifest = dependencies.capabilityManifest,
        models = dependencies.models or {},
        clientBuild = dependencies.clientBuild,
        futureRankResolver = dependencies.futureRankResolver,
        nextRequestID = 0,
        staleDiscardCount = 0,
    }, EvaluationCoordinator)
end

function EvaluationCoordinator:Request(itemRef, onPublish)
    self.nextRequestID = self.nextRequestID + 1
    local request = {
        id = self.nextRequestID,
        active = true,
        revisionToken = self.revisions:Capture(),
        context = self.characterPort:CaptureContext(),
        pending = 2,
        completed = {},
        cancellations = {},
    }

    onPublish(Result.New("pending", {
        reasonCodes = { Reasons.ITEM_DATA_PENDING },
        provenance = { enhancementPolicyID = request.context.enhancementPolicyID },
    }))

    local function cancelAll()
        for index = 1, #request.cancellations do
            if request.cancellations[index] then
                request.cancellations[index]()
            end
        end
    end

    local function completePart(part, result)
        if not request.active or request.completed[part] then
            return
        end
        request.completed[part] = true
        if not self.revisions:Matches(request.revisionToken) then
            request.active = false
            self.staleDiscardCount = self.staleDiscardCount + 1
            cancelAll()
            return
        end
        if result.status ~= "ready" then
            request.active = false
            cancelAll()
            onPublish(Result.New("unsupported", {
                reasonCodes = { result.reasonCode or Reasons.ITEM_DATA_FAILED },
                provenance = { enhancementPolicyID = request.context.enhancementPolicyID },
            }))
            return
        end
        request[part] = result
        request.pending = request.pending - 1
        if request.pending ~= 0 then
            return
        end

        local cacheKey = self.evaluationCache.Key(
            request.candidate.snapshot,
            request.equipment.state,
            request.context,
            self.artifactManifest
        )
        local cached = self.evaluationCache:Get(cacheKey)
        if cached then
            request.active = false
            onPublish(cached)
            return
        end

        local function evaluateAndPublish(futureResult)
            if not request.active then
                return
            end
            if not self.revisions:Matches(request.revisionToken) then
                request.active = false
                self.staleDiscardCount = self.staleDiscardCount + 1
                cancelAll()
                return
            end
            request.active = false
            local evaluated = self.evaluator.Evaluate({
                baseline = request.equipment.state,
                candidate = request.candidate.snapshot,
                context = request.context,
                artifactManifest = self.artifactManifest,
                capabilityManifest = self.capabilityManifest,
                models = self.models,
                clientBuild = self.clientBuild,
                futureStatus = futureResult and futureResult.status or "unsupported",
                futureCandidates = futureResult and futureResult.candidates or {},
            })
            self.evaluationCache:Put(cacheKey, evaluated)
            onPublish(evaluated)
        end

        if not self.futureRankResolver then
            evaluateAndPublish({ status = "unsupported", candidates = {} })
            return
        end
        request.cancellations[3] = self.futureRankResolver:Resolve(
            request.candidate.snapshot,
            request.revisionToken,
            function(token) return self.revisions:Matches(token) end,
            evaluateAndPublish
        )
    end

    -- Both dependency counts are initialized before either subscription. Both
    -- callbacks may run before Resolve/ResolveSnapshot returns.
    request.cancellations[1] = self.itemRepository:Resolve(itemRef, request.revisionToken, function(result)
        completePart("candidate", result)
    end)
    if request.active then
        request.cancellations[2] = self.equipmentRepository:ResolveSnapshot(request.revisionToken, function(result)
            completePart("equipment", result)
        end)
    end

    return function()
        if not request.active then
            return
        end
        request.active = false
        cancelAll()
    end
end
