-- sdk libs
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"

local gfx <const> = playdate.graphics

-- The speed of scrolling via the crank
local CRANK_SCROLL_SPEED <const> = 1.2
-- The current speed modifier for the crank
local crankSpeedModifier = 1
-- The crank offset from before skipScrollTicks was set
local previousCrankOffset = 0
-- The number of ticks to skip modulating the scroll offset
local skipScrollTicks = 0
-- The scroll offset
local offset = 0;

local pagePadding = 10
local kDirectionVertical = 1
local kDirectionHorizontal = 2

-- local libs
import "../playout.lua"
-- import "test"

fonts = {
  normal = gfx.getSystemFont(gfx.font.kVariantNormal),
  bold = gfx.getSystemFont(gfx.font.kVariantBold)
}

local button = {
  padding = 4,
  paddingLeft = 16,
  borderRadius = 12,
  border = 2,
  shadow = 3,
  shadowAlpha = 1/4,
  backgroundColor = gfx.kColorWhite,
  font = fonts.bold
}

local buttonHover = {
  padding = 4,
  paddingLeft = 16,
  borderRadius = 12,
  border = 2,
  shadow = 3,
  shadowAlpha = 1/4,
  backgroundColor = gfx.kColorWhite,
  backgroundAlpha = 1/2,
  font = fonts.bold,
  paddingBottom = 5,
  shadow = 5,
}

local menu = nil
local menuImg, menuSprite, menuTimer
local selectedIndex = 1

local pointer
local pointerPos = nil
local pointerTimer

local logo = gfx.image.new("images/tmm-block.png")

local testResultMessage
local selected

local function setPointerPos()
  selected = menu.tabIndex[selectedIndex]
  local menuRect = menuSprite:getBoundsRect()

  pointerPos = getRectAnchor(selected.rect, playout.kAnchorCenterLeft):
    offsetBy(getRectAnchor(menuRect, playout.kAnchorTopLeft):unpack())  
end

local function nextMenuItem()
  selectedIndex = selectedIndex + 1
  if selectedIndex > #menu.tabIndex then
    selectedIndex = 1
  end
  setPointerPos()
end

local function prevMenuItem()
  selectedIndex = selectedIndex - 1
  if selectedIndex < 1 then
    selectedIndex = #menu.tabIndex
  end
  setPointerPos()
end

-- for f = 1, #testRunner.failedDetails do
--   local result = testRunner.failedDetails[f];
--   print(result.group .. ' > ' .. result.name)
--   print("  expected: " .. tostring(result.expected))
--   print("  actual: " .. tostring(result.actual))
-- end

local function createMenu(ui)
  local box = ui.box
  local image = ui.image
  local text = ui.text

  return box({
    maxHeight = 380,
    backgroundColor = gfx.kColorWhite,
    borderRadius = 9,
    border = 2,
    direction = playout.kDirectionHorizontal,
    shadow = 8,
    shadowAlpha = 1/3,
    scroll = 1
  }, {
    box({
      padding = 12,
      spacing = 10,
      backgroundColor = gfx.kColorBlack,
      backgroundAlpha = 7/8,
      borderRadius = 9,
      border = 2
    }, {
      box({
        border = 2,
        padding = 6,
        borderRadius = 5,
        backgroundColor = gfx.kColorWhite
      }, { image(logo) }),
      box({
        paddingLeft = 6,
        paddingTop = 3,
        paddingBottom = 1,
      }, { text("playout", { stroke = 4 }) }),
    }),
    box({
      spacing = 12,
      paddingTop = 16,
      paddingLeft = 20,
      hAlign = playout.kAlignStart
    }, { 
      text("Lorem ipsum dolor sit amet, consectetur adipiscing elit."),
      text(testResultMessage),
      box({
        direction = playout.kDirectionHorizontal,
        spacing = 12,
        paddingLeft = 16,
        paddingTop = 12,
        paddingBottom = 0,
        vAlign = playout.kAlignEnd,
        width = 240
      }, { 
        box({ style = button }, { text("cancel", { id = "no", stroke = 2, tabIndex = 1 } ) } ),
        box({ flex = 1 }),
        box({ style = button }, { text("okay", { id = "yes", stroke = 2, tabIndex = 2 } ) } ),
      })
    })
  })
end


