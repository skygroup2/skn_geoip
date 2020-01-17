defmodule GeoIP do
  use Application
  require Logger

  def start(_type, _args) do
    :rand.seed :exs64, :os.timestamp
    Application.ensure_all_started(:lager)
    Application.ensure_all_started(:ssh)
    Application.ensure_all_started(:gun)
    Logger.add_backend(LoggerLagerBackend)
    mnesia_init()

    ret = GeoIP.Sup.start_link()
    GeoIP.Sup.start_api_worker()
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
    :mnesia.wait_for_tables([:skn_config], 600000)
  end
end

defmodule GeoIP.Sup do
  use Supervisor
  @name  :geoip_sup
  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init(_args) do
    children = [worker(MMDB2.Updater, [])]
    supervise(children, strategy: :one_for_one)
  end

  def start_api_worker() do
    Enum.each(0..(MMDB2.API.size() - 1), fn x ->
      opts = [id: {:mmdb2_api, x}, function: :start_link, restart: :transient, shutdown: 5000, modules: [MMDB2.API]]
      {:ok, _pid} = Supervisor.start_child(:geoip_sup, worker(MMDB2.API, [x], opts))
    end)
  end
end
