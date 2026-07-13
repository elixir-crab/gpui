%{
  configs: [
    %{
      name: "default",
      plugins: [{ExSlop, []}],
      files: %{
        included: ["lib/", "test/", "codegen/"],
        excluded: ["lib/gpui/native/generated.ex"]
      },
      checks: [
        {Credo.Check.Design.AliasUsage, false},
        {ExSlop.Check.Readability.NarratorDoc, false}
      ]
    }
  ]
}
