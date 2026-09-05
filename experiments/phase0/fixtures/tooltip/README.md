# Tooltip lifecycle fixtures

The offline stress report proves only the revision/key algorithm. It does not prove Blizzard frame behavior, taint safety, or source coverage.

For live validation, copy the unedited `Phase0TooltipProbe.lua` SavedVariables file here and record the client build plus test checklist. Use `/p0c mark <source>` before each source group and `/p0c export` after the run.

Required sources: bags, equipped/character sheet, chat item link, loot, merchant, encounter journal where applicable, and comparison/shopping tooltips. Run with all non-Blizzard addons disabled and taint logging enabled.

