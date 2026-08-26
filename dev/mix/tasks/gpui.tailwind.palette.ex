defmodule Mix.Tasks.Gpui.Tailwind.Palette do
  use Mix.Task

  @shortdoc "Generates the pinned Tailwind palette"

  @moduledoc """
  Extracts and generates GPUI's pinned Tailwind palette.

      mix gpui.tailwind.palette --extract
      mix gpui.tailwind.palette
      mix gpui.tailwind.palette --check

  Extraction is an explicit maintainer operation that requires the pinned npm
  package under `support/tailwind/node_modules`. Generation and checking use the
  committed JSON source and require no JavaScript runtime.
  """

  @version "3.4.17"
  @source_url "https://unpkg.com/tailwindcss@3.4.17/src/public/colors.js"
  @source_sha256 "28907aa147f4ca19fb3c07bd21e88aac459df8a533e629530eb8b384bcae760d"
  @source_path "support/tailwind/palette-source.json"
  @output_path "lib/gpui/tailwind/palette.ex"
  @extract_script "support/tailwind/extract-colors.ts"
  @families ~w(slate gray zinc neutral stone red orange amber yellow lime green emerald teal cyan sky blue indigo violet purple fuchsia pink rose)
  @shades ~w(50 100 200 300 400 500 600 700 800 900 950)

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args, strict: [extract: :boolean, check: :boolean])

    if rest != [] or invalid != [],
      do: Mix.raise("invalid arguments: #{inspect(rest ++ invalid)}")

    if opts[:extract] && opts[:check],
      do: Mix.raise("--extract and --check are mutually exclusive")

    if opts[:extract], do: extract!()

    source = read_source!()
    palette = normalize!(source)
    contents = render(palette)

    if opts[:check],
      do: check!(contents),
      else: Mix.Generator.create_file(@output_path, contents, force: true)
  end

  defp extract! do
    package_root = Path.dirname(@extract_script)
    package_path = Path.join(package_root, "node_modules/tailwindcss/package.json")
    colors_path = Path.join(package_root, "node_modules/tailwindcss/src/public/colors.js")

    package = package_path |> File.read!() |> Jason.decode!()

    unless package["version"] == @version do
      Mix.raise("expected tailwindcss #{@version}, found #{inspect(package["version"])}")
    end

    unless sha256(colors_path) == @source_sha256 do
      Mix.raise("#{colors_path} does not match the pinned SHA-256")
    end

    check_typescript!()
    quickbeam = quickbeam!()

    {:ok, _apps} = Application.ensure_all_started(:quickbeam)

    {:ok, runtime} =
      apply(quickbeam, :start, [
        [
          script: Path.expand(@extract_script),
          apis: :node,
          memory_limit: 16 * 1_024 * 1_024,
          max_stack_size: 1 * 1_024 * 1_024,
          max_convert_depth: 8,
          max_convert_nodes: 1_000
        ]
      ])

    colors =
      try do
        case apply(quickbeam, :eval, [
               runtime,
               "globalThis.__gpuiTailwindColors",
               [timeout: 5_000]
             ]) do
          {:ok, colors} when is_map(colors) -> colors
          {:ok, other} -> Mix.raise("Tailwind colors returned #{inspect(other)}")
          {:error, reason} -> Mix.raise("could not evaluate Tailwind colors: #{inspect(reason)}")
        end
      after
        apply(quickbeam, :stop, [runtime])
      end

    source = %{
      "tailwind_version" => @version,
      "source_url" => @source_url,
      "source_sha256" => @source_sha256,
      "colors" => select_colors!(colors)
    }

    contents = source |> Jason.encode_to_iodata!(pretty: true) |> IO.iodata_to_binary()
    Mix.Generator.create_file(@source_path, contents <> "\n", force: true)
  end

  defp select_colors!(colors) do
    ramps =
      Map.new(@families, fn family ->
        ramp = fetch_map!(colors, family)
        {family, Map.new(@shades, &{&1, fetch_binary!(ramp, &1)})}
      end)

    Map.merge(ramps, %{
      "black" => fetch_binary!(colors, "black"),
      "white" => fetch_binary!(colors, "white"),
      "transparent" => fetch_binary!(colors, "transparent")
    })
  end

  defp read_source! do
    source = @source_path |> File.read!() |> Jason.decode!()

    expected = %{
      "tailwind_version" => @version,
      "source_url" => @source_url,
      "source_sha256" => @source_sha256
    }

    unless Map.take(source, Map.keys(expected)) == expected do
      Mix.raise("#{@source_path} does not match the pinned Tailwind source")
    end

    source
  end

  defp normalize!(%{"colors" => colors}) do
    ramps =
      for family <- @families, shade <- @shades, into: %{} do
        value = colors |> fetch_map!(family) |> fetch_binary!(shade)
        {family <> "-" <> shade, parse_rgb!(value)}
      end

    Map.merge(ramps, %{
      "black" => colors |> fetch_binary!("black") |> parse_rgb!(),
      "white" => colors |> fetch_binary!("white") |> parse_rgb!(),
      "transparent" => {:rgba, 0x00000000}
    })
  end

  defp normalize!(_source), do: Mix.raise("#{@source_path} has no colors map")

  defp parse_rgb!("#" <> hex) when byte_size(hex) in [3, 6] do
    expanded =
      case String.graphemes(hex) do
        [r, g, b] -> r <> r <> g <> g <> b <> b
        _six_digits -> hex
      end

    case Integer.parse(expanded, 16) do
      {rgb, ""} -> {:rgb, rgb}
      _other -> Mix.raise("invalid Tailwind color #{inspect("#" <> hex)}")
    end
  end

  defp parse_rgb!(value), do: Mix.raise("invalid Tailwind RGB color #{inspect(value)}")

  defp render(palette) do
    ast =
      quote generated: true do
        defmodule GPUI.Tailwind.Palette do
          @moduledoc false

          @tailwind_version unquote(@version)
          @source_url unquote(@source_url)
          @source_sha256 unquote(@source_sha256)
          @generated_by "mix gpui.tailwind.palette"
          @colors unquote(Macro.escape(palette))

          @spec fetch(String.t()) :: {:ok, {:rgb | :rgba, non_neg_integer()}} | :error
          def fetch(name) when is_binary(name), do: Map.fetch(@colors, name)

          @spec fetch!(String.t()) :: {:rgb | :rgba, non_neg_integer()}
          def fetch!(name) when is_binary(name), do: Map.fetch!(@colors, name)

          @spec colors() :: %{String.t() => {:rgb | :rgba, non_neg_integer()}}
          def colors, do: @colors

          @spec tailwind_version() :: String.t()
          def tailwind_version, do: @tailwind_version

          @spec source_url() :: String.t()
          def source_url, do: @source_url

          @spec source_sha256() :: String.t()
          def source_sha256, do: @source_sha256

          @spec generated_by() :: String.t()
          def generated_by, do: @generated_by
        end
      end

    ast
    |> Macro.to_string()
    |> Code.format_string!()
    |> then(&[&1, ?\n])
    |> IO.iodata_to_binary()
  end

  defp check!(expected) do
    case File.read(@output_path) do
      {:ok, ^expected} ->
        Mix.shell().info("#{@output_path} is current")

      {:ok, _stale} ->
        Mix.raise("#{@output_path} is stale; run mix gpui.tailwind.palette")

      {:error, :enoent} ->
        Mix.raise("#{@output_path} is missing; run mix gpui.tailwind.palette")

      {:error, reason} ->
        Mix.raise("could not read #{@output_path}: #{:file.format_error(reason)}")
    end
  end

  defp quickbeam! do
    if Code.ensure_loaded?(QuickBEAM) do
      QuickBEAM
    else
      Mix.raise("QuickBEAM is required for the explicit Tailwind extraction workflow")
    end
  end

  defp check_typescript! do
    executable =
      System.find_executable("bun") ||
        Mix.raise("bun is required for the explicit Tailwind extraction workflow")

    case System.cmd(executable, ["run", "check"],
           cd: Path.dirname(@extract_script),
           into: IO.stream()
         ) do
      {_output, 0} -> :ok
      {_output, status} -> Mix.raise("Tailwind TypeScript checks failed with status #{status}")
    end
  end

  defp fetch_map!(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_map(value) -> value
      _other -> Mix.raise("missing Tailwind color family #{inspect(key)}")
    end
  end

  defp fetch_binary!(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_binary(value) -> value
      _other -> Mix.raise("missing Tailwind color #{inspect(key)}")
    end
  end

  defp sha256(path) do
    path
    |> File.stream!(64 * 1_024, [])
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end
end
