defmodule CozySVGTest do
  use ExUnit.Case

  @library CozySVG.compile("test/svgs")

  def library(), do: @library

  describe "compile/2" do
    test "traverses the tree, builds nested paths, and strips the .svg from the name" do
      assert Map.get(library(), "x")
      assert Map.get(library(), "nested/list")
      assert Map.get(library(), "more/cube")
    end

    test "can be piped with multiple folders" do
      library =
        CozySVG.compile("test/svgs/more")
        |> CozySVG.compile("test/svgs/nested")

      refute Map.get(library, "x")
      assert Map.get(library, "list")
      assert Map.get(library, "cube")
    end

    test "raises an error when reading an invalid svg file" do
      assert_raise CozySVG.CompileError,
                   "SVG \"invalid\" is invalid due to :invalid_format",
                   fn ->
                     CozySVG.compile("test/svg_invalid")
                   end
    end

    test "raises an error when the key of SVG file is duplicated" do
      assert_raise CozySVG.CompileError,
                   "SVG \"cube\" is duplicated",
                   fn ->
                     CozySVG.compile("test/svgs/more")
                     |> CozySVG.compile("test/svgs/more")
                   end
    end
  end

  describe "render/2" do
    test "retrieves the svg as a safe string" do
      svg = CozySVG.render(library(), "x")
      assert String.starts_with?(svg, "<svg xmlns=")
    end

    test "preserves the tailing </svg>" do
      svg = CozySVG.render(library(), "x")
      assert String.ends_with?(svg, "</svg>")
    end

    test "inserts attributes" do
      svg = CozySVG.render(library(), "x", class: "test_class", "@click": "action")
      assert String.starts_with?(svg, "<svg class=\"test_class\" @click=\"action\" xmlns=")
    end

    test "converts _ in attr name into -" do
      svg = CozySVG.render(library(), "x", test_attr: "some_data")
      assert String.starts_with?(svg, "<svg test-attr=\"some_data\" xmlns=")
    end

    test "raises an error if the svg is not in the library" do
      assert_raise CozySVG.RuntimeError,
                   "SVG \"missing\" not found in library",
                   fn ->
                     CozySVG.render(library(), "missing")
                   end
    end
  end
end
