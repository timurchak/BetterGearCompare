local _, BGA = ...

BGA.Generated = BGA.Generated or {}

-- Deliberately empty until the production generator and release validation are
-- implemented. Phase 0 manifests remain test evidence outside this addon tree.
BGA.Generated.SeasonManifest = {
    schema = 1,
    status = "unavailable",
    validationVerdict = "UNVALIDATED",
    wowBuild = nil,
    contentHash = nil,
    groups = {},
}
