defmodule GeoIP do
  @moduledoc """
    application for geolocation
  """
  use Application
  require Logger

  def start(_type, _args) do
    :rand.seed :exs64, :os.timestamp
    Application.ensure_all_started(:lager)
    Application.ensure_all_started(:gun)
    Logger.add_backend(LoggerLagerBackend)
    mnesia_init()
    GeoIP.Deploy.check_set_license()
    ret = GeoIP.Sup.start_link()
    ret
  end

  def mnesia_init do
    Skn.Counter.create_db()
    info = :mnesia.system_info(:all)
    if info[:use_dir] == false  do
      Logger.info("no schema existed, create schema for #{node()}")
      :mnesia.stop()
      :mnesia.create_schema([node()])
      :mnesia.start()
    end
    # initialize table here
    if info[:use_dir] == false do
      Logger.info("creating all mnesia table")
      Skn.Config.create_table()
      GeoIP.Repo.create_table()
    end
    :mnesia.wait_for_tables([:skn_config], 600_000)
  end
end

defmodule GeoIP.Sup do
  @moduledoc false
  use Supervisor
  @name  :geoip_sup
  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init(_args) do
    children = Enum.map(0..(MMDB2.API.worker_size() - 1), fn id ->
      Supervisor.child_spec({MMDB2.API, id}, id: MMDB2.API.worker_name(id), restart: :transient, shutdown: 5000)
    end)
    Supervisor.init([MMDB2.Updater| children], strategy: :one_for_one)
  end
end
