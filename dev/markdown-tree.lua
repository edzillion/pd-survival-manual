import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
local gfx = playdate.graphics
local geo = playdate.geometry

import "playout"
local styles = import 'styles'

-- markdown tree object
local mdTree = {}
-- private methods
local mdTreeMethods = {}

local redrawRoutine
local rootElementCounter

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
DRAW_ELEMENTS_SIZE = 50

mdTree.new = function(treeEntry)
  local mdt = {
    tree = nil,
    treeSprite = nil,
    treeData = treeEntry,
    lastElementNum = DRAW_ELEMENTS_SIZE --math.min(DRAW_ELEMENTS_SIZE, #treeEntry.json.blocks)
  }
  local tree = setmetatable(mdt, { __index = mdTreeMethods })
  return tree
end

function mdTreeMethods:build(callback)
  log.info('Building Tree for ' .. self.treeData.name)
  self.tree = playout.tree:build(self, self.createTree, self.treeData)
  self.tree:computeTabIndex()

  local treeImage
  log.info('Drawing Tree for ' .. self.treeData.name)
  DrawTreeRoutine = coroutine.create(function()
    treeImage = self.tree:draw()
  end)
  coroutine.yield()
  log.info('Creating treeSprite for ' .. self.treeData.name)
  self.treeSprite = gfx.sprite.new(treeImage)
  local treeRect  = self.treeSprite:getBoundsRect()
  local anchor    = playout.getRectAnchor(treeRect, playout.kAnchorTopLeft)

  self.treeSprite:moveTo(-anchor.x, -anchor.y)
  self.treeSprite:add()

  log.info('Tree successfully built for ' .. self.treeData.name .. ', calling callback()')
  callback(self)
end

function mdTreeMethods.createTree(self, ui, treeEntry)
  -- Playout elements
  local box = ui.box
  local image = ui.image
  local text = ui.text

  local links = {}
  local root = box(styles.Root)

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
    log.trace('Parsing node ' .. node.t)
    local n = parseFunctions[node.t](node)
    if UseCoroutines then
      coroutine.yield(rootElementCounter)
    end
    return n
  end

  local parseAndAddToTree = function(block, boxNode)
    local nodeToAdd = parseNode(block)
    if nodeToAdd ~= nil then
      log.trace('Adding node ' .. block.t)
      boxNode:appendChild(nodeToAdd)
    end
    return boxNode
  end

  local mergeNodeProps = function(node, props)
    for k, v in pairs(props) do
      node.properties[k] = v
    end
    return node
  end

  local function extractProps(tagString)
    local properties = {}
    -- Convert properties to playout keys
    for property, value in tagString:gmatch('(%a+)%s-=%s-"(.-)"') do
      if string.match(value, "^%d+$") then
        value = tonumber(value)
      end
      properties[HTML_TO_PLAYOUT_PROPS[property] or property] = HTML_TO_PLAYOUT_VALS[value] or value
    end
    -- Deal with hex colors
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
  local tagProps
  local textProps
  local indentWithStars
  local bulletListItems = {}
  local bulletListDepth = 0

  parseFunctions = {
    BlockQuote = function(blockQuote)
      local boxNode = box(styles.BlockQuote or nil)

      __.each(blockQuote.c, function(subBlock)
        local nodeToAdd = parseNode(subBlock)
        if nodeToAdd ~= nil then
          nodeToAdd = mergeNodeProps(nodeToAdd, styles.BlockQuoteContent)
          log.trace('Adding node ' .. subBlock.t)
          boxNode:appendChild(nodeToAdd)
        end
      end)

      return boxNode
    end,
    BulletList = function(bulletList)
      local boxNode = box(styles.BulletList or nil)
      -- Down one level, add to depth and indent
      bulletListDepth = bulletListDepth + 1
      if indentWithStars ~= nil then
        indentWithStars = ' ' .. indentWithStars
      else
        indentWithStars = '** '
      end

      log.trace('Enter Bulletlist, depth:', bulletListDepth)

      -- Go through the bulletList children, indenting and adding **
      for i = 1, #bulletList.c do
        for j = 1, #bulletList.c[i] do
          local block = bulletList.c[i][j]
          local nodeToAdd = parseNode(block)
          if nodeToAdd ~= nil then
            if block.t == 'Plain' then
              nodeToAdd.children[1].text = indentWithStars .. nodeToAdd.children[1].text
            end
            table.insert(bulletListItems, nodeToAdd)
          end
        end
      end

      -- Up one level, de-indent
      indentWithStars = indentWithStars:sub(2, #indentWithStars)

      -- If we're at the end of the GP BulletList, concat text / links and add to main BulletList node
      if bulletListDepth == 1 then
        local listTextBuffer = ''
        __.each(bulletListItems, function(node)
          __.each(node.children, function(subNode)
            if subNode.properties.tabIndex == nil then
              listTextBuffer = listTextBuffer .. subNode.text .. '\n'
            else
              if subNode.properties.target:sub(1, 8) == 'https://' or
                  subNode.properties.target:sub(1, 7) == 'http://' then
                -- external link, just print it's url string
                listTextBuffer = listTextBuffer .. subNode.text .. ' (' .. subNode.properties.target .. ')'
              else
                subNode.text = listTextBuffer .. subNode.text
                boxNode:appendChild(subNode)
                listTextBuffer = ''
              end
            end
          end)
        end)
        boxNode:appendChild(text(listTextBuffer))
        bulletListItems = {}
        indentWithStars = nil
      end


      log.trace('Exit Bulletlist, depth:', bulletListDepth)
      bulletListDepth = bulletListDepth - 1

      -- If we are inside a table then append to that instead of returning
      if tableColNode ~= nil then
        tableColNode:appendChild(boxNode)
      else
        return boxNode
      end
    end,
    Header = function(header)
      local headerStyleName = header.t .. header.c[1] --Header1, Header2 etc.
      local headerStyle = styles[headerStyleName] or nil
      local boxNode = box(headerStyle)

      if header.c[2][1] ~= nil and string.len(header.c[2][1]) > 0 then
        -- has an anchor
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
      return text(linkText, { target = linkLocation, tabIndex = #links })
    end,
    OrderedList = function(ordList)
      local boxNode = box(styles.OrderedList or nil)

      local listStart = ordList.c[1][1]
      local listStyle = ordList.c[1][2].t
      local listDelim = ordList.c[1][3].t

      -- Add custom delimeter for numerals
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
      end

      -- Add numerals and concat text
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
        end)
        return memo
      end)

      boxNode.children = { text(__.join(listStrings, '\n')) }

      -- If we are inside a table apppend to that instead of returning
      if tableColNode ~= nil then
        tableColNode:appendChild(boxNode)
      else
        return boxNode
      end
    end,
    Para = function(para)
      local boxNode = box(styles.Para or nil)

      __.each(para.c, function(subBlock)
        local node = parseNode(subBlock)
        if node then
          if subBlock.t == 'Image' then
            log.warn('Para subblock is an Image, special case?')
          end
          boxNode:appendChild(node)
        end
      end)

      -- If we are inside a table append to that instead of returning, applying Tag Props
      if tableColNode then
        for k, v in pairs(tagProps) do
          boxNode.properties[k] = v
        end
        tableColNode:appendChild(boxNode)
      else
        return boxNode
      end
    end,
    Plain = function(plain)
      local boxNode = box(styles.Plain or nil)
      __.each(plain.c, function(subBlock)
        boxNode = parseAndAddToTree(subBlock, boxNode)
      end)
      return boxNode
    end,
    Str = function(str)
      -- Dealing with TOC generated extra link string
      if str.c:sub(1, 5) == '{#toc' then
        return
      end
      -- if string is empty return nil (don't add an element)
      local textNode = str.c ~= '' and text(str.c, textProps or nil) or nil
      return textNode
    end,
    RawBlock = function(rawB)
      -- Mostly dealing with HTML tables
      if rawB.c[1] == 'html' then
        local rawBlockTag = rawB.c[2]
        local rawBlockClosingTag
        if rawBlockTag:sub(2, 2) == '/' then
          rawBlockClosingTag = rawBlockTag
        else
          local rawBlockTagStem = rawBlockTag:match('(.-)%s')
          rawBlockClosingTag = rawBlockTagStem:sub(1, 1) .. '/' .. rawBlockTagStem:sub(2, #rawBlockTagStem)
        end
        local rawBlockTagContents = rawBlockTag:match(">(.-)<")
        -- tagProps are applied to tags inside the table
        tagProps = extractProps(rawBlockTag) or nil

        if rawBlockTag:sub(1, 6) == '<table' then
          tableNode = box(styles.Table or tagProps)
          return tableNode
        elseif rawBlockTag:sub(1, 8) == '</table>' then
          tableNode = nil
          tableRowNode = nil
          tableColNode = nil
        elseif rawBlockTag:match('^<%/?t[hrd]') then
          tagProps.padding = 4
          tagProps.border = 1
          local node = box(tagProps or nil)
          if rawBlockTag:sub(1, 3) == '<tr' then
            tableRowNode = mergeNodeProps(node, styles.TableRow)
          elseif rawBlockTag:sub(1, 5) == '</tr>' then
            -- At closing tag of table row, we know how many cols there are so calc width
            __.each(tableRowNode.children, function(colNode)
              colNode.properties.width = 380 / #tableRowNode.children
            end)
            tableNode:appendChild(tableRowNode)
            tableRowNode = nil
          elseif rawBlockTag:sub(1, 3) == '<td' then
            if rawBlockTagContents and rawBlockTagContents:gsub("[\n\r\t]", "") ~= '' then
              local t = text(rawBlockTagContents)
              node:appendChild(t)
            end
            tableColNode = mergeNodeProps(node, styles.TableCol)
            if rawBlockTag:find(rawBlockClosingTag) then
              tableRowNode:appendChild(tableColNode)
              tableColNode = nil
            end
          elseif rawBlockTag:sub(1, 5) == '</td>' then
            tableRowNode:appendChild(tableColNode)
            tableColNode = nil
          elseif rawBlockTag:sub(1, 3) == '<th' then
            if rawBlockTagContents and rawBlockTagContents:gsub("[\n\r\t]", "") ~= '' then
              local t = text(rawBlockTagContents)
              node:appendChild(t)
            end
            tableColNode = mergeNodeProps(node, styles.TableHead)

            if rawBlockTag:find(rawBlockClosingTag) then
              tableRowNode:appendChild(tableColNode)
              tableColNode = nil
            end
          elseif rawBlockTag:sub(1, 5) == '</th>' then
            tableRowNode:appendChild(tableColNode)
            tableColNode = nil
          end
        elseif rawBlockTag:sub(1, 4) == '<ul>' then
          tableColNode:appendChild(text(''))
        elseif rawBlockTag:sub(1, 4) == '<li>' then
          -- Concat all <li> tags into one text() element
          if rawBlockTagContents and rawBlockTagContents:gsub("[\n\r\t]", "") ~= '' then
            tableColNode.children[#tableColNode.children].text = tableColNode.children[#tableColNode.children].text ..
                '** ' .. rawBlockTagContents .. '\n'
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
        -- textProps apply to all text() elements inside the font tag
        textProps = extractProps(rawI.c[2])
        return
      elseif rawI.c[2] == '</font>' then
        textProps = nil
        return
      else
        boxNode = parseAndAddToTree(rawI, boxNode)
      end
      return boxNode
    end,
    Table = function(pandocTable)
      -- Markdown tables. HTML tables are RawBlock elements
      local attr = pandocTable.c[1]
      local boxNode = box(styles.Table or { maxWidth = 380 })

      local caption = pandocTable.c[2]
      local colspecs = pandocTable.c[3]
      local head = pandocTable.c[4]
      local bodies = pandocTable.c[5]
      local foot = pandocTable.c[6]

      -- Determine the props for each col based on colspecs
      local colProps = {}
      for i = 1, #colspecs do
        local props = table.shallowcopy(styles.TableCol, { hAlign = PANDOC_TO_PLAYOUT_VALS[colspecs[i][1].t] })
        if colspecs[i][2].t ~= 'ColWidthDefault' then
          props.width = colspecs[i][2].c * 380
        else
          props.width = 380 / #colspecs
        end
        table.insert(colProps, props)
      end

      -- First deal with the header row
      local headAttr = head[1]
      local headRows = head[2]
      if headRows then
        for i = 1, #headRows do
          local rowNode = box(styles.TableRow)
          local rowAttr = headRows[i][1]
          local cells = headRows[i][2]
          for j = 1, #cells do
            local headProps = table.shallowcopy(colProps[j], styles.TableHead)
            local colNode = box(headProps)
            local cell = cells[j]
            local cellAttr = cell[1]
            local cellAlign = cell[2]
            local colSpan = cell[3]
            local rowSpan = cell[4]
            local cellContents = cell[5]
            if #cellContents == 0 then
              local node = text('')
              colNode:appendChild(node)
            else
              for l = 1, #cellContents do
                local node = text(cellContents[l].c[1].c)
                colNode:appendChild(node)
              end
            end
            rowNode:appendChild(colNode)
          end
          boxNode:appendChild(rowNode)
        end
      end

      -- Then deal with the rest of the table rows
      for i = 1, #bodies do
        local bodyAttr = bodies[i][1]
        local row_head_columns = bodies[i][2]
        local headRows = bodies[i][3]
        local bodyRows = bodies[i][4]
        if bodyRows then
          for j = 1, #bodyRows do
            local rowNode = box(styles.TableRow)
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
            end
            boxNode:appendChild(rowNode)
          end
        end
      end
      local d
      return boxNode
    end
  }

  -- Walk the page tree parsing nodes as we go
  rootElementCounter = 0
  log.info('walking page tree...')
  local function walkTree(treeNodes)
    for i = 1, #treeNodes do
      rootElementCounter = i
      local node = treeNodes[i]
      lastNode = parseNode(node)
      if lastNode then
        log.info('Adding top level node ' .. node.t .. ' at ' .. #root.children + 1)
        if (node.t:sub(1, 6) == 'Header') then
          lastNode.children[1].text = (#root.children + 1) .. ' ' .. lastNode.children[1].text
          local d
        end

        root:appendChild(lastNode)
      end
    end
  end

  walkTree(treeEntry.json.blocks)
  -- root is our generated page
  return root
end

function mdTreeMethods:reDraw(newLastElement)
  log.info('Redrawing Tree for ' .. self.treeData.name)

  local currentImg = self.tree.img:copy()
  local cw, ch = currentImg:getSize()
  if UseCoroutines then
    coroutine.yield('copy previous sprite image')
  end
  self.tree:layout(self.lastElementNum, newLastElement)
  local rect = self.tree.rect
  if UseCoroutines then
    coroutine.yield('layout new tree')
  end
  local newTreeImage = self.tree:draw(self.lastElementNum, newLastElement)
  if UseCoroutines then
    coroutine.yield('draw new tree')
  end
  local newImg = gfx.image.new(rect.width, rect.height + ch)
  if UseCoroutines then
    coroutine.yield('new target sprite image')
  end
  gfx.pushContext(newImg)
  do
    currentImg:draw(0, 0)
    newTreeImage:draw(0, ch)
  end
  gfx.popContext()
  if UseCoroutines then
    coroutine.yield('draw to target sprite image')
  end
  self.tree.img = newImg
  self.treeSprite:setImage(newImg)

  self.lastElementNum = newLastElement
  if UseCoroutines then
    coroutine.yield('set new sprite image')
  end
  log.info('Tree successfully redrawn for ' .. self.treeData.name)
end

function mdTreeMethods:update(crankChange, offset)
  local treePosition = { x = self.treeSprite.x, y = self.treeSprite.y }

  -- Move the tree based on scrolling
  if self.tree.scrollTarget then
    if self.tree.scrollTarget.properties.direction == playout.kDirectionHorizontal then
      treePosition.x = (self.treeSprite.width / 2) + offset
    else
      treePosition.y = (self.treeSprite.height / 2) + offset
    end
  end

  -- if self.lastElementNum < #self.treeData.json.blocks then
  --   local topElementIndex = 1
  --   local accum = self.tree.root.properties.padding
  --   for i = 1, self.lastElementNum do
  --     local node = self.tree.root.children[i]
  --     accum = accum + node.rect.height + self.tree.root.properties.spacing
  --     if -accum < offset then
  --       topElementIndex = i
  --       break
  --     end
  --   end
  -- if topElementIndex > self.lastElementNum - 10 and CurrentMode ~= MODES.PRELOADING then
  --   log.info('Redrawing from lasElemNum: ' .. self.lastElementNum)
  --   if UseCoroutines then
  --     CurrentMode = MODES.PRELOADING
  --     redrawRoutine = coroutine.create(function(lastElemNum)
  --       self:reDraw(lastElemNum)
  --     end)
  --   else
  --     self:reDraw(self.lastElementNum + DRAW_ELEMENTS_SIZE)
  --   end
  -- end

  -- if CurrentMode == MODES.PRELOADING then
  --   local status = coroutine.status(redrawRoutine)
  --   if status == "suspended" then
  --     local success, stage = coroutine.resume(redrawRoutine, self.lastElementNum + DRAW_ELEMENTS_SIZE)
  --     if success and stage then
  --       log.trace(stage)
  --     end
  --   elseif status == 'dead' then
  --     CurrentMode = MODES.READING
  --   end
  -- end
  -- local target = currentPage.tree:get(targetId)
  -- pointer:remove()

  -- local currentPageRect = currentPage.treeSprite:getBoundsRect()
  -- local targetPos       = getRectAnchor(target.rect, playout.kAnchorTopLeft):offsetBy(getRectAnchor(currentPageRect,
  --   playout.kAnchorTopLeft):unpack())

  -- if treePosition.y - 400 < -self.treeSprite.height / 2 then
  --   self:reDraw(self.lastElementNum + DRAW_ELEMENTS_SIZE)
  -- end
  -- end

  self.treeSprite:moveTo(treePosition.x, treePosition.y)
  self.treeSprite:update()
  playdate.timer.updateTimers()
  playdate.drawFPS()
end

return mdTree
