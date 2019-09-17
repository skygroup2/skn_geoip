defmodule SknGeoip.MixProject do
  use Mix.Project

  def project do
    [
      app: :skn_geoip,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {GeoIP, []},
      extra_applications: [:mnesia, :logger, :logger_lager_backend, :ssh, :gun, :gen_statem2]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:logger_lager_backend, git: "https://github.com/gskynet/logger_lager_backend.git", branch: "master"},
      {:skn_lib, git: "git@gitlab.com:gskynet_lib/skn_lib.git", branch: "master"},
      {:skn_proto, git: "git@gitlab.com:gskynet_lib/skn_proto.git", branch: "master"},
      {:lager, "~> 3.8", override: true}
    ]
  end
end
