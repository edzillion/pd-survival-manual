function Pandoc(doc)
  print(PANDOC_STATE.input_files[1])
  local titleWords = {}
  local filename = PANDOC_STATE.input_files[1]:match(".+/([^/]+)$"):match("(.+)%..+")

  for word in filename:gmatch("([A-Z][a-z]+)") do
    table.insert(titleWords, word)
  end
  if #titleWords == 0 then
    table.insert(titleWords, filename)
  end
  local h1 = pandoc.Header(1, table.concat(titleWords, ' '))
  table.insert(doc.blocks, 1, h1)
  return doc
end
