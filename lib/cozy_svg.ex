defmodule CozySVG do
  @moduledoc """
  A tiny and fast library to compile and render SVG files.

  `CozySVG` reads the SVG files at compile-time and provides runtime access
  through a term stored in the BEAM file, which is very fast to access.

  ## Why use it?

  It is recommended to embed the SVG data into web pages instead of asking
  the browser to make additional requests to servers. This makes web pages load
  faster.

  `CozySVG` provides the key ability to do this - reading the SVG files as
  strings in an efficient way. That's the key.

  ## Usage

  To use `CozySVG`, it's better to create a wrapper module instead of calling
  the low-level API directly.

  ### create wrapper module with pre-built macro

  See `CozySVG.QuickWrapper` for more details.

  ### create wrapper module with low-level API

  This method offers the greatest flexibility, allowing you to customize naming
  , rendering or compiling as required.

  An example:

      defmodule DemoWeb.SVG do
        # Build the library at compile time
        @library CozySVG.compile("assets/svg")

        # Accesses the library at runtime
        defp library(), do: @library

        # Render an SVG from the library
        def render(key, attrs \\ []) do
          CozySVG.render(library(), key, attrs)
        end
      end

  `DemoWeb.SVG.render/1` / `DemoWeb.SVG.render/2` will be ready to use.

  > `@library` should be accessed through a function.
  >
  > The library could be very large, wrapping it with a function ensures that 
  > it is only stored as a term in BEAM file once.

  ### The requirements for SVG files

  Every SVG file must contain a single valid `<svg></svg>` tag.

  Anything before the `<svg>` tag or after the `</svg>` tag is treated as
  comment and stripped from the content during compilation.

  ## Phoenix Integration

  ### `svg/1` component

  An example:

      use Phoenix.Component

      attr :key, :string, required: true, doc: "The key for SVG file."
      attr :rest, :global, doc: "Additional attributes to add to the <svg> tag."

      def svg(assigns) do
        ~H\"\"\"
        <%= raw DemoWeb.SVG.render(@key, @rest) %>
        \"\"\"
      end
        
  ### Live reloading

  Enable live reloading by telling Phoenix to watch the SVG directory:

      live_reload: [
        patterns: [
          # ...
          ~r"assets/svg/*/.*(svg)$"
        ]
      ]

  """

  @type library :: map()
  @type path :: String.t()
  @type key :: String.t()
  @type attrs :: keyword() | map()

  @doc """
  Compiles a folder of `*.svg` files into a library.

  The folder and it's subfolders will be traversed and all valid `*.svg` files
  will be added to the library with a key that is relative path of the SVG file
  minus the `.svg` part.

  For example, if you compile the folder "assets/svg" and it finds a file with
  the path "assets/svg/heroicons/calendar.svg", then the key for that SVG is
  `"heroicons/calendar"` in the library.

  ## Examples

      # Compiles a folder
      CozySVG.compile("assets/svg")

      # Compiles multiple folders
      CozySVG.compile("assets/svg_a")
      |> CozySVG.compile("assets/svg_b")

      # Or, compiles multiple folders with a neater pipeline
      %{}
      |> CozySVG.compile("assets/svg_a")
      |> CozySVG.compile("assets/svg_b")

  """
  @spec compile(library(), path()) :: library()
  def compile(%{} = library \\ %{}, root) when is_binary(root) do
    root = Path.expand(root)

    unless File.dir?(root) do
      raise CozySVG.CompileError, "SVG root at #{root} does not exist"
    end

    root
    |> Path.join("**/*.svg")
    |> Path.wildcard()
    |> Enum.reduce(library, fn path, acc ->
      key = get_key(path, root)

      with :ok <- validate_key(library, key),
           {:ok, svg} <- read_svg(path) do
        Map.put(acc, key, svg)
      else
        {:error, :duplicate, key} ->
          raise CozySVG.CompileError, "SVG #{inspect(key)} is duplicated"

        {:error, :file, error} ->
          raise CozySVG.CompileError, "SVG #{inspect(key)} is invalid due to #{inspect(error)}"
      end
    end)
  end

  defp get_key(path, root) do
    path
    |> String.trim(root)
    |> String.trim("/")
    |> String.trim_trailing(".svg")
  end

  defp validate_key(library, key) do
    case Map.fetch(library, key) do
      {:ok, _} -> {:error, :duplicate, key}
      _ -> :ok
    end
  end

  @re_svg ~r|<svg\s*[^>]*?>([\s\S]*?)</svg>|
  defp read_svg(path) do
    open_tag = "<svg"
    close_tag = "</svg>"

    with {:ok, svg} <- File.read(path),
         {:valid_string?, true} <- {:valid_string?, String.valid?(svg)},
         {:valid_format?, true} <- {:valid_format?, Regex.match?(@re_svg, svg)} do
      content =
        svg
        |> String.trim()
        |> String.trim_leading(open_tag)
        |> String.trim_trailing(close_tag)

      {:ok, {open_tag, content, close_tag}}
    else
      {:error, error} ->
        {:error, :file, error}

      {:valid_string?, false} ->
        {:error, :file, :invalid_chars}

      {:valid_format?, false} ->
        {:error, :file, :invalid_format}
    end
  end

  @doc """
  Renders an SVG as a string.

  The named svg must be in the provided library, which should be built using the
  compile function.

  ## Examples

      iex> CozySVG.render(library(), "heroicons/menu")
      "<svg xmlns= ... </svg>"

  """
  @spec render(library(), key()) :: String.t()
  def render(%{} = library, key) do
    render(library, key, [])
  end

  @doc """
  Renders an SVG as a string.

  The named svg must be in the provided library, which should be built using the
  compile function.

  The `attrs` will be inserted as attributes of the `<svg></svg>` tag. But keep
  one thing in mind, the underscore character `"_"` in attribute name will be
  converted to the hyphen character `"-"`.

  ## Examples

      iex> CozySVG.render(library(), "heroicons/menu", class: "h-5 w-5")
      "<svg class=\"h-5 w-5\" xmlns= ... </svg>"

      iex> CozySVG.render(library(), "heroicons/menu", %{phx_click: "action"})
      "<svg phx-click=\"action\" xmlns= ... </svg>"

  """
  @spec render(library(), key(), attrs()) :: String.t()
  def render(%{} = library, key, attrs) when is_list(attrs) do
    case Map.fetch(library, key) do
      {:ok, {open_tag, content, close_tag}} ->
        open_tag <> render_attrs(attrs) <> content <> close_tag

      _ ->
        raise CozySVG.RuntimeError, "SVG #{inspect(key)} not found in library"
    end
  end

  def render(%{} = library, key, attrs) when is_map(attrs) do
    attrs = Map.to_list(attrs)
    render(library, key, attrs)
  end

  defp render_attrs(attrs), do: render_attrs(attrs, "")

  defp render_attrs([], acc), do: acc

  defp render_attrs([{name, value} | tail], acc) do
    name = to_string(name) |> String.replace("_", "-")
    render_attrs(tail, "#{acc} #{name}=#{inspect(value)}")
  end
end

defmodule CozySVG.CompileError do
  @moduledoc false
  defexception message: nil, svg: nil
end

defmodule CozySVG.RuntimeError do
  @moduledoc false
  defexception message: nil
end
