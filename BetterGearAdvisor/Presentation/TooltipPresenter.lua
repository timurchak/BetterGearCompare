local _, BGA = ...

BGA.Presentation = BGA.Presentation or {}

local TooltipPresenter = {}
BGA.Presentation.TooltipPresenter = TooltipPresenter

local colors = {
    neutral = { 0.65, 0.65, 0.65 },
    title = { 0.77, 0.65, 0.97 },
    upgrade = { 0.25, 0.95, 0.45 },
    downgrade = { 0.95, 0.35, 0.35 },
    close = { 0.95, 0.82, 0.30 },
    special = { 0.75, 0.45, 0.95 },
}

local function reasonText(result)
    return result.reasonCodes and result.reasonCodes[1] or nil
end

function TooltipPresenter.Signature(itemKey, result)
    return table.concat({
        itemKey,
        result.status,
        tostring(result.deltaPercent or ""),
        tostring(result.uncertaintyPercent or ""),
        result.chosenStateID or "",
        table.concat(result.reasonCodes or {}, ","),
        result.provenance and (result.provenance.artifactSetHash or result.provenance.addonVersion or "") or "",
    }, "|")
end

function TooltipPresenter.Render(tooltip, result, strings)
    if result.status == "pending" then
        tooltip:AddLine(strings.loading, unpack(colors.neutral))
        return
    end

    tooltip:AddLine(strings.title, unpack(colors.title))
    if result.status == "upgrade" or result.status == "downgrade" then
        local label = result.status == "upgrade" and ("▲ " .. strings.upgrade) or ("▼ " .. strings.downgrade)
        local color = result.status == "upgrade" and colors.upgrade or colors.downgrade
        tooltip:AddDoubleLine(label, string.format("%+.1f%% %s", result.deltaPercent, strings.modeledAoE), unpack(color))
    elseif result.status == "too_close" then
        tooltip:AddDoubleLine("≈ " .. strings.tooClose, string.format("%+.1f%%", result.deltaPercent), unpack(colors.close))
    elseif result.status == "special" then
        tooltip:AddLine("◆ " .. strings.special, unpack(colors.special))
        if reasonText(result) then tooltip:AddLine(reasonText(result), unpack(colors.neutral)) end
    else
        tooltip:AddLine("? " .. strings.unsupported, unpack(colors.neutral))
        if reasonText(result) then tooltip:AddLine(reasonText(result), unpack(colors.neutral)) end
    end

    if result.replacement and result.replacement.replacedSlots and result.replacement.replacedSlots[1] then
        tooltip:AddLine(strings.replaces .. ": slot " .. result.replacement.replacedSlots[1], unpack(colors.neutral))
    end
end
