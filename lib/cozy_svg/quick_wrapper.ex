defmodule CozySVG.QuickWrapper do
  @moduledoc ~S"""
  Creates a wrapper module quickly.

  > This is a high-level abstraction of the basic API provided by `CozySVG`.

  ## Usage

  Assuming the structure of SVG files is like this:

      assets/svg
      ├── logo.svg
      └── misc
          ├── header.svg
          └── footer.svg

  Creates a wrapper module:

      defmodule DemoWeb.SVG do
        use CozySVG.QuickWrapper, root: "assets/svg"
      end

  Then, the generated functions can be used like this:

      DemoWeb.SVG.render("logo")
      DemoWeb.SVG.render("misc/header", class: "w-6 h-auto mr-2")
      DemoWeb.SVG.render("misc/footer", class: "w-6 h-auto mr-2")

  """

  defmacro __using__(opts) do
    root = Keyword.fetch!(opts, :root)

    quote do
      @library_path Path.expand(unquote(root), __DIR__)
      @library CozySVG.compile(@library_path)

      paths = Path.wildcard("#{@library_path}/**/*.svg")
      @paths_hash :erlang.md5(paths)

      for path <- paths do
        @external_resource path
      end

      # https://hexdocs.pm/mix/1.14.4/Mix.Tasks.Compile.Elixir.html#module-__mix_recompile__-0
      def __mix_recompile__?() do
        Path.wildcard("#{@library_path}/**/*.svg") |> :erlang.md5() != @paths_hash
      end

      defp library(), do: @library

      def render(key, attrs \\ []) do
        CozySVG.render(library(), key, attrs)
      end
    end
  end
end
