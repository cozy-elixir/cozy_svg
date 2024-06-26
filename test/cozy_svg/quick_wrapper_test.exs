defmodule CozySVG.QuickWrapperTest do
  use ExUnit.Case

  describe "CozySVG.QuickWrapper" do
    test "works" do
      defmodule SVG do
        use CozySVG.QuickWrapper, root: "../svgs"
      end

      assert {:ok, "<svg" <> _} = SVG.render("x")
      assert "<svg" <> _ = SVG.render!("x")
    end
  end
end
