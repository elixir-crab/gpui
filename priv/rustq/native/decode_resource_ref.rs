let env = term.get_env();
Ok(__STRUCT_NAME__ {
    id: term.map_get(Atom::from_bytes(env, b"id")?)?.decode::<String>()?,
    type_: term
        .map_get(Atom::from_bytes(env, b"type")?)?
        .atom_to_string()
        .unwrap_or_default(),
})
