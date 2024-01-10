local playdate_markdown = {
  _VERSION     = 'playdate-markdown v0.0.1',
  _DESCRIPTION = 'Tool for converting markdown into a Playout tree for display on a Playdate',
  _URL         = 'https://github.com/edzillion/playdate-markdown',
  _LICENSE     = [[GNU AFFERO GENERAL PUBLIC LICENSE Version 3]]
}

local gfx <const> = playdate.graphics
local file <const> = playdate.file

local startingPage = 'Home'

local MarkdownTree = import 'markdown-tree'

-- local playout = import '../playout/playout'
__ = import 'underscore'

local styles = import 'styles'

local JSON_FOLDER = 'json'

local currentPage
local pages = {}
local history = {}

local pointer
local pointerPos = nil
local pointerTimer
local pageTimer
local selected
local selectedIndex = 1

-- The speed of scrolling via the crank
local CRANK_SCROLL_SPEED <const> = 1.2
-- The current speed modifier for the crank
local crankSpeedModifier = 1
-- The crank offset from before skipScrollTicks was set
local previousCrankOffset = 0
-- The number of ticks to skip modulating the scroll offset
local skipScrollTicks = 0
-- The scroll offset
local offset = 0
-- The crank change sinice last update
local crankChange = 0

local MODES = {
  READING = "1",
  TABBING = "2"
}

local currentMode = MODES.TABBING


local function setPointerPos()
  if #currentPage.tree.tabIndex == 0 or currentMode == MODES.READING then
    pointer:remove()
    return
  end

  pointer:add()

  selected = currentPage.tree.tabIndex[selectedIndex]
  local currentPageRect = currentPage.treeSprite:getBoundsRect()

  pointerPos = getRectAnchor(selected.rect, playout.kAnchorCenterLeft):offsetBy(getRectAnchor(currentPageRect,
    playout.kAnchorTopLeft):unpack())
  print(pointerPos)
  if pointerPos.y < 15 and pointerPos.y > -240 then
    local moveY  = pointerPos.y - 15
    offset       = offset - moveY
    pointerPos.y = 15
  elseif pointerPos.y > 230 and pointerPos.y < 480 then
    local moveY  = pointerPos.y - 230
    offset       = offset - moveY
    pointerPos.y = 230
  end
end

local function retargetPointer()
  local currentPageRect = currentPage.treeSprite:getBoundsRect()
  for i = 1, #currentPage.tree.tabIndex do
    local tab = currentPage.tree.tabIndex[i]
    local tabPos = getRectAnchor(tab.rect, playout.kAnchorCenterLeft):offsetBy(getRectAnchor(currentPageRect,
      playout.kAnchorTopLeft):unpack())
    -- we have a tab in viewable range
    if tabPos.y > 10 and tabPos.y < 230 then
      selectedIndex = i
      currentMode = MODES.TABBING
      break;
    end
  end
  setPointerPos()
end

local function nextTabItem()
  selectedIndex = selectedIndex + 1
  if selectedIndex > #currentPage.tree.tabIndex then
    selectedIndex = #currentPage.tree.tabIndex
  end
  setPointerPos()
end

local function prevTabItem()
  selectedIndex = selectedIndex - 1
  if selectedIndex < 1 then
    selectedIndex = 1
  end
  setPointerPos()
end