local function createPage(ui)
  local box = ui.box
  local image = ui.image
  local text = ui.text

  return box({
    maxWidth = 380,
    backgroundColor = gfx.kColorWhite,
    borderRadius = 9,
    border = 2,
    direction = playout.Vertical,
    vAlign = playout.kAlignStretch,
    shadow = 8,
    shadowAlpha = 1 / 3,
    scroll = 1
  }, {
    box({
      padding = 12,
      spacing = 10,
      backgroundColor = gfx.kColorBlack,
      backgroundAlpha = 7 / 8,
      borderRadius = 9,
      border = 2
    }, { text("playout", { stroke = 4 }) }),
    box({
      spacing = 12,
      paddingTop = 16,
      paddingLeft = 20,
      -- scroll=1
      -- hAlign = playout.kAlignStart
    }, {
      text(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. More Text will this stretch fur consectetur adipiscing elit. More Text will this stretch fur consectetur adipiscing elit. More Text will this stretch fur consectetur adipiscing elit. More Text will this stretch further down the page or will it not I don't knwo ow hwowhjioewioweoiew."),
      text(testResultMessage),
      box({
        direction = playout.kDirectionHorizontal,
        spacing = 12,
        paddingLeft = 16,
        paddingTop = 12,
        paddingBottom = 0,
        vAlign = playout.kAlignEnd,
      }, {
        box({ style = button }, { text("cancel", { id = "no", stroke = 2, tabIndex = 1 }) }),
        box({ flex = 1 }),
        box({ style = button }, { text("okay", { id = "yes", stroke = 2, tabIndex = 2 }) }),
      })
    })
  })
end

local inputHandlers = {
  rightButtonDown = nextMenuItem,
  downButtonDown = nextMenuItem,
  leftButtonDown = prevMenuItem,
  upButtonDown = prevMenuItem,
  AButtonDown = function ()
    local selected = menu.tabIndex[selectedIndex]
    if selected == menu:get("yes") then
      menuSprite:moveBy(0, 4)
      menuSprite:update()
    end
    if selected == menu:get("no") then
      menuSprite:moveBy(0, -4)
      menuSprite:update()
    end
    setPointerPos()
  end,
  cranked = function(change, acceleratedChange)
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

function setup()
  -- run tests (see test.lua)
  -- testRunner:run()
  -- testResultMessage = "Tests: *" .. testRunner.passed .. "/" .. testRunner.total .. "* passed."
  -- if testRunner.passed < testRunner.total then
  --   testResultMessage = testResultMessage .. " Oops"
  -- else
  --   testResultMessage = testResultMessage .. " Nice!"
  -- end

  -- attach input handlers
  playdate.inputHandlers.push(inputHandlers)

  -- setup menu
  menu = playout.tree:build(createMenu)
  menu:computeTabIndex()
  menuImg = menu:draw()
  menuSprite = gfx.sprite.new(menuImg)
  local menuRect = menuSprite:getBoundsRect()
  local anchor  = getRectAnchor(menuRect, playout.kAnchorTopLeft)

  menuSprite:moveTo(-anchor.x + pagePadding, -anchor.y + pagePadding)
  menuSprite:add()

  -- setup bg sprite
  local bg = gfx.image.new("images/mountains.png")
  gfx.sprite.setBackgroundDrawingCallback(
    function(x, y, width, height)
      gfx.setClipRect(x, y, width, height)
      bg:draw(0, 0)
      gfx.clearClipRect()
    end
  )

  -- setup pointer
  local pointerImg = gfx.image.new("images/pointer")
  pointer = gfx.sprite.new(pointerImg)
  pointer:setRotation(90)
  pointer:setZIndex(1)
  pointer:add()
  setPointerPos()

  -- setup pointer animation
  pointerTimer = playdate.timer.new(500, -18, -14, playdate.easingFunctions.inOutSine)
  pointerTimer.repeats = true
  pointerTimer.reverses = true

  -- setup menu animation
  menuTimer = playdate.timer.new(500, 400, 100, playdate.easingFunctions.outCubic)
  menuTimer.timerEndedCallback = setPointerPos

  -- Reset the crank position
  offset = 0
  previousCrankOffset = 0
  skipScrollTicks = 0
end

-- frame callback
function playdate.update()
  -- if menuTimer.timeLeft > 0 then
  --   menuSprite:moveTo(200, menuTimer.value)\
  --   menuSprite:update()
  -- end
  
  local menuPosition = { x = menuSprite.x, y = menuSprite.y }
  if menu.scrollTarget then
    if menu.scrollTarget.properties.direction == kDirectionHorizontal  then
      menuPosition.x = (menuSprite.width / 2) + offset + pagePadding
    else 
      menuPosition.y = (menuSprite.height / 2) + offset + pagePadding 
    end
  end

  menuSprite:moveTo(menuPosition.x, menuPosition.y)
  menuSprite:update()

  setPointerPos()
  pointer:moveTo(pointerPos.x, pointerPos.y)
  -- pointer:moveTo(
  --   pointerPos:offsetBy(pointerTimer.value, 0)
  -- )
  pointer:update()

  playdate.timer.updateTimers()
  playdate.drawFPS()
end

setup()
