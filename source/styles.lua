local ctrldFontFamily = {
  [playdate.graphics.font.kVariantNormal] = 'fonts/ctrld/ctrld-fixed-16',
  [playdate.graphics.font.kVariantBold] = 'fonts/ctrld/ctrld-fixed-16b',
  [playdate.graphics.font.kVariantItalic] = 'fonts/ctrld/ctrld-fixed-16i'
}

local scientificaFontFamily = {
  [playdate.graphics.font.kVariantNormal] = 'fonts/scientifica/scientifica-11',
  [playdate.graphics.font.kVariantBold] = 'fonts/scientifica/scientificaBold-11',
  [playdate.graphics.font.kVariantItalic] = 'fonts/scientifica/scientificaItalic-11'
}

local roobertFontFamily = {
  [playdate.graphics.font.kVariantNormal] = 'fonts/roobert/Roobert-11-Medium',
  [playdate.graphics.font.kVariantBold] = 'fonts/roobert/Roobert-11-Bold',
  [playdate.graphics.font.kVariantItalic] = 'fonts/roobert/Roobert-11-Medium-Halved'
}

local UWttyp0FontFamily = {
  [playdate.graphics.font.kVariantNormal] = 'fonts/UW-ttyp0/UW-ttyp0',
  [playdate.graphics.font.kVariantBold] = 'fonts/UW-ttyp0/UW-ttyp0-Bold',
  [playdate.graphics.font.kVariantItalic] = 'fonts/UW-ttyp0/UW-ttyp0-Italic'
}

local leggieFontFamily = {
  [playdate.graphics.font.kVariantNormal] = 'fonts/leggie/leggie-24',
  [playdate.graphics.font.kVariantBold] = 'fonts/leggie/leggie-24b',
  [playdate.graphics.font.kVariantItalic] = 'fonts/leggie/leggie-24i'
}

local lucidiaFontFamily = {
  [playdate.graphics.font.kVariantNormal] = 'fonts/lucidia/lucidia-16x30',
  [playdate.graphics.font.kVariantBold] = 'fonts/lucidia/lucidia-16x30b',
}


local styles = {
  BlockQuote = {
    borderLeft = 10,
    paddingLeft = 20,
    spacing = 12,
    fontFamily = playdate.graphics.font.newFamily(leggieFontFamily),
  },
  BulletList = {
    hAlign = playout.kAlignStart,
    spacing = 6,
    fontFamily = playdate.graphics.font.newFamily(leggieFontFamily)
  },
  Header1 = {
    padding = 10,
    backgroundColor = playdate.graphics.kColorBlack,
    -- backgroundAlpha = 2 / 8,
    color = playdate.graphics.kColorWhite,

    font = playdate.graphics.font.new(lucidiaFontFamily[playdate.graphics.font.kVariantBold])
  },
  Header2 = {
    padding = 10,
    backgroundAlpha = 2 / 8,
    border = 4,
    color = playdate.graphics.kColorWhite,
    backgroundColor = playdate.graphics.kColorBlack,
    font = playdate.graphics.font.new(lucidiaFontFamily[playdate.graphics.font.kVariantBold])
  },
  Header3 = {
    paddingLeft = 10,
    paddingRight = 6,
    paddingTop = 6,
    paddingBottom = 6,
    color = playdate.graphics.kColorWhite,
    backgroundColor = playdate.graphics.kColorBlack,
    backgroundAlpha = 3 / 8,
    border = 2,
    font = playdate.graphics.font.new(lucidiaFontFamily[playdate.graphics.font.kVariantNormal])
  },
  Header4 = {    
    padding = 4,
    backgroundColor = playdate.graphics.kColorBlack,
    backgroundAlpha = 7 / 8,
    border = 1,
    font = playdate.graphics.font.new(leggieFontFamily[playdate.graphics.font.kVariantBold])
  },
  Para = {
    spacing = 12,
    fontFamily = playdate.graphics.font.newFamily(leggieFontFamily)
  },
  Root = {
    width = 400,
    backgroundColor = playdate.graphics.kColorWhite,
    direction = playout.Vertical,
    hAlign = playout.kAlignStretch,
    scroll = 1,
    padding = 10,
    spacing = 8
  }
}

-- styles.BulletList = styles.Para
styles.OrderedList = styles.BulletList
return styles
