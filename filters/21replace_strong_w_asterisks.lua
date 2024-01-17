function Strong(elem)
  local text = ''  
  local elements = {}
  for i = 1, #elem.content do    
    if elem.content[i].t == 'Str' then
      text = text .. elem.content[i].text
    elseif elem.content[i].t == 'Space' then
      text = text .. ' '
    elseif elem.content[i].t == 'SoftBreak' then
      text = text .. '\n'
    else
      if text ~= '' then
        table.insert(elements, pandoc.Str(text))
        text = ''
      end
      table.insert(elements, elem.content[i])
    end
  end

  if text ~= '' then
    table.insert(elements, pandoc.Str(text))
  end

  if #elements ~= 0 then
    for i = 1, #elements do
      if elements[i].t == 'Str' then
        if elements[i].text:sub(1, 1) == '*' then
          elements[i].text = '* ' .. elements[i].text
        else 
          elements[i].text = '*' .. elements[i].text
        end
        break
      end
    end
    for i = #elements, 1, -1 do
      if elements[i].t == 'Str' then
        if elements[i].text:sub(#elements[i].text, #elements[i].text) == '*' then
          elements[i].text = elements[i].text .. ' *'
        else
          elements[i].text = elements[i].text .. '*'
        end
        break
      end
    end

    return elements
  end
end
