local _, BGA = ...

BGA.Domain = BGA.Domain or {}

local Result = BGA.Core.Result
local Reasons = BGA.Core.ReasonCodes
local EffectClassifier = BGA.Domain.EffectClassifier
local CandidateEnumerator = BGA.Domain.CandidateEnumerator
local StateValidator = BGA.Domain.StateValidator
local ModelRegistry = BGA.Domain.ModelRegistry
local OrdinaryModel = BGA.Domain.OrdinaryModel
local ConfidencePolicy = BGA.Domain.ConfidencePolicy

local GearEvaluator = {}
BGA.Domain.GearEvaluator = GearEvaluator

local function provenance(input, capability, model)
    return {
        clientBuild = input.clientBuild,
        addonVersion = input.artifactManifest and input.artifactManifest.addonVersion,
        artifactSetHash = input.artifactManifest and input.artifactManifest.artifactSetHash,
        capabilityID = capability and capability.archetypeID or input.context.archetypeID,
        modelID = capability and capability.modelID,
        modelHash = model and model.payloadHash,
        simcCommit = model and model.simcCommit,
        profileHash = model and model.profileHash,
        seasonManifestHash = input.artifactManifest and input.artifactManifest.seasonManifestHash,
        enhancementPolicyID = input.context.enhancementPolicyID,
    }
end

local function nonnumeric(status, reasonCodes, input, capability, model)
    return Result.New(status, {
        reasonCodes = reasonCodes,
        provenance = provenance(input, capability, model),
        future = { status = "unsupported", ranks = {} },
    })
end

local function retainedSlots(replacedSlots)
    if replacedSlots[1] == 11 then return { 12 } end
    if replacedSlots[1] == 12 then return { 11 } end
    return {}
end

