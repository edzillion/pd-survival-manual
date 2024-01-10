import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local __ = import 'underscore'

local gfx <const> = playdate.graphics

import "../playout.lua"
local box = playout.box.new
local text = playout.text.new

local mdTree = {}
-- private methods
local mdTreeMethods = {}

function mdTreeMethods.createTree(self, ui, treeTable)
  local box = ui.box
  local image = ui.image
  local text = ui.text



  function walkTreeTable(node, treeTable)
    for i = 1, #treeTable.children do
      local childNode
      local style = self.styles[treeTable.children[i].style]
      if treeTable.children[i].type == 'box' then
        childNode = box(style or nil)
        node:appendChild(childNode)
        if treeTable.children[i].children then
          walkTreeTable(childNode, treeTable.children[i])
        end
      elseif treeTable.children[i].type == 'text' then
        childNode = text(treeTable.children[i].textContent, style or nil)
        node:appendChild(childNode)
      elseif node[i].type == 'image' then
        --TODO generate image
      end
    end
  end

  local root = box(self.styles[treeTable[1].style])
  walkTreeTable(root, treeTable[1])
  return root
end

function mdTreeMethods.createTreePandoc(self, ui, treeTable)
  local box = ui.box
  local image = ui.image
  local text = ui.text


  -- collapse strings into text
  function collapseStrings()
    if self.t == 'Para' then
      local debug
    end
  end

  -- local function collapseParaStrings(paraBlock)
  --   local strings = __.pluck(paraBlock.c, 'c')
  --   local text = __.first(strings)
  --   local r = __.rest(strings)
  --   local text = __.reduce(r, text, function(memo, element)
  --     if type(element) ~= 'table' then
  --       return memo .. ' ' .. element
  --     else
  --       if element.t == 'Strong' then
  --         return memo .. '*' .. collapseParaStrings({ c = element }) .. '*'
  --         -- elseif element.t == 'Emphasis' then
  --       end
  --     end
  --   end)
  --   return text
  -- end

  local function collapseParaStrings(paraBlock)
    paraBlock.c = __.map(paraBlock.c, function(textBlock)
      if type(textBlock.c) == 'table' then
        if textBlock.t == 'Strong' then
          local strings = __.pluck(textBlock.c, 'c')
          textBlock.c = '*' .. __.join(strings, ' ') .. '*'
          textBlock.t = 'Str'
        end
      end
      return textBlock
    end)
    local strings = __.pluck(paraBlock.c, 'c')
    return __.join(strings, ' ')    
  end

  -- local newmap = __.map(treeTable.blocks, function(block)
  --   if block.t == 'BlockQuote' then
  --     block.c = __.map(block.c, function(subBlock)
  --       if subBlock.t == 'Para' then
  --         return collapseParaStrings(subBlock)
  --       end
  --     end)
  --     return block
  --   elseif block.t == 'Para' then
  --     return collapseParaStrings(block)
  --   end    
  -- end)

  local root = box(self.styles.Root)
  local lastNode = root
  local lastBlock

  local titleBox = box(self.styles.Header1)  
  local titleNode = text('HEADER')
  titleBox:appendChild(titleNode)
  root:appendChild(titleBox)

  __.each(treeTable.blocks, function(block)
    if block.t == 'BlockQuote' then
      local boxNode = box(self.styles[block.t] or nil)
      __.each(block.c, function(subBlock)
        if subBlock.t == 'Para' then
          local textNode = text(collapseParaStrings(subBlock))
          boxNode:appendChild(textNode)
        end
      end)
      root:appendChild(boxNode)
    elseif block.t == 'Para' then  
      if lastBlock ~= 'Para' then          
        local boxNode = box(self.styles[block.t] or nil)
        local textNode = text(collapseParaStrings(block))        
        boxNode:appendChild(textNode)
        root:appendChild(boxNode)    
        lastBlock = 'Para'
        lastNode = boxNode
      else
        local textNode = text(collapseParaStrings(block))        
        lastNode:appendChild(textNode)
      end
    elseif block.t == 'Header' then
      local headerStyle = block.t .. block.c[1]
      local boxNode = box(self.styles[headerStyle] or nil)
      local str = __.join(__.pluck(block.c[3], 'c'), ' ')
      local textNode = text(str)
      boxNode:appendChild(textNode)
      root:appendChild(boxNode)
    end
  end)

  -- function walkTreeTable(node, treeTable)
  --   for i = 1, #treeTable do
  --     local childNode
  --     local blockType = treeTable[i].t
  --     local style = self.styles[blockType]
  --     if blockType == 'BlockQuote' then
  --       childNode = box(style or nil)
  --       node:appendChild(childNode)
  --       if treeTable[i].c then
  --         walkTreeTable(childNode, treeTable[i].c)
  --       end
  --     elseif blockType == 'Para' then


  --     elseif blockType == 'Str' then
  --       childNode = text(treeTable.children[i].textContent, style or nil)
  --       node:appendChild(childNode)
  --     elseif node[i].type == 'image' then
  --       --TODO generate image
  --     end
  --   end
  -- end

  
  -- walkTreeTable(root, treeTable.blocks)
  return root
