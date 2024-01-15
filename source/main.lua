local playdate_markdown = {
  _VERSION     = 'playdate-markdown v0.0.1',
  _DESCRIPTION = 'Tool for converting markdown into a Playout tree for display on a Playdate',
  _URL         = 'https://github.com/edzillion/playdate-markdown',
  _LICENSE     = [[GNU AFFERO GENERAL PUBLIC LICENSE Version 3]]
}

local gfx <const> = playdate.graphics
local file <const> = playdate.file

import 'CoreLibs/animation'

local loadingPage = 'Apps'

local MarkdownTree = import 'markdown-tree'

-- local playout = import '../playout/playout'
__ = import 'underscore'
log = import "log"

local styles = import 'styles'

local JSON_FOLDER = 'json'

local currentPage
local pages = {}
local history = {}

local pointer
local pointerPos = { x = 0, y = 0 }
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
local previousOffset = offset
-- The crank change sinice last update
local crankChange = 0

local MODES = {
  READING = 1,
  TABBING = 2,
  LOADING = 3
}

local currentMode = MODES.LOADING

local loaderAnimation

local scrollButtonOffsetChange = 0

local function changeMode(newMode)
  local newModeName
  for k, v in pairs(MODES) do
    if v == newMode then
      newModeName = k
    end
  end
  log.info('MODE CHANGE: ' .. newModeName)
  currentMode = newMode
end

local function setPointerPos()
  log.info('setPointerPos')
  if #currentPage.tree.tabIndex == 0 or currentMode == MODES.READING then
    pointer:remove()
    log.info('pointer:remove()')
    return
  end

  log.info('pointer:add()')
  pointer:add()

  selected = currentPage.tree.tabIndex[selectedIndex]
  local currentPageRect = currentPage.treeSprite:getBoundsRect()

  local newPointerPos = getRectAnchor(selected.rect, playout.kAnchorCenterLeft):offsetBy(getRectAnchor(currentPageRect,
    playout.kAnchorTopLeft):unpack())

  if newPointerPos.y < 15 and newPointerPos.y > -240 then
    local moveY     = newPointerPos.y - 15
    offset          = offset - moveY
    newPointerPos.y = 15
  elseif newPointerPos.y > 230 and newPointerPos.y < 480 then
    local moveY     = newPointerPos.y - 230
    offset          = offset - moveY
    newPointerPos.y = 230
  end

  if newPointerPos.y > 0 and newPointerPos.y < 240 then
    pointerPos = newPointerPos
    log.info('pointerPos', pointerPos)
  end
end

