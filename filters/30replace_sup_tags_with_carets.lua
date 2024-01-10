function RawInline(raw)
  if raw.format == 'html' then
    if raw.text == '<sup>' then
      return '^'
    elseif raw.text == '</sup>' then
      return ''
    end
  end
end
