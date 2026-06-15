Ok(__STRUCT_NAME__ {
    style: decode_style(term).unwrap_or_default(),
    value: generated_string_attr(term, "value").unwrap_or_default(),
    placeholder: generated_string_attr(term, "placeholder"),
    change: generated_string_attr(term, "__CHANGE_ATTR__"),
    keydown: generated_string_attr(term, "__KEYDOWN_ATTR__"),
    keyup: generated_string_attr(term, "__KEYUP_ATTR__"),
})
