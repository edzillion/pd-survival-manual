import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics

import "playout"

local mdTree = {}
-- private methods
local mdTreeMethods = {}

local settings = {
  linksEnabled = true
}

HTML_TO_PLAYOUT_PROPS = {
  cellpadding = 'padding',
  cellspacing = 'spacing',
  valign = 'vAlign',
  bgcolor = 'backgroundColor'
}

HTML_TO_PLAYOUT_VALS = {
  top = playout.kAlignStart,
  bottom = playout.kAlignEnd,
  center = playout.kAlignCenter
}

PANDOC_TO_PLAYOUT_VALS = {
  AlignLeft = playout.kAlignStart,
  AlignCenter = playout.kAlignCenter,
  AlignRight = playout.kAlignEnd,
  AlignDefault = playout.kAlignCenter
}

mdTree.new = function(styles, treeEntry)
  local mdt = {
    styles = styles,
    tree = nil,
    treeSprite = nil,
    treeData = treeEntry
  }
  local tree = setmetatable(mdt, { __index = mdTreeMethods })
  return tree
end

function mdTreeMethods:build()
  -- build tree
  self.tree = playout.tree:build(self, self.createTree, self.treeData)
  if settings.linksEnabled then
    self.tree:computeTabIndex()
  end

  self.treeSprite = gfx.sprite.new(self.tree:draw())
  local treeRect  = self.treeSprite:getBoundsRect()
  local anchor    = playout.getRectAnchor(treeRect, playout.kAnchorTopLeft)

  self.treeSprite:moveTo(-anchor.x, -anchor.y)
  self.treeSprite:add()
  return self
end

