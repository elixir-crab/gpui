# ETS table explorer

A supervised desktop explorer for ETS tables on the current BEAM node.

```bash
RUST_FONTCONFIG_DLOPEN=1 mix run examples/ets_table_explorer/run.exs
```

The example demonstrates:

- a supervised source process that owns the complete table and selected-entry models;
- bounded discovery of at most 10,000 tables and bounded asynchronous reads of at most 5,000 objects;
- generation-keyed stale-result rejection for selected-table reads;
- source-backed data tables whose snapshots contain at most 256 loaded rows;
- fixed sortable headers, numeric alignment, row selection, filtering, and explicit empty states;
- stable table IDs, display-safe bounded inspection, and resilience when tables disappear during inspection;
- deterministic model, runtime, and visual tests without placing test orchestration in the example.

ETS inspection is local to the application node. With a remote GPUI display, table data crosses the display transport but table access still occurs on the server running the application.
