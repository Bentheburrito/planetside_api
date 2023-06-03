defmodule PS2.MixProject do
  use Mix.Project

  def project do
    [
      app: :planetside_api,
      version: "0.3.4",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      package: package(),
      name: "PlanetSide 2 API",
      source_url: "https://github.com/Bentheburrito/planetside_api",
      homepage_url: "https://github.com/Bentheburrito/planetside_api"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:httpoison, "~> 1.6"},
      {:websockex, "~> 0.4.2"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp description do
    "A wrapper for the PlanetSide 2 API and Event Streaming service for Elixir."
  end

  defp package do
    [
      name: "planetside_api",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Bentheburrito/planetside_api"}
    ]
  end
end