function mdTreeMethods.createTree(self, ui, treeEntry)
  local box = ui.box
  local image = ui.image
  local text = ui.text

  local links = {}
  local anchors = {}

  local root = box(self.styles.Root)
  local lastNode = root
  local lastBlock

  local blockCounter = 1

  print('creating tree for ' .. treeEntry.name)

  -- __.each(treeEntry.json.blocks, function(block)
  --   blockCounter = blockCounter + 1
  --   print(blockCounter, block.t)

  --   if block.t == 'BlockQuote' then
  --     local boxNode = box(self.styles[block.t] or nil)
  --     __.each(block.c, function(subBlock)
  --       if subBlock.t == 'Para' or subBlock.t == 'Plain' then
  --         for i = 1, #subBlock.c do
  --           if subBlock.c[i].t == 'Str' then
  --             local textNode = text(subBlock.c[i].c)
  --             boxNode:appendChild(textNode)
  --           end
  --         end
  --       end
  --     end)
  --     root:appendChild(boxNode)
  --     lastBlock = 'BlockQuote'
  --     lastNode = boxNode
  --   elseif block.t == 'Plain' then
  --     if lastBlock ~= 'Plain' then
  --       local boxNode = box(self.styles[block.t] or nil)
  --       for i = 1, #block.c do
  --         if block.c[i].t == 'Str' then
  --           local textNode = text(block.c[i].c)
  --           boxNode:appendChild(textNode)
  --         end
  --       end
  --       root:appendChild(boxNode)
  --       lastBlock = 'Plain'
  --       lastNode = boxNode
  --     else
  --       for i = 1, #block.c do
  --         if block.c[i].t == 'Str' then
  --           local textNode = text(block.c[i].c)
  --           lastNode:appendChild(textNode)
  --         end
  --       end
  --     end
  --   elseif block.t == 'Para' then
  --     if lastBlock ~= 'Para' then
  --       local boxNode = box(self.styles[block.t] or nil)
  --       for i = 1, #block.c do
  --         if block.c[i].t == 'Str' then
  --           local textNode = text(block.c[i].c)
  --           boxNode:appendChild(textNode)
  --           root:appendChild(boxNode)
  --           lastBlock = 'Para'
  --           lastNode = boxNode
  --         elseif block.c[i].t == 'RawInline' then
  --           if block.c[i].c[1] == 'html' and block.c[i].c[2]:sub(1, 3) == '<a ' then
  --             table.insert(anchors, block.c[i].c[2])
  --           elseif block.c[i].c[2] == '</a>' then
  --             --end anchor
  --           else
  --             local debug
  --           end
  --         elseif block.c[i].t == 'Image' then
  --           local imgPath = block.c[i].c[3][1]
  --           local img = gfx.image.new(imgPath)
  --           local imageBlock = image(img)
  --           boxNode:appendChild(imageBlock)
  --         elseif block.c[i].t == 'Link' then
  --           local strings = __.pluck(block.c[i].c[2], 'c')
  --           local linkText = __.join(strings, ' ')
  --           local linkLocation = block.c[i].c[3][1]
  --           table.insert(links, { text = linkText, location = linkLocation })
  --           boxNode:appendChild(text(linkText))
  --           root:appendChild(boxNode)
  --           lastBlock = 'Para'
  --           lastNode = boxNode
  --         else
  --           local d
  --         end
  --       end
  --       -- boxNode:appendChild(textNode)
  --       -- root:appendChild(boxNode)
  --       -- lastBlock = 'Para'
  --       -- lastNode = boxNode
  --     else
  --       for i = 1, #block.c do
  --         if block.c[i].t == 'Str' then
  --           local textNode = text(block.c[i].c)
  --           lastNode:appendChild(textNode)
  --         elseif block.c[i].t == 'Link' then
  --           local strings = __.pluck(block.c[i].c[2], 'c')
  --           local linkText = __.join(strings, ' ')
  --           local linkLocation = block.c[i].c[3][1]
  --           table.insert(links, { text = linkText, location = linkLocation })
  --           lastNode.children[#lastNode.children].text = lastNode.children[#lastNode.children].text .. linkText
  --         end
  --       end
  --     end
  --   elseif block.t == 'Header' then
  --     local headerStyle = block.t .. block.c[1] --Header1, Header2 etc.
  --     local boxNode = box(self.styles[headerStyle] or nil)
  --     if block.c[3][1].t == 'Link' then
  --       local strings = __.pluck(block.c[3][1].c[2], 'c')
  --       local linkText = __.join(strings, ' ')
  --       local linkLocation = block.c[3][1].c[3][1]
  --       table.insert(links, { text = linkText, location = linkLocation })
  --       boxNode:appendChild(text(linkText, { target = linkLocation, tabIndex = #links }))
  --       root:appendChild(boxNode)
  --     elseif block.c[3][1].t == 'Str' then
  --       local textNode = text(block.c[3][1].c)
  --       boxNode:appendChild(textNode)
  --       root:appendChild(boxNode)
  --       lastBlock = 'Header'
  --       lastNode = boxNode
  --     end
  --   elseif block.t == 'Image' then
  --     local debug
  --     lastBlock = 'Image'
  --     --lastNode = boxNode
  --   elseif block.t == 'BulletList' then
  --     local boxNode = box(self.styles[block.t] or nil)
  --     local listItems = {}
  --     for i = 1, #block.c do
  --       for j = 1, #block.c[i] do
  --         if block.c[i][j].t == 'Plain' then
  --           for k = 1, #block.c[i][j].c do
  --             if block.c[i][j].c[k].t == 'Str' then
  --               table.insert(listItems, block.c[i][j].c[k].c)
  --             end
  --           end
  --         end
  --       end
  --     end
  --     local textNode = text(__.join(listItems, '\n'))
  --     boxNode:appendChild(textNode)
  --     root:appendChild(boxNode)
  --     lastBlock = 'BulletList'
  --     lastNode = boxNode
  --   end
  -- end)


  local function hexToGrey(hex_string)
    -- Convert hex to RGB
    local r = tonumber(string.sub(hex_string, 2, 3), 16)
    local g = tonumber(string.sub(hex_string, 4, 5), 16)
    local b = tonumber(string.sub(hex_string, 6, 7), 16)
    -- Convert to grayscale using the formula gray = 0.3*red + 0.59*green + 0.11*blue
    local gray = 0.3 * r + 0.59 * g + 0.11 * b
    -- Normalize to range [0, 1]
    gray = gray / 255
    return gray
  end

  local parseAndAddToTree = function(block, boxNode)
    local nodeToAdd = parseFunctions[block.t](block)
    if nodeToAdd ~= nil then
      boxNode:appendChild(nodeToAdd)
    end
    return boxNode
  end

  local function extractProps(tagString)
    local properties = {}
    for property, value in tagString:gmatch('(%a+)%s-=%s-"(.-)"') do
      if string.match(value, "^%d+$") then
        value = tonumber(value)
      end
      properties[HTML_TO_PLAYOUT_PROPS[property] or property] = HTML_TO_PLAYOUT_VALS[value] or value
    end
    if properties.backgroundColor and properties.backgroundColor:sub(1, 1) == '#' then
      local grey = hexToGrey(properties.backgroundColor)
      properties.backgroundColor = grey > 0.5 and gfx.kColorBlack or gfx.kColorWhite
      properties.backgroundAlpha = grey > 0.5 and 1 - grey or grey
    end
    return properties
  end



  local tableNode
  local tableRowNode
  local tableColNode
  local lastNode
  local tableBuffer = {}

  parseFunctions = {
    BlockQuote = function(blockQuote)
      print('BlockQuote')
      local boxNode = box(self.styles[blockQuote.t] or nil)
      __.each(blockQuote.c, function(subBlock)
        boxNode = parseAndAddToTree(subBlock, boxNode)
      end)
      return boxNode
    end,
    BulletList = function(bulletList)
      print('BulletList')
      if countcounter == 14 then
        local d
      end
      local boxNode = box(self.styles[bulletList.t] or nil)

      local listItems = {}
      local listString = ''
      for i = 1, #bulletList.c do
        for j = 1, #bulletList.c[i] do
          local bl = bulletList.c[i][j]
          boxNode = parseAndAddToTree(bl, boxNode)
          -- table.insert(listItems, )
          -- if block.c[i][j].t == 'Plain' then
          --   for k = 1, #block.c[i][j].c do
          --     if block.c[i][j].c[k].t == 'Str' then
          --       table.insert(listItems, block.c[i][j].c[k].c)
          --     end
          --   end
          -- end
        end
      end
      local listStrings = __.reduce(boxNode.children, {}, function(memo, node)
        __.each(node.children, function(subNode)
          if subNode.properties.tabIndex ~= nil then
            if subNode.properties.target:sub(1, 8) == 'https://' or
                subNode.properties.target:sub(1, 7) == 'http://' then
              -- external link, just print it's url string
              local textnow = memo[#memo] .. subNode.text .. ' (' .. subNode.properties.target .. ')'
              memo[#memo] = textnow
            end
            local debug
          else
            table.insert(memo, subNode.text)
          end
          -- if memo[#memo] and memo[#memo].text and subNode.text then
          --   memo[#memo].text = memo[#memo].text .. subNode.text .. '\n'
          -- elseif subNode.text then

          -- else
          --   local debug
          -- end
        end)
        return memo
      end)
      -- local listItemString = __.join(mapped, '\n')
      boxNode.children = { text(__.join(listStrings, '\n')) }

      if tableColNode ~= nil then
        tableColNode:appendChild(boxNode)
      else
        return boxNode
      end
    end,
    Header = function(header)
      print('Header')
      local headerStyle = header.t .. header.c[1] --Header1, Header2 etc.
      local boxNode = box(self.styles[headerStyle] or nil)
      return parseAndAddToTree(header.c[3][1], boxNode)
    end,
    HorizontalRule = function(horizR)
      return box({ width = 380, height = 3, borderTop = 3 })
    end,
    Image = function(img)
      print('Image')
      local imgPath = img.c[3][1]
      local img = gfx.image.new(imgPath)
      local imageBlock = image(img)
      return imageBlock
    end,
    Link = function(link)
      print('Link')
      local strings = __.pluck(link.c[2], 'c')
      local linkText = __.join(strings, ' ')
      local linkLocation = link.c[3][1]
      table.insert(links, { text = linkText, location = linkLocation })
      local textNode = text(linkText, { target = linkLocation, tabIndex = #links })
      return textNode
      -- boxNode:appendChild(text(linkText, { target = linkLocation, tabIndex = #links }))
      -- root:appendChild(boxNode)
    end,
    OrderedList = function(ordList)
      print('OrderedList')
      local boxNode = box(self.styles[ordList.t] or nil)

      local listItems = {}
      local listString = ''

      local listStart = ordList.c[1][1]
      local listStyle = ordList.c[1][2].t
      local liotDelim = ordList.c[1][3].t

      for i = 1, #ordList.c[2] do
        boxNode = parseAndAddToTree(ordList.c[2][i][1], boxNode)
        -- table.insert(listItems, )
        -- if block.c[i][j].t == 'Plain' then
        --   for k = 1, #block.c[i][j].c do
        --     if block.c[i][j].c[k].t == 'Str' then
        --       table.insert(listItems, block.c[i][j].c[k].c)
        --     end
        --   end
        -- end
      end
      local ordCounter = 1

      local listStrings = __.reduce(boxNode.children, {}, function(memo, node)
        __.each(node.children, function(subNode)
          if subNode.properties.tabIndex ~= nil then
            if subNode.properties.target:sub(1, 8) == 'https://' or
                subNode.properties.target:sub(1, 7) == 'http://' then
              -- external link, just print it's url string
              local textnow = memo[#memo] .. subNode.text .. ' (' .. subNode.properties.target .. ')'
              memo[#memo] = textnow
            end
            local debug
          else
            table.insert(memo, ordCounter .. '.' .. subNode.text)
            ordCounter = ordCounter + 1
          end
          -- if memo[#memo] and memo[#memo].text and subNode.text then
          --   memo[#memo].text = memo[#memo].text .. subNode.text .. '\n'
          -- elseif subNode.text then

          -- else
          --   local debug
          -- end
        end)
        return memo
      end)
      -- local listItemString = __.join(mapped, '\n')
      boxNode.children = { text(__.join(listStrings, '\n')) }

      if tableColNode ~= nil then
        tableColNode:appendChild(boxNode)
      else
        return boxNode
      end
    end,
    Para = function(para)
      print('Para')
      local boxNode = box(self.styles[para.t] or nil)
      -- local nodesToAdd = {}
      -- local textNode
      __.each(para.c, function(subBlock)
        local node = parseFunctions[subBlock.t](subBlock)
        boxNode:appendChild(node)
      end)
      -- if __.any(boxNode.children, function(child) return child.properties.tabIndex ~= nil end) then
      --   local text = __.join(boxNode.children, function (child)
      --     child.text
      --   end)
      --   boxNode.children =
      -- end
      if tableColNode ~= nil then
        tableColNode:appendChild(boxNode)
      else
        return boxNode
      end
    end,
    Plain = function(plain)
      print('Plain')
      local boxNode = box(self.styles[plain.t] or nil)
      __.each(plain.c, function(subBlock)
        boxNode = parseAndAddToTree(subBlock, boxNode)
      end)
      return boxNode
    end,
    Str = function(str)
      local textNode = text(str.c)
      return textNode
      -- boxNode:appendChild(textNode)
      -- root:appendChild(boxNode)
      -- lastheader = 'Header'
      -- lastNode = boxNode
    end,
    RawBlock = function(rawB)
      if rawB.c[1] == 'html' then
        if rawB.c[2]:sub(1, 6) == '<table' then
          print('Table')

          local props = extractProps(rawB.c[2])
          tableNode = box(self.styles.Table or props or nil)
          return tableNode
        elseif rawB.c[2]:sub(1, 8) == '</table>' then
          tableNode = nil
          tableRowNode = nil
          tableColNode = nil
        elseif rawB.c[2]:match('^<%/?t[hrd]') then
          local tableTag = rawB.c[2]
          local props = extractProps(rawB.c[2])
          print('parsing ' .. tableTag)
          local node = box(props or nil)
          if tableTag:sub(1, 3) == '<tr' then
            -- table.insert(tableBuffer[#tableBuffer].children, node)
            tableRowNode = node
          elseif tableTag:sub(1, 5) == '</tr>' then
            tableNode:appendChild(tableRowNode)
            tableRowNode = nil
          elseif tableTag:sub(1, 3) == '<td' then
            tableColNode = node
          elseif tableTag:sub(1, 5) == '</td>' then
            tableRowNode:appendChild(tableColNode)
            tableColNode = nil
          elseif tableTag:sub(1, 3) == '<th' then
            tableColNode = node
          elseif tableTag:sub(1, 5) == '</th>' then
            tableRowNode:appendChild(tableColNode)
            tableColNode = nil
          end
        end
      end
    end,
    RawInline = function(rawI)
      local boxNode = box()
      if rawI.c[2]:sub(1, 3) == '<a ' then
        -- anchor, add id to props
        boxNode.properties.id = rawI.c[2]:match('<a%s+name%s-=%s-"(.-)"')
      elseif rawI.c[2] == '</a>' then
        --end anchor
      else
        boxNode = parseAndAddToTree(rawI, boxNode)
      end
      return boxNode
    end,
    Table = function(pandocTable)
      print('Table')
      local attr = pandocTable.c[1]
      local boxNode = box(self.styles.Table or { maxWidth = 380 })

      local caption = pandocTable.c[2]
      local colspecs = pandocTable.c[3]
      local head = pandocTable.c[4]
      local bodies = pandocTable.c[5]
      local foot = pandocTable.c[6]

      local colProps = {}

      for i = 1, #colspecs do
        local prop = {
          direction = playout.kDirectionVertical,
          hAlign = PANDOC_TO_PLAYOUT_VALS[colspecs[i][1].t],
          vAlign = playout.kAlignStretch,
          border = 1
        }
        -- TODO: 380 should be max width of the parent
        if colspecs[i][2].t ~= 'ColWidthDefault' then
          prop.width = colspecs[i][2].c * 380
        end
        table.insert(colProps, prop)
      end


      local headAttr = head[1]
      local headRows = head[2]
      if headRows then
        for i = 1, #headRows do
          local rowNode = box({ direction = playout.kDirectionHorizontal, vAlign = playout.kAlignStretch, maxWidth = 380 })
          local rowAttr = headRows[i][1]
          local cells = headRows[i][2]
          for j = 1, #cells do
            local cellNode = box(colProps[j])
            local cell = cells[j]
            local cellAttr = cell[1]
            local cellAlign = cell[2]
            local colSpan = cell[3]
            local rowSpan = cell[4]
            local cellContents = cell[5]
            if #cellContents == 0 then
              local node = text('')
              cellNode:appendChild(node)
            else
              for l = 1, #cellContents do
                local node = text(cellContents[l].c[1].c)
                cellNode:appendChild(node)
              end
            end
            rowNode:appendChild(cellNode)

            -- for k = 1, #cellContents do
            --   local node = parseFunctions[cellContents[k].t](cellContents[k])
            --   for key, val in pairs(colProps[k]) do
            --     node.properties[key] = val
            --   end
            --   -- TODO: merge props here from colProps
            --   rowNode:appendChild(node)
            -- end
          end
          boxNode:appendChild(rowNode)
        end
      end


      for i = 1, #bodies do
        local bodyAttr = bodies[i][1]
        local row_head_columns = bodies[i][2]
        local headRows = bodies[i][3]
        local bodyRows = bodies[i][4]
        if bodyRows then
          for j = 1, #bodyRows do
            local rowNode = box({ direction = playout.kDirectionHorizontal, maxWidth = 380 })
            local rowAttr = bodyRows[j][1]
            local cells = bodyRows[j][2]
            for k = 1, #cells do
              local cellNode = box(colProps[k])
              local cell = cells[k]
              local cellAttr = cell[1]
              local cellAlign = cell[2]
              local colSpan = cell[3]
              local rowSpan = cell[4]
              local cellContents = cell[5]
              if #cellContents == 0 then
                local node = text('')
                cellNode:appendChild(node)
              else
                for l = 1, #cellContents do
                  local node = text(cellContents[l].c[1].c)
                  cellNode:appendChild(node)
                end
              end
              rowNode:appendChild(cellNode)
              -- colProps[1].flex = nil
              -- colProps[2].flex = nil
              -- colProps[1].width = 100
              -- colProps[2].width = 200
              -- if j == 4 then
              --   local debug
              -- end
              -- for k = 1, #cellContents do

              --   local node = parseFunctions[cellContents[k].t](cellContents[k])

              --   -- TODO: merge props here from colProps
              --   row:appendChild(node)
              -- end
            end
            boxNode:appendChild(rowNode)
          end
        end
      end
      local d
      return boxNode
    end
  }

  countcounter = 0
  local function walkTree(treeNodes)
    for i = 1, #treeNodes do
      countcounter = i
      local node = treeNodes[i]
      print(i, node.t)
      lastNode = parseFunctions[node.t](node)
      if lastNode then
        root:appendChild(lastNode)
      end
    end
  end

  walkTree(treeEntry.json.blocks)

  return root
end

function mdTreeMethods:update(crankChange, offset)
  if crankChange ~= 0 or offset ~= 0 then
    local treePosition = { x = self.treeSprite.x, y = self.treeSprite.y }
    if self.tree.scrollTarget then
      if self.tree.scrollTarget.properties.direction == playout.kDirectionHorizontal then
        treePosition.x = (self.treeSprite.width / 2) + offset
      else
        treePosition.y = (self.treeSprite.height / 2) + offset
      end
    end

    self.treeSprite:moveTo(treePosition.x, treePosition.y)
  end
  self.treeSprite:update()

  playdate.timer.updateTimers()
  playdate.drawFPS()
end

return mdTree
