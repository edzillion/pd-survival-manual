function BulletList(elem)
  for i = 1, #elem.content do
    local list = elem.content[i]
    for j = 1, #list do
      local listItem = list[j]
      local text = '** '
      local contentTable = {}
      for k = 1, #listItem.content do
        if listItem.content[k].t == 'Link' then
          if text ~= '** ' or text ~= '' then
            table.insert(contentTable, pandoc.Str(text))
            table.insert(contentTable, listItem.content[k])
            text = ''
          end
        elseif listItem.content[k].t == 'Str' then
          text = text .. listItem.content[k].text
        elseif listItem.content[k].t == 'Space' then
          text = text .. ' '
        end
      end
      if text ~= '' then
        table.insert(contentTable, pandoc.Str(text))
      end
      if #contentTable > 0 then
        listItem.content = contentTable
      end
    end
  end
  return elem
end
