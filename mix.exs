defmodule DeepSinker.MixProject do
  use Mix.Project

  def project do
    [
      app: :deep_sinker,
      version: "2.0.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      package: package(),
      source_url: "https://github.com/sankaku-deltalab/deep_sinker",
      homepage_url: "https://github.com/sankaku-deltalab/deep_sinker",
      docs: docs()
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
      {:typed_struct, "~> 0.3.0"},
      {:tmp, "~> 0.2.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Customizable directory traverser."
  end

  defp package do
    [
      contributors: ["Sankaku <sankaku_dlt.45631@outlook.jp>"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/sankaku-deltalab/deep_sinker"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end
end
