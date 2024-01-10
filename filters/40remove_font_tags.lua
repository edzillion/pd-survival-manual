function RawInline(raw)
  if raw.format == 'html' and
      (raw.text:sub(1, 6) == '<font ' or raw.text == '</font>') then
    return ''
  end
end
