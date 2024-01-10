function Str(elem)
  local str = elem.text:gsub("%*", "**")
  str = elem.text:gsub("[—–]", "-")
  return pandoc.Str(str)
end
