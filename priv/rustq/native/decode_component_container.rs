Ok(__STRUCT_NAME__ {
    style: decode_style(term).unwrap_or_default(),
    children: decode_children(term).unwrap_or_default(),
    click: generated_string_attr(term, "__CLICK_ATTR__"),
})
