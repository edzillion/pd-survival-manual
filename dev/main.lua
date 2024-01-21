local pd_survival_manual = {
  _VERSION     = 'pd-survival-manual v0.1.0',
  _DESCRIPTION = "Libre Survival Manual based on ligi's Android SurvivalManual",
  _URL         = 'https://github.com/edzillion/pd-survival-manual',
  _LICENSE     = [[GNU AFFERO GENERAL PUBLIC LICENSE Version 3]]
}

import 'CoreLibs/animation'
local gfx                      = playdate.graphics
local file                     = playdate.file

__                             = import 'underscore'
log                            = import "pd-log"
log.level                      = 'debug'

local MarkdownTree             = import 'markdown-tree'

local JSON_FOLDER              = 'json'
MODES                          = {
  READING = 1,
  TABBING = 2,
  LOADING = 3,
  PRELOADING = 4
}

local loadingPage              = 'Home'
UseCoroutines                  = true
BuildTreeRoutine               = nil
DrawTreeRoutine                = nil
local drawingPhase             = false

local currentPage
CurrentMode                    = MODES.LOADING
Pages                          = {}
local history                  = {}

local pointer
local pointerPos               = { x = 0, y = 0 }
local pointerTimer
local pageTimer
local selected
local selectedIndex            = 1

-- The speed of scrolling via the crank
local CRANK_SCROLL_SPEED       = 1.2
-- The current speed modifier for the crank
local crankSpeedModifier       = 1
-- The crank offset from before skipScrollTicks was set
local previousCrankOffset      = 0
-- The number of ticks to skip modulating the scroll offset
local skipScrollTicks          = 0
-- The scroll offset
local offset                   = 0
local previousOffset           = offset
-- The crank change since last update
local crankChange              = 0

local loaderAnimation
TreeElementsCount              = nil
local treeElementsBuilt        = 0
local treeElementsDrawn        = 0
local scrollButtonOffsetChange = 0

local function changeMode(newMode)
  local newModeName
  for k, v in pairs(MODES) do
    if v == newMode then
      newModeName = k
    end
  end
  log.info('MODE CHANGE: ' .. newModeName)
  CurrentMode = newMode
end

