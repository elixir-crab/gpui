let env = term.get_env();
Ok(__STRUCT_NAME__ {
    width: term.map_get(Atom::from_bytes(env, b"width")?)?.decode::<u32>()?,
    height: term.map_get(Atom::from_bytes(env, b"height")?)?.decode::<u32>()?,
    format: term
        .map_get(Atom::from_bytes(env, b"format")?)?
        .atom_to_string()
        .unwrap_or_else(|_| "rgba8".to_string()),
    stride: optional_u32(term.map_get(Atom::from_bytes(env, b"stride")?).ok()),
    data: term
        .map_get(Atom::from_bytes(env, b"data")?)?
        .decode::<rustler::Binary>()?
        .as_slice()
        .to_vec(),
})
