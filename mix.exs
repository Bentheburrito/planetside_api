defmodule PS2.MixProject do
  use Mix.Project

  def project do
    [
      app: :planetside_api,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
			extra_applications: [:logger],
			mod: {PS2, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
			{:httpoison, "~> 1.6"},
			{:websockex, "~> 0.4.2"},
			{:gen_stage, "~> 1.0"}
    ]
  end
end
