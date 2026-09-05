# Upgrade-projection fixtures

`season-manifest.generated.json` is produced from Raidbots' documented, client-derived static files and cross-checked against the pinned build. It is supporting metadata, not proof that constructed links resolve in the WoW client.

Place unedited `Phase0UpgradeProbe.lua` SavedVariables captures in `client/`. The validator recognizes `.lua` only after they have also been exported as JSON from the addon or converted with a reviewed importer; do not invent expected outputs.

Required live categories:

- current-season ordinary armor;
- ring;
- neck;
- socketed current-season item;
- crafted item;
- old-season upgrade-track item;
- visually upgrade-like but presently ineligible item;
- at least one upgrade-vendor capture whose `upgradeLevelInfos` can be compared with projected links.

An empty `client/` directory means the spike remains `PARTIAL`.

