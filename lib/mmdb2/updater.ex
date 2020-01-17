defmodule MMDB2.Updater do
  use GenServer
  require Logger
  import GunEx, only: [
    http_request: 6,
    get_body: 1
  ]
  @name :mmdb2_updater

  def wait_for_ready() do
    GenServer.call(@name, :wait_for_ready, :infinity)
  end

  def sync_run(fun) do
    GenServer.call(@name, {:sync_run, fun}, :infinity)
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def init(_args) do
    Process.flag(:trap_exit, true)
    send(self(), :check_update)
    {:ok, %{ready: false, waiter: []}}
  end

  def handle_call({:sync_run, fun}, _from, state) when is_function(fun) do
    ret = fun.()
    {:reply, ret, state}
  end

  def handle_call(:wait_for_ready, from, %{ready: ready, waiter: waiter} = state) do
    if ready == true do
      {:reply, true, state}
    else
      {:noreply, %{state| waiter: [from| waiter]}}
    end
  end

  def handle_call(request, from, state) do
    Logger.error("drop #{inspect request} from #{inspect from}")
    {:reply, {:error, :badarg}, state}
  end

  def handle_cast(request, state) do
    Logger.warn("drop #{inspect request}")
    {:noreply, state}
  end

  def handle_info(:check_update, state) do
    try do
      _ = get_geoip_path("GeoLite2-Country")
      Enum.each(state.waiter, fn x -> GenServer.reply(x, true) end)
      {:noreply, %{ready: true, waiter: []}}
    catch
      _, exp ->
        Logger.error("check_update error #{inspect exp}/ #{inspect __STACKTRACE__}")
        Skn.Util.reset_timer(:check_update, :check_update, 60_000)
        {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("drop #{inspect msg}")
    {:noreply, state}
  end

  def code_change(_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(reason, _state) do
    Logger.debug("stopped by #{inspect reason}")
    :ok
  end

  # GeoLite2-Country, GeoLite2-ASN, GeoLite2-City
  @mmdb2_dir "./.mmdb2"
  def get_geoip_path(name) do
    if File.exists?(@mmdb2_dir) == false, do: File.mkdir(@mmdb2_dir)
    all_files = File.ls!(@mmdb2_dir) |> Enum.sort() |> Enum.reverse()
    pattern = name <> "_"
    ret = Enum.find(all_files, fn x -> File.dir?(@mmdb2_dir <> "/" <> x) and String.contains?(x, pattern) end)
    if is_binary(ret) do
      Enum.each(all_files, fn x ->
        if File.dir?(x) and String.contains?(x, pattern) and x != ret, do: File.rm!(x)
      end)
      @mmdb2_dir <> "/" <> ret <> "/#{name}.mmdb"
    else
      download_geoip_db(name)
      get_geoip_path(name)
    end
  end

  def download_geoip_db(file) do
    tar = @mmdb2_dir <> "/" <> file <> ".tar.gz"
    if File.exists?(tar) == false or check_create_time(tar) == true do
      maxmind_license = Skn.Config.get(:maxmind_license, System.get_env("MAXMIND_LICENSE", "xlwBl5KsfAS8fTCu"))
      Logger.info("Try to download #{file} : #{maxmind_license}")
      url = "https://download.maxmind.com/app/geoip_download?edition_id=#{file}&license_key=#{maxmind_license}&suffix=tar.gz"
      bin = http_request("GET", url, %{}, "", GunEx.default_option(), nil) |> get_body()
      File.write!(tar, bin, [:write, :binary])
      Logger.info("Finished download #{file}")
    end
    :erl_tar.extract(tar, [:compressed, {:cwd, to_charlist(@mmdb2_dir)}])
  end

  def check_create_time(tar) do
    c = (File.stat!(tar).ctime |> :calendar.datetime_to_gregorian_seconds) - 62167219200
    ts_now = System.system_time(:second)
    ts_now - c >= 24 * 3600
  end

end