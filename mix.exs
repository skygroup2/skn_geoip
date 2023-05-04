defmodule SknGeoip.MixProject do
  use Mix.Project

  def project do
    [
      app: :skn_geoip,
      version: "0.2.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {GeoIP, []},
      extra_applications: [
        :mnesia,
        :logger,
        :jason,
        :gun,
        :skn_lib,
        :skn_proto,
        :runtime_tools,
        :observer_cli
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:skn_lib, git: "git@github.com:skygroup2/skn_lib.git", branch: "main"},
      {:skn_proto, git: "git@github.com:skygroup2/skn_proto.git", branch: "main"},
      {:mmdb2_decoder, "~> 3.0"},
      {:observer_cli, "~> 1.7"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
    ]
  end
end
