defmodule GeoIP do
  use Application
  require Logger
  import GunEx, only: [
    http_request: 6,
    get_body: 1
  ]

  def start(_type, _args) do
    :rand.seed :exs64, :os.timestamp
    Application.ensure_all_started(:lager)
    Application.ensure_all_started(:ssh)
    Application.ensure_all_started(:gun)
    Logger.add_backend(LoggerLagerBackend)
    mnesia_init()

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
    end
    :mnesia.wait_for_tables([:skn_config], 600000)
  end

  def download_geoLite() do
    url = "https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz"
    headers = %{}
    bin = http_request("GET", url, headers, "", proxy_option(), nil) |> get_body()
    File.write!("./GeoLite2-Country.tar.gz", bin, [:write, :binary])
  end

  defp proxy_option() do
    default_opts =
      %{
        retry: 0,
        recv_timeout: 25000,
        connect_timeout: 35000,
        retry_timeout: 5000,
        transport_opts: [{:reuseaddr, true}, {:reuse_sessions, false}, {:linger, {false, 0}}]
      }
    default_opts
  end
end

defmodule GeoIP.Sup do
  use Supervisor
  @name  :void_sup
  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init(_args) do
    children = []
    supervise(children, strategy: :one_for_one)
  end
end