local function clickLink()
  table.insert(history, { name = currentPage.name, offset = offset, selectedIndex = selectedIndex })
  local selected = currentPage.tree.tabIndex[selectedIndex]
  local linkTarget = selected.properties.target
  gfx.clear()

  if linkTarget:sub(1, 1) == '#' then
    local targetId = linkTarget:sub(2, #linkTarget)
    local target = currentPage.tree:get(targetId)
    pointer:remove()

    local currentPageRect = currentPage.treeSprite:getBoundsRect()

    local targetPos       = getRectAnchor(target.rect, playout.kAnchorTopLeft):offsetBy(getRectAnchor(currentPageRect,
      playout.kAnchorTopLeft):unpack())
    offset                = offset - targetPos.y
  else
    currentPage.treeSprite:remove()
    currentPage = pages[linkTarget]:build()
    selectedIndex = 1
    offset = 0
  end
  currentMode = MODES.READING
  setPointerPos()
end

local inputHandlers = {
  rightButtonDown = nextTabItem,
  downButtonDown = nextTabItem,
  leftButtonDown = prevTabItem,
  upButtonDown = prevTabItem,
  AButtonDown = function()
    -- if we hit A while in reading mode then tab to the first link in the currently viewable content
    if currentMode == MODES.READING then
      retargetPointer()
    elseif currentMode == MODES.TABBING then
      clickLink()
    end
  end,
  BButtonDown = function()
    if currentMode == MODES.TABBING then
      currentMode = MODES.READING
      setPointerPos()
    elseif currentMode == MODES.READING then
      if #history > 0 then
        local linkTarget = table.remove(history, #history)
        currentPage.treeSprite:remove()
        gfx.clear()
        currentPage = pages[linkTarget.name]:build()
        selectedIndex = linkTarget.selectedIndex
        offset = linkTarget.offset
        currentMode = MODES.TABBING
        setPointerPos()
      end
    end
  end,
  cranked = function(change, acceleratedChange)
    crankChange = change
    if skipScrollTicks > 0 then
      skipScrollTicks = skipScrollTicks - 1
      offset = offset - previousCrankOffset
    else
      offset = offset - change * CRANK_SCROLL_SPEED * crankSpeedModifier
      previousCrankOffset = change * CRANK_SCROLL_SPEED * crankSpeedModifier
    end
    -- print('offset', offset)
  end
}

local function init()
  print('Initialising. Checking folders ...')
  assert(file.isdir(JSON_FOLDER), 'Missing folder: ' .. JSON_FOLDER)
  local filenames = file.listFiles(JSON_FOLDER)
  assert(#filenames > 0, 'No .json files in output folder, have you run the convert_to_json.js script?')
  print('JSON files found. Decoding ...')
  local filesJson = __.map(filenames, function(filename)
    local fileEntry = { name = filename:match("(.+)%..-") }
    local jsonFile = playdate.file.open(JSON_FOLDER .. '/' .. filename, playdate.file.kFileRead)
    fileEntry.json = json.decodeFile(jsonFile)
    print('Decoded successfully: ' .. filename)
    return fileEntry
  end)

  print('Converting to markdown trees')
  __.each(filesJson, function(fileEntry)
    local page = MarkdownTree.new(styles, fileEntry)
    page.name = fileEntry.name
    print('Page converted successfully: ' .. fileEntry.name)
    -- playdate.datastore.writeImage(image, path)
    pages[fileEntry.name] = page
  end)

  currentPage = pages[startingPage]:build()
  -- set to tabbing first since we are on the Home page
  currentMode = MODES.READING

  -- setup pointer
  local pointerImg = gfx.image.new("images/pointer")
  pointer = gfx.sprite.new(pointerImg)
  pointer:setRotation(90)
  pointer:setZIndex(1)
  setPointerPos()

  -- setup pointer animation
  pointerTimer = playdate.timer.new(500, -18, -14, playdate.easingFunctions.inOutSine)
  pointerTimer.repeats = true
  pointerTimer.reverses = true

  -- setup page animation
  pageTimer = playdate.timer.new(500, 400, 100, playdate.easingFunctions.outCubic)
  pageTimer.timerEndedCallback = setPointerPos

  -- add input handlers
  playdate.inputHandlers.push(inputHandlers)
end

function playdate.update()
  print('offset', offset)
  print('currentPage.treeSprite.height', currentPage.treeSprite.height)
  if currentPage then
    if offset > 0 then
      offset = 0
    elseif offset < -currentPage.treeSprite.height + 150 then
      offset = -currentPage.treeSprite.height + 150
    end
    currentPage:update(crankChange, offset)

    if pointerPos then
      pointerPos:offsetBy(pointerTimer.value, 0)
      pointer:moveTo(pointerPos.x, pointerPos.y)
      pointer:update()
    end
  end
  playdate.timer.updateTimers()
  playdate.drawFPS()
end

init()
