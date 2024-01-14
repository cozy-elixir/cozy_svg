defmodule CozySVG.MixProject do
  use Mix.Project

  @version "0.2.0"
  @description "A tiny and fast library to compile and render SVG files."
  @source_url "https://github.com/cozy-elixir/cozy_svg"

  def project do
    [
      app: :cozy_svg,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: @description,
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_check, "~> 0.15.0", only: [:dev], runtime: false},
      {:credo, ">= 0.0.0", only: [:dev], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev], runtime: false}
    ]
  end

  defp package do
    %{
      licenses: ["Apache-2.0"],
      maintainers: ["Zeke Dou", "Boyd Multerer"],
      links: %{"GitHub" => @source_url}
    }
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end

  defp aliases do
    [publish: ["hex.publish", "tag"], tag: &tag_release/1]
  end

  defp tag_release(_) do
    Mix.shell().info("Tagging release as v#{@version}")
    System.cmd("git", ["tag", "v#{@version}"])
    System.cmd("git", ["push", "--tags"])
  end
end
