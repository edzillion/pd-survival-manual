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
  [playdate.graphics.font.kVariantNormal] = 'fonts/leggie/leggie-18',
  [playdate.graphics.font.kVariantBold] = 'fonts/leggie/leggie-18b',
  [playdate.graphics.font.kVariantItalic] = 'fonts/leggie/leggie-18bi'
}


local styles = {
  Header1 = {
    padding = 12,
    backgroundColor = playdate.graphics.kColorBlack,
    backgroundAlpha = 7 / 8,
    borderLeft = 2,
    font = playdate.graphics.font.new('fonts/emerald_20')
  },

  Header3 = {
    padding = 12,
    backgroundColor = playdate.graphics.kColorBlack,
    backgroundAlpha = 7 / 8,
    border = 2,
    font = playdate.graphics.font.new('fonts/emerald_17')
  },

  BlockQuote = {
    paddingLeft = 25,
    backgroundColor = playdate.graphics.kColorWhite,
    borderLeft = 10,
    borderBottom = 2,
    borderTop = 2,
    borderRight = 2,
    fontFamily = playdate.graphics.font.newFamily(leggieFontFamily)
  },

  Para = {
    spacing = 12,
    paddingTop = 16,
    paddingLeft = 20,
    border = 1,
    fontFamily = playdate.graphics.font.newFamily(leggieFontFamily)
  },

  Root = {
    maxWidth = 400,
    backgroundColor = playdate.graphics.kColorWhite,
    direction = playout.Vertical,
    vAlign = playout.kAlignStretch,
    scroll = 1,
    padding = 10,
    spacing = 10
  }
}

return styles
