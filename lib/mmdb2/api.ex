defmodule MMDB2.API do
  use GenServer
  require Logger
  import GunEx, only: [
    http_request: 6,
    get_body: 1
  ]
  @name :mmdb2_api
  @mmdb2_cache_db :mmdb2_cache_db

  def create_db() do
    :ets.new(@mmdb2_cache_db, [:public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}])
  end

  def lookup(addr) do
    GenServer.call(@name, {:lookup, format_ip_addr(addr)})
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init(_args) do
    Process.flag(:trap_exit, true)
    Skn.Util.reset_timer(:check_tick, :check_tick, 20_000)
    mmdb = get_geoip_path("GeoLite2-Country")
    {:ok, meta, tree, data} = MMDB2.File.read_mmdb2(mmdb)
    {:ok, %{meta: meta, tree: tree, data: data}}
  end

  def handle_call({:lookup, ip}, _from, %{meta: meta, tree: tree, data: data} = state) do
    case MMDB2.Tree.locate(ip, meta, tree) do
      {:ok, pointer} ->
        options = MMDB2.File.default_options()
        {:reply, {:ok, MMDB2.Data.value(data, pointer - meta.node_count - 16, options)}, state}
      exp ->
        {:reply, exp, state}
    end
  end

  def handle_call(request, from, state) do
    Logger.error "drop #{inspect request} from #{inspect from}"
    {:reply, {:error, :badarg}, state}
  end

  def handle_cast(request, state) do
    Logger.warn "drop #{inspect request}"
    {:noreply, state}
  end

  def handle_info(:check_tick, state) do
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug "drop #{inspect msg}"
    {:noreply, state}
  end

  def code_change(_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(reason, _state) do
    Logger.debug "stopped by #{inspect reason}"
    :ok
  end

  defp format_ip_addr(addr) when is_binary(addr) do
    format_ip_addr(to_charlist(addr))
  end
  defp format_ip_addr(addr) when is_list(addr) do
    {:ok, addr} = :inet.parse_address(addr)
    addr
  end
  defp format_ip_addr(addr) when is_tuple(addr) do
    addr
  end

  def import_mmdb2() do
  end

  # GeoLite2-Country, GeoLite2-ASN, GeoLite2-City
  def get_geoip_path(name) do
    all_files = File.ls!() |> Enum.sort() |> Enum.reverse()
    pattern = name <> "_"
    ret = Enum.find(all_files, fn x -> File.dir?(x) and String.contains?(x, pattern) end)
    if is_binary(ret) do
      Enum.each(all_files, fn x ->
        if File.dir?(x) and String.contains?(x, pattern) and x != ret, do: File.rm!(x)
      end)
      "/tmp/" <> ret <> "/#{name}.mmdb"
    else
      download_geoip_db("#{name}.tar.gz")
      get_geoip_path(name)
    end
  end

  def download_geoip_db(file) do
    tar = "/tmp/" <> file
    if File.exists?(tar) == false or check_create_time(tar) == true do
      url = "https://geolite.maxmind.com/download/geoip/database/#{file}"
      bin = http_request("GET", url, %{}, "", GunEx.default_option(), nil) |> get_body()
      File.write!(tar, bin, [:write, :binary])
    end
    :erl_tar.extract(tar, [:compressed])
  end

  def check_create_time(tar) do
    c = (File.stat!(tar).ctime |> :calendar.datetime_to_gregorian_seconds) - 62167219200
    ts_now = System.system_time(:second)
    ts_now - c >= 24 * 3600
  end
end