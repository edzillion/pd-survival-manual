import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
local gfx = playdate.graphics

import "playout"
local styles = import 'styles'

-- markdown tree object
local mdTree = {}
-- private methods
local mdTreeMethods = {}

local rootElementCounter
local parseFunctions

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

  TreeElementsCount = nil
  local treeImage
  log.debug('Drawing Tree for ' .. self.treeData.name)
  DrawTreeRoutine = coroutine.create(function()
    treeImage = self.tree:draw()
  end)
  if UseCoroutines then
    coroutine.yield()
  end
  log.debug('Creating treeSprite for ' .. self.treeData.name)
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
  local anchorId

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
              elseif subNode.properties.target and rootElementCounter > 3 then
                -- link, not TOC (rootElementCounter > 3)
                if listTextBuffer ~= '' then
                  if listTextBuffer:sub(#listTextBuffer, #listTextBuffer) == '\n' then
                    listTextBuffer = listTextBuffer:sub(1, #listTextBuffer - 1)
                  end
                  local textNode = text(listTextBuffer)
                  boxNode:appendChild(textNode)
                  listTextBuffer = ''
                end
                local node = box({ hAlign = kAlignCenter, width = 388 })
                local underlineNode = box({ borderBottom = 2 })
                underlineNode:appendChild(subNode)
                node:appendChild(underlineNode)
                boxNode:appendChild(node)
              else
                local underlineNode = box({ borderBottom = 2 })
                underlineNode:appendChild(subNode)
                boxNode:appendChild(underlineNode)
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
      return box({ width = 388, height = 3, borderTop = 3 })
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

      local lastTextNode
      __.each(para.c, function(subBlock)
        local node = parseNode(subBlock)
        if node then
          if subBlock.t == 'Image' then
            boxNode = box(styles.Image)
            if anchorId then
              boxNode.properties.id = anchorId
            end
            boxNode:appendChild(node)
            lastTextNode = nil
          elseif subBlock.t == 'Str' and subBlock.c:sub(1, 8) == '*Figure ' then
            -- is an Image Caption, center
            local captionNode = box()
            captionNode:appendChild(node)
            boxNode = box(styles.ImageCaption)
            boxNode:appendChild(captionNode)
          elseif subBlock.t == 'Link' then
            local strings = __.pluck(subBlock.c[2], 'c')
            local linkText = __.join(strings, ' ')
            local linkLocation = subBlock.c[3][1]

            if linkLocation:sub(1, 1) ~= '#' and Pages[linkLocation] == nil then              
              -- this is not a valid link
              local isWebLink = linkLocation:match("https?://[%w-_%.%?%.:/%+=&]+")

              if boxNode.children and boxNode.children[#boxNode.children] and boxNode.children[#boxNode.children].text then
                lastTextNode = boxNode.children[#boxNode.children]
                if lastTextNode.text:sub(#lastTextNode.text, #lastTextNode.text) == '\n' then
                  lastTextNode.text = lastTextNode.text:sub(1, #lastTextNode.text - 1)
                end
                if isWebLink then
                  lastTextNode.text = lastTextNode.text .. linkText .. ' (' .. linkLocation .. ')'
                else
                  lastTextNode.text = lastTextNode.text .. linkText
                end
              else
                if isWebLink then
                  boxNode:appendChild(text(linkText .. ' (' .. linkLocation .. ')'))
                else
                  boxNode:appendChild(text(linkText))
                end
              end
            end
          elseif subBlock.t == 'Str' and lastTextNode then
            lastTextNode.text = lastTextNode.text .. node.text
            lastTextNode = nil
          else
            boxNode:appendChild(node)
            lastTextNode = nil
          end
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
      local lastTextNode
      __.each(plain.c, function(subBlock)
        if subBlock.t == 'Link' then
          local strings = __.pluck(subBlock.c[2], 'c')
          local linkText = __.join(strings, ' ')
          local linkLocation = subBlock.c[3][1]
          if linkLocation:sub(1, 1) ~= '#' and Pages[linkLocation] == nil then
            local isWebLink = linkLocation:match("https?://[%w-_%.%?%.:/%+=&]+")
            -- this is not a valid link
            if boxNode.children and boxNode.children[#boxNode.children] and boxNode.children[#boxNode.children].text then
              lastTextNode = boxNode.children[#boxNode.children]
              if lastTextNode.text:sub(#lastTextNode.text, #lastTextNode.text) == '\n' then
                lastTextNode.text = lastTextNode.text:sub(1, #lastTextNode.text - 1)
              end
              if isWebLink then
                lastTextNode.text = lastTextNode.text .. linkText .. ' (' .. linkLocation .. ')'
              else
                lastTextNode.text = lastTextNode.text .. linkText
              end
            else
              if isWebLink then
                boxNode:appendChild(text(linkText .. ' (' .. linkLocation .. ')'))
              else
                boxNode:appendChild(text(linkText))
              end
            end
          else
            boxNode = parseAndAddToTree(subBlock, boxNode)
            lastTextNode = nil
          end
        elseif subBlock.t == 'Str' and lastTextNode then
          lastTextNode.text = lastTextNode.text .. subBlock.c
        else
          boxNode = parseAndAddToTree(subBlock, boxNode)
          lastTextNode = nil
        end
      end)
      return boxNode
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
          if anchorId then
            tableNode.properties.id = anchorId
            anchorId = ''
          end
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
              colNode.properties.width = 388 / #tableRowNode.children
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
        anchorId = rawI.c[2]:match('<a%s+name%s-=%s-"(.-)"')
        return nil
      elseif rawI.c[2] == '</a>' then
        --end anchor
        return nil
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
    Str = function(str)
      -- Dealing with TOC generated extra link string
      if str.c:sub(1, 5) == '{#toc' then
        return
      end
      -- if string is empty return nil (don't add an element)
      local textNode = str.c ~= '' and text(str.c, textProps or nil) or nil
      return textNode
    end,
    Table = function(pandocTable)
      -- Markdown tables. HTML tables are RawBlock elements
      local boxNode = box(styles.Table or { maxWidth = 388 })
      if anchorId then
        boxNode.properties.id = anchorId
        anchorId = ''
      end

      local colspecs = pandocTable.c[3]
      local head = pandocTable.c[4]
      local bodies = pandocTable.c[5]

      -- Determine the props for each col based on colspecs
      local colProps = {}
      for i = 1, #colspecs do
        ---@diagnostic disable-next-line: undefined-field
        local props = table.shallowcopy(styles.TableCol, { hAlign = PANDOC_TO_PLAYOUT_VALS[colspecs[i][1].t] })
        if colspecs[i][2].t ~= 'ColWidthDefault' then
          props.width = colspecs[i][2].c * 388
        else
          props.width = 388 / #colspecs
        end
        table.insert(colProps, props)
      end

      -- First deal with the header row
      local headRows = head[2]
      if headRows then
        for i = 1, #headRows do
          local rowNode = box(styles.TableRow)
          local cells = headRows[i][2]
          for j = 1, #cells do
            ---@diagnostic disable-next-line: undefined-field
            local headProps = table.shallowcopy(colProps[j], styles.TableHead)
            local colNode = box(headProps)
            local cell = cells[j]
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
        local bodyRows = bodies[i][4]
        if bodyRows then
          for j = 1, #bodyRows do
            local rowNode = box(styles.TableRow)
            local cells = bodyRows[j][2]
            for k = 1, #cells do
              local cellNode = box(colProps[k])
              local cell = cells[k]
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
      return boxNode
    end
  }

  -- Walk the page tree parsing nodes as we go
  rootElementCounter = 0
  log.debug('walking page tree...')
  -- -- Add title to Home page
  -- if treeEntry.name == 'Home' then
  --   local textNode = text('Survival Manual')
  --   local boxNode = box(styles.Title)
  --   boxNode:appendChild(textNode)
  --   root:appendChild(boxNode)
  -- end
  local function walkTree(treeNodes)
    for i = 1, #treeNodes do
      rootElementCounter = i
      local node = treeNodes[i]
      lastNode = parseNode(node)
      if lastNode then
        log.debug('Adding top level node ' .. node.t .. ' at ' .. #root.children + 1)
        root:appendChild(lastNode)
      end
    end
  end

  walkTree(treeEntry.json.blocks)

  -- free up memory?
  parseFunctions = nil

  -- root is our generated page
  return root
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

  self.treeSprite:moveTo(treePosition.x, treePosition.y)
  self.treeSprite:update()
  playdate.timer.updateTimers()
  playdate.drawFPS()
end

return mdTree
