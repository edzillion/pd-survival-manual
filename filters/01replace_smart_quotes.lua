function Str(elem)
  local smartQuotesReplacements = {
    ["\226\128\156"] = "\"", -- “
    ["\226\128\157"] = "\"", -- ”
    ["\226\128\152"] = "\'", -- ‘
    ["\226\128\153"] = "\'"  -- ’
  }

  elem.text = elem.text:gsub("\226\128[\152\153\156\157]", smartQuotesReplacements)

  local ellipsis = utf8.char(0x2026) -- Unicode character for ellipsis (…)
  local bullet = utf8.char(0x2022)
  local unicodeReplacements = {
    [bullet] = "**",    -- Bullet character (•)
    [ellipsis] = "..." -- Ellipsis (…)
  }

  elem.text = elem.text:gsub(ellipsis, unicodeReplacements)
  elem.text = elem.text:gsub(bullet, unicodeReplacements)

  return elem
end