local function setPointerPos()
  log.debug('setPointerPos()')
  if #currentPage.tree.tabIndex == 0 or CurrentMode == MODES.READING then
    pointer:remove()
    log.debug('pointer:remove()')
    return
  end

  log.debug('pointer:add()')
  pointer:add()

  selected = currentPage.tree.tabIndex[selectedIndex]
  local currentPageRect = currentPage.treeSprite:getBoundsRect()

  local newPointerPos = playout.getRectAnchor(selected.rect, playout.kAnchorCenterLeft):offsetBy(playout.getRectAnchor(
    currentPageRect,
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
    log.debug('pointerPos', pointerPos)
  end
end

local function retargetPointer()
  log.debug('retargetPointer()')
  local currentPageRect = currentPage.treeSprite:getBoundsRect()
  for i = 1, #currentPage.tree.tabIndex do
    local tab = currentPage.tree.tabIndex[i]
    local tabPos = playout.getRectAnchor(tab.rect, playout.kAnchorCenterLeft):offsetBy(playout.getRectAnchor(
      currentPageRect,
      playout.kAnchorTopLeft):unpack())
    -- we have a tab in viewable range
    if tabPos.y > 10 and tabPos.y < 230 then
      selectedIndex = i
      changeMode(MODES.TABBING)
      log.debug('tab found, selectedIndex:', selectedIndex)
      break;
    end
  end
  setPointerPos()
end

local function nextTabItem()
  selectedIndex = selectedIndex + 1
  if selectedIndex > #currentPage.tree.tabIndex then
    selectedIndex = #currentPage.tree.tabIndex
  else
    local currPos = pointerPos
    setPointerPos()
    if pointerPos == currPos and offset == previousOffset then
      -- no new pointer position, next item is too far away
      selectedIndex = selectedIndex - 1
    end
  end
end

local function prevTabItem()
  selectedIndex = selectedIndex - 1
  if selectedIndex < 1 then
    selectedIndex = 1
  else
    local currPos = pointerPos
    setPointerPos()
    if pointerPos == currPos and offset == previousOffset then
      -- no new pointer position, next item is too far away
      selectedIndex = selectedIndex + 1
    end
  end
end

local function clickLink()
  log.debug('clickLink()')
  local selected = currentPage.tree.tabIndex[selectedIndex]
  local linkTarget = selected.properties.target

  -- If the link target is an anchor, not a page
  if linkTarget:sub(1, 1) == '#' then
    local targetId = linkTarget:sub(2, #linkTarget)
    local target = currentPage.tree:get(targetId)
    pointer:remove()

    local currentPageRect = currentPage.treeSprite:getBoundsRect()
    local targetPos       = playout.getRectAnchor(target.rect, playout.kAnchorTopLeft):offsetBy(playout.getRectAnchor(
      currentPageRect,
      playout.kAnchorTopLeft):unpack())
    offset                = offset - targetPos.y + 8 --styles.Root.spacing
    changeMode(MODES.READING)
    setPointerPos()
  else
    -- The link target is a page
    table.insert(history, { name = currentPage.name, offset = offset, selectedIndex = selectedIndex })

    changeMode(MODES.LOADING)
    currentPage.treeSprite:remove()
    currentPage.treeSprite = nil
    currentPage.tree = nil
    TreeElementsCount = nil

    loadingPage = linkTarget

    if UseCoroutines then
      BuildTreeRoutine = coroutine.create(function(pageTree)
        pageTree:build(function(page)
          currentPage = page
          drawingPhase = false
          selectedIndex = 1
          offset = 0
          changeMode(MODES.READING)
          setPointerPos()
        end)
      end)
    else
      Pages[loadingPage]:build(function(page)
        currentPage = page
        selectedIndex = 1
        offset = 0
        changeMode(MODES.READING)
        setPointerPos()
      end)
    end
  end
end

local inputHandlers = {
  rightButtonDown = function()
    if CurrentMode == MODES.TABBING then
      return nextTabItem()
    end
  end,
  downButtonDown  = function()
    if CurrentMode == MODES.TABBING then
      return nextTabItem()
    elseif CurrentMode == MODES.READING then
      scrollButtonOffsetChange = -5
    end
  end,
  downButtonUp    = function()
    if CurrentMode == MODES.READING then
      scrollButtonOffsetChange = 0
    end
  end,
  leftButtonDown  = function()
    if CurrentMode == MODES.TABBING then
      return prevTabItem()
    end
  end,
  upButtonDown    = function()
    if CurrentMode == MODES.TABBING then
      return prevTabItem()
    elseif CurrentMode == MODES.READING then
      scrollButtonOffsetChange = 5
    end
  end,
  upButtonUp      = function()
    if CurrentMode == MODES.READING then
      scrollButtonOffsetChange = 0
    end
  end,
  AButtonDown     = function()
    -- if we hit A while in reading mode then tab to the first link in the currently viewable content
    if CurrentMode == MODES.READING then
      retargetPointer()
    elseif CurrentMode == MODES.TABBING then
      clickLink()
    end
  end,
  BButtonDown     = function()
    if CurrentMode == MODES.TABBING then
      changeMode(MODES.READING)
      setPointerPos()
    elseif CurrentMode == MODES.READING then
      if #history > 0 then
        local targetTree = table.remove(history, #history)
        loadingPage = targetTree.name
        selectedIndex = targetTree.selectedIndex

        changeMode(MODES.LOADING)
        currentPage.treeSprite:remove()
        currentPage.treeSprite = nil
        currentPage.tree = nil
        TreeElementsCount = nil

        if UseCoroutines then
          BuildTreeRoutine = coroutine.create(function(pageTree)
            pageTree:build(function(page)
              currentPage = page
              drawingPhase = false
              selectedIndex = targetTree.selectedIndex
              offset = targetTree.offset
              if currentPage.name == 'Home' then
                changeMode(MODES.TABBING)
              else
                changeMode(MODES.READING)
              end
              currentPage:update(crankChange, offset)
              setPointerPos()
            end)
          end)
        else
          Pages[loadingPage]:build(function(page)
            currentPage = page
            selectedIndex = targetTree.selectedIndex
            offset = targetTree.offset
            if currentPage.name == 'Home' then
              changeMode(MODES.TABBING)
            else
              changeMode(MODES.READING)
            end
            currentPage:update(crankChange, offset)
            setPointerPos()
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
    if CurrentMode == MODES.TABBING and pointerPos then
      local offsetChange = offset - previousOffset
      pointerPos.y = pointerPos.y + offsetChange
      if pointerPos.y > 250 or pointerPos.y < -10 then
        changeMode(MODES.READING)
        setPointerPos()
      end
    end
  end
}

local function init()
  log.info('Initialising. Checking folders ...')
  assert(file.isdir(JSON_FOLDER), 'Missing folder: ' .. JSON_FOLDER)
  local filenames = file.listFiles(JSON_FOLDER)
  assert(#filenames > 0, 'No .json files in output folder, have you run the convert_to_json.js script?')
  log.info('JSON files found. Decoding ...')
  local filesJson = __.map(filenames, function(filename)
    local fileEntry = { name = filename:match("(.+)%..-") }
    local jsonFile = playdate.file.open(JSON_FOLDER .. '/' .. filename, playdate.file.kFileRead)
    fileEntry.json = json.decodeFile(jsonFile)
    log.debug('Decoded successfully: ' .. filename)
    return fileEntry
  end)

  log.info('Converting to markdown trees')
  __.each(filesJson, function(fileEntry)
    local page = MarkdownTree.new(fileEntry)
    page.name = fileEntry.name
    log.debug('Page converted successfully: ' .. fileEntry.name)
    -- playdate.datastore.writeImage(image, path)
    Pages[fileEntry.name] = page
  end)

  local pointerImg = gfx.image.new("images/pointer")
  pointer = gfx.sprite.new(pointerImg)
  pointer:setRotation(90)
  pointer:setZIndex(1)

  if UseCoroutines then
    BuildTreeRoutine = coroutine.create(function(pageTree)
      pageTree:build(function(page)
        currentPage = page
        drawingPhase = false
        changeMode(MODES.TABBING)
        setPointerPos()
        playdate.inputHandlers.push(inputHandlers)
      end)
    end)
  else
    Pages[loadingPage]:build(function(page)
      currentPage = page
      changeMode(MODES.TABBING)
      setPointerPos()
      playdate.inputHandlers.push(inputHandlers)
    end)
  end


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

function playdate.update()
  if CurrentMode == MODES.LOADING then
    if TreeElementsCount == nil then
      if DrawTreeRoutine then
        drawingPhase = true
        TreeElementsCount = #Pages[loadingPage].tree.root.children
        treeElementsDrawn = 0
      else
        TreeElementsCount = #Pages[loadingPage].treeData.json.blocks
        treeElementsBuilt = 0
      end
    end

    local prevColor = gfx.getColor()
    gfx.setColor(gfx.kColorBlack)

    loaderAnimation:draw(0, 0)
    local loadingText = drawingPhase and 'Drawing ' .. loadingPage or 'Loading ' .. loadingPage
    gfx.drawTextAligned(loadingText, 200, 190, kTextAlignment.center)

    gfx.drawRect(60, 220, 280, 6)
    local xScale = drawingPhase and 279 * (treeElementsDrawn / TreeElementsCount) or
        279 * (treeElementsBuilt / TreeElementsCount)
    gfx.setLineWidth(6)
    gfx.drawLine(60, 223, 60 + xScale, 223)
    gfx.setLineWidth(1)
    gfx.setColor(prevColor)

    if DrawTreeRoutine then
      local status = coroutine.status(DrawTreeRoutine)
      if status == "suspended" then
        local success, elementsDrawn = coroutine.resume(DrawTreeRoutine, Pages[loadingPage])
        if success and elementsDrawn then
          treeElementsDrawn = elementsDrawn
        end
      elseif status == 'dead' then
        DrawTreeRoutine = nil
      end
    elseif BuildTreeRoutine then
      local status = coroutine.status(BuildTreeRoutine)
      if status == "suspended" then
        local success, elementsBuilt = coroutine.resume(BuildTreeRoutine, Pages[loadingPage])
        if success and elementsBuilt then
          treeElementsBuilt = elementsBuilt
          if treeElementsBuilt == TreeElementsCount then
            local d
          end
        end
      elseif status == 'dead' then
        log.warn('BuildTreeRoutine coroutine dead, should not hit here.')
      end
    end
  else
    offset = offset + scrollButtonOffsetChange
    -- Keep offset within bounds of page
    if offset > 0 then
      pointerPos.y = pointerPos.y - offset
      offset = 0
    elseif offset < -currentPage.treeSprite.height + 150 then
      local newOffset = -currentPage.treeSprite.height + 150
      local offsetChange = -offset + newOffset
      pointerPos.y = pointerPos.y + offsetChange
      offset = newOffset
    end
    currentPage:update(crankChange, offset)

    if CurrentMode == MODES.TABBING and pointerPos then
      pointer:moveTo(pointerPos.x, pointerPos.y)
      pointer:update()
    end

    previousOffset = offset
  end

  playdate.timer.updateTimers()
end

local loaderImgTbl = gfx.imagetable.new('images/book_animation.gif')
loaderAnimation = gfx.animation.loop.new(50, loaderImgTbl, true)

init()
