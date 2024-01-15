function Plain(elem)
  local text = ''
  local contentTable = {}
  for i = 1, #elem.content do
    if elem.content[i].t == 'Str' then
      text = text .. elem.content[i].text
    elseif elem.content[i].t == 'Space' then
      text = text .. ' '
    elseif elem.content[i].t == 'SoftBreak' then
      text = text .. '\n'
    elseif elem.content[i].t == 'Link' then
      if elem.content[i].target:sub(1, 8) == 'https://'
          or elem.content[i].target:sub(1, 8) == 'http://' then
        for j = 1, #elem.content[i].content do
          if elem.content[i].content[j].t == 'Str' then
            text = text .. elem.content[i].content[j].text
          elseif elem.content[i].content[j].t == 'Space' then
            text = text .. ' '
          end
        end
        text = text .. ' (' .. elem.content[i].target .. ')'
      else
        table.insert(contentTable, pandoc.Str(text))
        table.insert(contentTable, elem.content[i])
        text = ''
      end
    end
  end
  if text ~= '' then
    table.insert(contentTable, pandoc.Str(text))
  end
  if #contentTable > 0 then
    elem.content = contentTable
  end
  return elem
end