end

local boxData = {
  {
    type = 'box',
    style = 'root',
    children = {
      {
        type = 'box',
        style = 'header1',
        children = {
          { type = 'text', textContent = "PLANNING" }
        }
      },
      {
        type = 'box',
        style = 'blockquote',
        children = {
          { type = 'text', textContent = "Survival planning is nothing more than realizing something could happen that would put you in a survival situation and, with that in mind, _taking steps to increase your chances of survival._" },
          { type = 'text', textContent = "" },
          { type = 'text', textContent = "Preparation means preparing yourself and your survival kit for those contingencies that you have in your plan. Prepare yourself by making sure your immunizations and dental work are up-to-date. Break in your boots and make sure that the boots have good soles and water-repellent properties. Study the area, climate, terrain, and indigenous methods of food and water procurement. You should continuously assess data, even after the plan is made, to update the plan as necessary and give you the greatest possible chance of survival. Another example of preparation is finding the emergency exits on an aircraft when you board it for a flight. *Practice things that you have planned with the items in your survival kit - get to know your gear. Checking ensures that items work and that you know how to use them.* Build a fire in the rain so you know that when it is critical to get warm, you can do it. Review the medical items in your kit and have instructions printed on their use so that even in times of stress, you will not make life-threatening errors." }
        }
      },
      {
        type = 'box',
        style = 'header3',
        children = {
          { type = 'text', textContent = "IMPORTANCE OF PLANNING" }
        }
      },
      {
        type = 'box',
        style = 'paragraph',
        children = {
          { type = 'text', textContent = "Detailed prior planning is essential in potential survival situations. Including survival considerations in mission planning will enhance your chances of survival if an emergency occurs. For example, if your job requires that you work in a small, enclosed area that limits what you can carry on your person, plan where you can put your rucksack or your load-bearing equipment (LBE). *Put it where it will not prevent you from getting out of the area quickly, yet where it is readily accessible.*" }
        }
      },
    }
  }
}

function mdTreeMethods:build(treeTable)
  -- build tree
  self.tree = playout.tree:build(self, self.createTreePandoc, treeTable)
  self.tree:computeTabIndex()

  local treeImg   = self.tree:draw()
  self.treeSprite = gfx.sprite.new(treeImg)
  local treeRect  = self.treeSprite:getBoundsRect()
  local anchor    = getRectAnchor(treeRect, playout.kAnchorTopLeft)

  self.treeSprite:moveTo(-anchor.x, -anchor.y)
  self.treeSprite:add()
end

-- frame callback
function mdTreeMethods:update(crankChange, crankOffset)
  if crankChange ~= 0 then
    local treePosition = { x = self.treeSprite.x, y = self.treeSprite.y }
    if self.tree.scrollTarget then
      if self.tree.scrollTarget.properties.direction == playout.kDirectionHorizontal then
        treePosition.x = (self.treeSprite.width / 2) + crankOffset
      else
        treePosition.y = (self.treeSprite.height / 2) + crankOffset
      end
    end

    self.treeSprite:moveTo(treePosition.x, treePosition.y)
  end
  self.treeSprite:update()

  playdate.timer.updateTimers()
  playdate.drawFPS()
end

mdTree.new = function(styles, treeTable)
  local mdt = {
    styles = styles,
    tree = nil,
    treeSprite = nil
  }
  local t = setmetatable(mdt, { __index = mdTreeMethods })
  t:build(treeTable)
  return t
end

return mdTree
