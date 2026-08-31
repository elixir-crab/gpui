base = Path.join(__DIR__, "component_gallery")

Code.require_file("story.exs", base)
Code.require_file("components.exs", base)

base
|> Path.join("stories/*.exs")
|> Path.wildcard()
|> Enum.sort()
|> Enum.each(&Code.require_file/1)

Code.require_file("catalog.exs", base)
Code.require_file("view.exs", base)
Code.require_file("app.exs", base)
