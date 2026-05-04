defmodule PS2.MixProject do
  use Mix.Project

  def project do
    [
      app: :planetside_api,
      version: "1.0.0",
      elixir: "~> 1.18",
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
      {:req, "~> 0.5.10"},
      {:mint_web_socket, "~> 1.0"},
      {:ex_doc, "~> 0.37.3", only: :dev, runtime: false}
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
