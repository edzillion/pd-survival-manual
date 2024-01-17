function Str(elem)
  local str = elem.text:gsub("%*", "**")
  str = str:gsub("[—–]", "-")
  return pandoc.Str(str)
end

function RawBlock(elem)
  local str = elem.text:gsub("%*", "**")
  elem.text = str:gsub("[—–]", "-")
  return elem
end
