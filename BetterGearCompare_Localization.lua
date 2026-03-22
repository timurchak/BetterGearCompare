local _, ns = ...

local locale = GetLocale()
local strings = {}

ns.Locale = {
  current = locale,
  strings = strings,
}

function ns.Locale:AddTranslations(localeName, values)
  if localeName ~= "enUS" and localeName ~= locale then
    return
  end

  for key, value in pairs(values) do
    strings[key] = value
  end
end

ns.L = setmetatable({}, {
  __index = function(_, key)
    return strings[key] or key
  end,
})
