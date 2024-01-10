function Pandoc(doc)
  local titleWords = {}
  for word in PANDOC_STATE.input_files[1]:match("(.+)%..+"):gmatch("([A-Z][a-z]+)") do
    table.insert(titleWords, word)
  end
  local h1 = pandoc.Header(1, table.concat(titleWords, ' '))
  table.insert(doc.blocks, 1, h1)
  return doc
end
