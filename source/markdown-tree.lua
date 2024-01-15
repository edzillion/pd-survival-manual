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

local buildCoroutine

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

function mdTreeMethods:build(callback)
  log.info('Building Tree for ' .. self.treeData.name)
  self.tree = playout.tree:build(self, self.createTree, self.treeData)
  if settings.linksEnabled then
    self.tree:computeTabIndex()
  end

  self.treeSprite = gfx.sprite.new(self.tree:draw())
  local treeRect  = self.treeSprite:getBoundsRect()
  local anchor    = playout.getRectAnchor(treeRect, playout.kAnchorTopLeft)

  self.treeSprite:moveTo(-anchor.x, -anchor.y)
  self.treeSprite:add()
  -- buildCoroutine = nil
  log.info('Tree successfully built for ' .. self.treeData.name .. ', calling callback()')
  callback(self)
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

  local parseNode = function(node)
    log.info('Parsing node ' .. node.t)
    local n = parseFunctions[node.t](node)
    coroutine.yield(BuildTreeRoutine)
    return n
  end

  local parseAndAddToTree = function(block, boxNode)
    local nodeToAdd = parseNode(block)
    if nodeToAdd ~= nil then
      log.info('Adding node ' .. block.t)
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
      properties.backgroundColor = grey > 0.5 and gfx.kColorWhite or gfx.kColorBlack
      properties.backgroundAlpha = grey > 0.5 and 1 - grey or grey
    end
    if properties.color and properties.color:sub(1, 1) == '#' then
      local grey = hexToGrey(properties.color)
      properties.color = grey > 0.5 and gfx.kColorWhite or gfx.kColorBlack
    end
    return properties
  end

  local tableNode
  local tableRowNode
  local tableColNode
  local lastNode
  local tableProps
  local textProps

  parseFunctions = {
    BlockQuote = function(blockQuote)
      local boxNode = box(self.styles[blockQuote.t] or nil)
      __.each(blockQuote.c, function(subBlock)
        boxNode = parseAndAddToTree(subBlock, boxNode)
      end)
      return boxNode
    end,
    BulletList = function(bulletList)
      local st = self.styles[bulletList.t]

      local boxNode = box(st or nil)

      local listItems = {}
      local listString = ''
      for i = 1, #bulletList.c do
        for j = 1, #bulletList.c[i] do
          local block = bulletList.c[i][j]
          local nodeToAdd = parseNode(block)
          if nodeToAdd ~= nil then
            table.insert(listItems, nodeToAdd)
          end

          -- boxNode = parseAndAddToTree(bl, boxNode)
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


      local listTextBuffer = ''
      __.each(listItems, function(node)
        __.each(node.children, function(subNode)
          if subNode.properties.tabIndex == nil then
            listTextBuffer = listTextBuffer .. subNode.text
          else
            if subNode.properties.target:sub(1, 8) == 'https://' or
                subNode.properties.target:sub(1, 7) == 'http://' then
              -- external link, just print it's url string
              listTextBuffer = listTextBuffer .. subNode.text .. ' (' .. subNode.properties.target .. ')'
            else
              subNode.text = listTextBuffer .. subNode.text
              boxNode:appendChild(subNode)
              listTextBuffer = ''
              -- table.insert(links, { text = linkText, location = linkLocation })
              -- local textNode = text(linkText, { target = linkLocation, tabIndex = #links })
            end

            local debug
          end
          -- if memo[#memo] and memo[#memo].text and subNode.text then
          --   memo[#memo].text = memo[#memo].text .. subNode.text .. '\n'
          -- elseif subNode.text then

          -- else
          --   local debug
          -- end
          -- if listTextBuffer ~= '' then
          --   listTextBuffer = listTextBuffer .. '\n'
          -- end
        end)
        if listTextBuffer ~= '' then
          listTextBuffer = listTextBuffer .. '\n'
        end
        local debug
      end)

      if listTextBuffer ~= '' then
        boxNode:appendChild(text(listTextBuffer))
        -- local listItemString = __.join(mapped, '\n')
        -- boxNode.children = { text(__.join(listStrings, '\n')) }
      end

      if tableColNode ~= nil then
        tableColNode:appendChild(boxNode)
      else
        return boxNode
      end
    end,
    Header = function(header)
      local headerStyleName = header.t .. header.c[1] --Header1, Header2 etc.
      local headerStyle = self.styles[headerStyleName] or nil
      local boxNode = box(headerStyle)

      if header.c[2][1] ~= nil and string.len(header.c[2][1]) > 0 then
        --has an anchor
        boxNode.properties.id = header.c[2][1]
      end

      return parseAndAddToTree(header.c[3][1], boxNode)
    end,
    HorizontalRule = function(horizR)
      return box({ width = 380, height = 3, borderTop = 3 })
    end,
    Image = function(img)
      local imgPath = img.c[3][1]
      local img = gfx.image.new(imgPath)
      local imageBlock = image(img)
      return imageBlock
    end,
    Link = function(link)
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
      local boxNode = box(self.styles[ordList.t] or nil)

      local listStart = ordList.c[1][1]
      local listStyle = ordList.c[1][2].t
      local listDelim = ordList.c[1][3].t

      local function addDelim(listNum, listDelim)
        if listDelim == 'DefaultDelim' or listDelim == 'Period' then
          return listNum .. '.'
        elseif listDelim == 'OneParen' then
          return listNum .. '(' .. listNum .. ')'
        elseif listDelim == 'TwoParens' then
          return listNum .. '((' .. listNum .. '))'
        end
      end

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
      local ordCounter = listStart

      local listStrings = __.reduce(boxNode.children, {}, function(memo, node)
        __.each(node.children, function(subNode)
          if subNode.properties.tabIndex ~= nil then
            if subNode.properties.target:sub(1, 8) == 'https://' or
                subNode.properties.target:sub(1, 7) == 'http://' then
              -- external link, just print it's url string
              local textnow = memo[#memo] .. subNode.text .. ' (' .. subNode.properties.target .. ')'
              memo[#memo] = textnow
            end
          else
            table.insert(memo, addDelim(ordCounter, listDelim) .. subNode.text)
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
      local boxNode = box(self.styles[para.t] or nil)
      -- local nodesToAdd = {}
      -- local textNode
      __.each(para.c, function(subBlock)
        local node = parseNode(subBlock)
        boxNode:appendChild(node)
      end)
      -- if __.any(boxNode.children, function(child) return child.properties.tabIndex ~= nil end) then
      --   local text = __.join(boxNode.children, function (child)
      --     child.text
      --   end)
      --   boxNode.children =
      -- end
      if tableColNode ~= nil then
        for k, v in pairs(tableProps) do
          boxNode.properties[k] = v
        end
        tableColNode:appendChild(boxNode)
      else
        return boxNode
      end
    end,
    Plain = function(plain)
      local boxNode = box(self.styles[plain.t] or nil)
      __.each(plain.c, function(subBlock)
        boxNode = parseAndAddToTree(subBlock, boxNode)
      end)
      return boxNode
    end,
    Str = function(str)
      if str.c:sub(1, 5) == '{#toc' then
        return
      end
      local textNode = text(str.c, textProps or nil)
      return textNode
      -- boxNode:appendChild(textNode)
      -- root:appendChild(boxNode)
      -- lastheader = 'Header'
      -- lastNode = boxNode
    end,
    RawBlock = function(rawB)
      if rawB.c[1] == 'html' then
        if rawB.c[2]:sub(1, 6) == '<table' then
          local props = extractProps(rawB.c[2])
          tableNode = box(self.styles.Table or props or nil)
          return tableNode
        elseif rawB.c[2]:sub(1, 8) == '</table>' then
          tableNode = nil
          tableRowNode = nil
          tableColNode = nil
        elseif rawB.c[2]:match('^<%/?t[hrd]') then
          local tableTag = rawB.c[2]
          tableProps = extractProps(rawB.c[2]) or nil
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
      elseif rawI.c[2]:sub(1, 11) == '<font color' then
        textProps = extractProps(rawI.c[2])
      elseif rawI.c[2] == '</font>' then
        textProps = nil
      else
        boxNode = parseAndAddToTree(rawI, boxNode)
      end
      return boxNode
    end,
    Table = function(pandocTable)
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
            --   local node = parseNode(cellContents[k])
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

              --   local node = parseNode(cellContents[k])

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

  log.info('walking tree...')
  local function walkTree(treeNodes)
    for i = 1, #treeNodes do
      countcounter = i
      local node = treeNodes[i]
      lastNode = parseNode(node)

      if lastNode and #lastNode.children > 0 then
        log.info('Adding top level node ' .. node.t .. ' at ' .. i)
        root:appendChild(lastNode)
      end
    end
  end

  walkTree(treeEntry.json.blocks)
  return root
end

function mdTreeMethods:update(crankChange, offset)
  -- if crankChange ~= 0 or offset ~= 0 then
  local treePosition = { x = self.treeSprite.x, y = self.treeSprite.y }
  if self.tree.scrollTarget then
    if self.tree.scrollTarget.properties.direction == playout.kDirectionHorizontal then
      treePosition.x = (self.treeSprite.width / 2) + offset
    else
      treePosition.y = (self.treeSprite.height / 2) + offset
    end
  end

  self.treeSprite:moveTo(treePosition.x, treePosition.y)
  -- end
  self.treeSprite:update()

  playdate.timer.updateTimers()
  playdate.drawFPS()
end

return mdTree
