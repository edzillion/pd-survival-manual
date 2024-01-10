function Image(img)
  img.src = img.src:gsub("%.jpg$", ".png")
  img.src = 'images/' .. img.src
  img.caption = ''
  return img
end