local function retargetPointer()
  log.info('retargetPointer')
  local currentPageRect = currentPage.treeSprite:getBoundsRect()
  for i = 1, #currentPage.tree.tabIndex do
    local tab = currentPage.tree.tabIndex[i]
    local tabPos = getRectAnchor(tab.rect, playout.kAnchorCenterLeft):offsetBy(getRectAnchor(currentPageRect,
      playout.kAnchorTopLeft):unpack())
    -- we have a tab in viewable range
    if tabPos.y > 10 and tabPos.y < 230 then
      selectedIndex = i
      changeMode(MODES.TABBING)
      log.info('tab found, selectedIndex:', selectedIndex)
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
  log.info('clickLink')
  table.insert(history, { name = currentPage.name, offset = offset, selectedIndex = selectedIndex })
  local selected = currentPage.tree.tabIndex[selectedIndex]
  local linkTarget = selected.properties.target
  -- gfx.clear()

  if linkTarget:sub(1, 1) == '#' then
    local targetId = linkTarget:sub(2, #linkTarget)
    local target = currentPage.tree:get(targetId)
    pointer:remove()

    local currentPageRect = currentPage.treeSprite:getBoundsRect()

    local targetPos       = getRectAnchor(target.rect, playout.kAnchorTopLeft):offsetBy(getRectAnchor(currentPageRect,
      playout.kAnchorTopLeft):unpack())
    offset                = offset - targetPos.y
    changeMode(MODES.READING)
    setPointerPos()
  else
    changeMode(MODES.LOADING)
    currentPage.treeSprite:remove()

    loadingPage = linkTarget
    BuildTreeRoutine = coroutine.create(function(pageTree)
      pageTree:build(function(page)
        currentPage = page
        selectedIndex = 1
        offset = 0
        changeMode(MODES.READING)
        setPointerPos()
      end)
    end)
  end
end

local inputHandlers = {
  rightButtonDown = function()
    if currentMode == MODES.TABBING then
      return nextTabItem()
    end
  end,
  downButtonDown  = function()
    if currentMode == MODES.TABBING then
      return nextTabItem()
    elseif currentMode == MODES.READING then
      scrollButtonOffsetChange = -5
    end
  end,
  downButtonUp    = function()
    if currentMode == MODES.READING then
      scrollButtonOffsetChange = 0
    end
  end,
  leftButtonDown  = function()
    if currentMode == MODES.TABBING then
      return prevTabItem()
    end
  end,
  upButtonDown    = function()
    if currentMode == MODES.TABBING then
      return prevTabItem()
    elseif currentMode == MODES.READING then
      scrollButtonOffsetChange = 5
    end
  end,
  upButtonUp      = function()
    if currentMode == MODES.READING then
      scrollButtonOffsetChange = 0
    end
  end,
  AButtonDown     = function()
    -- if we hit A while in reading mode then tab to the first link in the currently viewable content
    if currentMode == MODES.READING then
      retargetPointer()
    elseif currentMode == MODES.TABBING then
      clickLink()
    end
  end,
  BButtonDown     = function()
    if currentMode == MODES.TABBING then
      changeMode(MODES.READING)
      setPointerPos()
    elseif currentMode == MODES.READING then
      if #history > 0 then
        local targetTree = table.remove(history, #history)
        loadingPage = targetTree.name
        if currentPage.name == loadingPage then
          offset = targetTree.offset
          changeMode(MODES.TABBING)
          currentPage:update(crankChange, offset)
          setPointerPos()
        else
          currentPage.treeSprite:remove()
          -- gfx.clear()
          changeMode(MODES.LOADING)
          BuildTreeRoutine = coroutine.create(function(pageTree)
            pageTree:build(function(page)
              currentPage = page
              selectedIndex = targetTree.selectedIndex
              offset = targetTree.offset
              if currentPage.name == 'Home' then
                changeMode(MODES.TABBING)
              end
              setPointerPos()
            end)
          end)
        end
      end
    end
  end,
  cranked         = function(change, acceleratedChange)
    crankChange = change
    if skipScrollTicks > 0 then
      skipScrollTicks = skipScrollTicks - 1
      offset = offset - previousCrankOffset
    else
      offset = offset - change * CRANK_SCROLL_SPEED * crankSpeedModifier
      previousCrankOffset = change * CRANK_SCROLL_SPEED * crankSpeedModifier
    end
    if currentMode == MODES.TABBING and pointerPos then
      local offsetChange = offset - previousOffset
      pointerPos.y = pointerPos.y + offsetChange
      if pointerPos.y > 480 or pointerPos.y < -240 then
        changeMode(MODES.READING)
        setPointerPos()
      end
    end
    -- print('offset', offset)
  end
}


function buildPageAsync(linkTarget, callback)
  local co = coroutine.create(pages[linkTarget].build)
  local function exec(linkTarget, callback)
    local ok, data = coroutine.resume(co, linkTarget, callback)
    if not ok then
      error(debug.traceback(co, data))
    end
    if coroutine.status(co) ~= "dead" then
      data(exec)
    end
  end
  exec(linkTarget, callback)
end

function buildPageAsync2(linkTarget, callback)
  local co = coroutine.create(pages[linkTarget].build)
  local function exec(linkTarget, callback)
    local ok, data = coroutine.resume(co, linkTarget, callback)
    if not ok then
      error(debug.traceback(co, data))
    end
    if coroutine.status(co) ~= "dead" then
      data(exec)
    end
  end
  exec(linkTarget, callback)
end

function coroutine.xpcall(co)
  local output = { coroutine.resume(co) }
  if output[1] == false then
    return false, output[2], debug.traceback(co)
  end
  return table.unpack(output)
end

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

  local pointerImg = gfx.image.new("images/pointer")
  pointer = gfx.sprite.new(pointerImg)
  pointer:setRotation(90)
  pointer:setZIndex(1)

  BuildTreeRoutine = coroutine.create(function(pageTree)
    pageTree:build(function(page)
      currentPage = page
      changeMode(MODES.TABBING)
      setPointerPos()
      playdate.inputHandlers.push(inputHandlers)
    end)
  end)

  -- set to tabbing first since we are on the Home page

  -- setup pointer

  -- setPointerPos()

  -- setup pointer animation
  -- pointerTimer = playdate.timer.new(500, -18, -14, playdate.easingFunctions.inOutSine)
  -- pointerTimer.repeats = true
  -- pointerTimer.reverses = true

  -- setup page animation
  -- pageTimer = playdate.timer.new(500, 400, 100, playdate.easingFunctions.outCubic)
  -- pageTimer.timerEndedCallback = setPointerPos

  -- add input handlers
end

-- Redefine the function with your own
---@diagnostic disable-next-line: duplicate-set-field
os = {}
function os.date(format, time)
  local time = playdate.getTime()
  local f = {
    Y = time.year,
    m = time.month,
    d = time.day,
    H = time.hour,
    M = time.minute,
    S = time.second
  }
  local timeString = format:gsub("%%([a-zA-Z])", function(c)
    return f[c]
  end)

  -- Call the original function
  return timeString
end

function playdate.update()
  if currentMode == MODES.LOADING then
    -- if buildRoutine then
    --   buildRoutine.resume()
    -- end
    local status = coroutine.status(BuildTreeRoutine)
    if status == "suspended" then
      coroutine.resume(BuildTreeRoutine, pages[loadingPage])
    elseif status == 'dead' then
      print(coroutine.xpcall(BuildTreeRoutine))
      local debug
    end
    loaderAnimation:draw(0, 0)
    local loadingText = 'Loading ' .. loadingPage .. ' ...'
    gfx.drawTextAligned(loadingText, 200, 200, kTextAlignment.center)
  else
    offset = offset + scrollButtonOffsetChange
    -- local offsetChange
    if offset > 0 then
      pointerPos.y = pointerPos.y - offset
      offset = 0
      -- offsetChange = -offset
    elseif offset < -currentPage.treeSprite.height + 150 then
      local newOffset = -currentPage.treeSprite.height + 150
      local offsetChange = -offset + newOffset
      pointerPos.y = pointerPos.y + offsetChange
      offset = newOffset
    end
    currentPage:update(crankChange, offset)

    if currentMode == MODES.TABBING and pointerPos then
      -- pointerPos:offsetBy(pointerTimer.value, 0)
      local offsetChange = offset - previousOffset
      pointer:moveTo(pointerPos.x, pointerPos.y)
      pointer:update()
    end

    previousOffset = offset
  end

  playdate.timer.updateTimers()
  playdate.drawFPS()
end

local loaderImgTbl = gfx.imagetable.new('images/book_animation.gif')
loaderAnimation = gfx.animation.loop.new(50, loaderImgTbl, true)

init()
