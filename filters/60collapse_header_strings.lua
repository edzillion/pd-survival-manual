function Header(elem)
  local id = elem.attr.identifier
  local text = ''
  for i = 1, #elem.content do
    if elem.content[i].t == 'Str' then
      text = text .. elem.content[i].text
    elseif elem.content[i].t == 'Space' then
      text = text .. ' '
    elseif elem.content[i].t == 'SoftBreak' then
      text = text .. '\n'    
    end
  end
  if text ~= '' then
    elem.content = pandoc.Str(text)
  end
  return elem
end