local function scoreCandidate(input, snapshot, model, baselineLog)
    local classification = EffectClassifier.Classify(snapshot)
    if classification.status ~= "ordinary" then
        return {
            status = classification.status,
            reasonCodes = classification.reasonCodes,
        }
    end

    local enumeration = CandidateEnumerator.Enumerate(input.baseline, snapshot)
    if enumeration.status ~= "ok" then
        return { status = "unsupported", reasonCodes = enumeration.reasonCodes }
    end

    local validStates = {}
    local rejectedReasons = {}
    for index = 1, #enumeration.states do
        local candidateState = enumeration.states[index]
        local validation = StateValidator.Validate(candidateState)
        candidateState.validation = validation
        if validation.status == "valid" then
            validStates[#validStates + 1] = candidateState
        else
            rejectedReasons[#rejectedReasons + 1] = validation.reasonCodes[1]
        end
    end
    if #validStates == 0 then
        return { status = "unsupported", reasonCodes = rejectedReasons }
    end

    local alternatives = {}
    local winner
    for index = 1, #validStates do
        local candidateState = validStates[index]
        local candidateLog, candidateReason = OrdinaryModel.Evaluate(model, candidateState.state.aggregateStats)
        if candidateLog then
            local delta = OrdinaryModel.DeltaPercent(baselineLog, candidateLog)
            local alternative = {
                stateID = candidateState.id,
                replacedSlots = candidateState.replacedSlots,
                removedItemKeys = candidateState.removedItemKeys,
                deltaPercent = delta,
                candidateLogScore = candidateLog,
            }
            alternatives[#alternatives + 1] = alternative
            if not winner or candidateLog > winner.candidateLogScore then
                winner = alternative
            end
        else
            alternatives[#alternatives + 1] = {
                stateID = candidateState.id,
                replacedSlots = candidateState.replacedSlots,
                reasonCodes = { candidateReason },
            }
        end
    end
    if not winner then
        return { status = "unsupported", reasonCodes = { Reasons.OUT_OF_MODEL_DOMAIN } }
    end

    return {
        status = "scored",
        winner = winner,
        alternatives = alternatives,
    }
end

local function futureRanks(input, model, baselineLog, capability)
    local future = {
        status = input.futureStatus or "unsupported",
        ranks = {},
    }
    for index = 1, #(input.futureCandidates or {}) do
        local candidate = input.futureCandidates[index]
        local rankResult = {
            rank = candidate.rank,
            itemLevel = candidate.itemLevel,
        }
        if candidate.status ~= "verified" or not candidate.snapshot then
            rankResult.status = "unsupported"
            rankResult.reasonCodes = candidate.reasonCodes or { Reasons.UNVERIFIED_SEASON_DATA }
        else
            local scored = scoreCandidate(input, candidate.snapshot, model, baselineLog)
            if scored.status == "scored" then
                local winner = scored.winner
                local decision = ConfidencePolicy.Decide(
                    winner.deltaPercent,
                    model.uncertaintyPP,
                    model.materialityPP,
                    {
                        reasonCodes = {},
                        replacement = {
                            replacedSlots = winner.replacedSlots,
                            removedItemKeys = winner.removedItemKeys,
                            retainedSlots = retainedSlots(winner.replacedSlots),
                        },
                        alternatives = scored.alternatives,
                        provenance = provenance(input, capability, model),
                    }
                )
                rankResult.status = decision.status
                rankResult.deltaPercent = decision.deltaPercent
                rankResult.uncertaintyPercent = decision.uncertaintyPercent
                rankResult.materialityPercent = decision.materialityPercent
                rankResult.reasonCodes = decision.reasonCodes
                rankResult.replacement = decision.replacement
                if decision.status == "upgrade" and not future.firstConfirmedUpgradeRank then
                    future.firstConfirmedUpgradeRank = candidate.rank
                end
            else
                rankResult.status = scored.status == "special" and "special" or "unsupported"
                rankResult.reasonCodes = scored.reasonCodes
            end
        end
        future.ranks[#future.ranks + 1] = rankResult
    end
    table.sort(future.ranks, function(left, right) return left.rank < right.rank end)
    return future
end

function GearEvaluator.Evaluate(input)
    if not input or not input.baseline or not input.candidate or not input.context then
        return Result.New("unsupported", { reasonCodes = { Reasons.INVALID_EQUIPMENT_STATE } })
    end

    local classification = EffectClassifier.Classify(input.candidate)
    if classification.status == "pending" then
        return nonnumeric("pending", classification.reasonCodes, input)
    end
    if classification.status == "special" or classification.status == "unsupported" then
        return nonnumeric(classification.status, classification.reasonCodes, input)
    end

    local model, selectionReason, capability = ModelRegistry.Select(
        input.context,
        input.baseline,
        input.artifactManifest,
        input.capabilityManifest,
        input.models
    )
    if not model then
        return nonnumeric("unsupported", { selectionReason }, input, capability)
    end

    local baselineLog, baselineReason = OrdinaryModel.Evaluate(model, input.baseline.aggregateStats)
    if not baselineLog then
        return nonnumeric("unsupported", { baselineReason }, input, capability, model)
    end

    local scored = scoreCandidate(input, input.candidate, model, baselineLog)
    if scored.status ~= "scored" then
        return nonnumeric(scored.status, scored.reasonCodes, input, capability, model)
    end

    local winner = scored.winner

    return ConfidencePolicy.Decide(
        winner.deltaPercent,
        model.uncertaintyPP,
        model.materialityPP,
        {
            reasonCodes = {},
            baselineStateID = input.baseline.id,
            chosenStateID = winner.stateID,
            replacement = {
                replacedSlots = winner.replacedSlots,
                removedItemKeys = winner.removedItemKeys,
                retainedSlots = retainedSlots(winner.replacedSlots),
            },
            alternatives = scored.alternatives,
            future = futureRanks(input, model, baselineLog, capability),
            provenance = provenance(input, capability, model),
        }
    )
end
