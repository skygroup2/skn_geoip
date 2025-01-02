defmodule MMDB2.Updater do
  @moduledoc """
    periodic updating free mmdb2
  """
  use GenServer
  require Logger
  import Skn.Util, only: [
    reset_timer: 3
  ]
  @name :mmdb_updater

  def get_mmdb(timeout \\ :infinity) do
    GenServer.call(@name, :get_mmdb, timeout)
  catch
    _, _exp ->
      {:error, :timeout}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(_args) do
    Process.flag(:trap_exit, true)
    Process.flag(:fullsweep_after, 0)
    reset_timer(:check_update, :check_update, 5_000)
    {:ok, %{mmdb: nil, waiter: [], version: GeoIP.Config.get_version()}}
  end

  def handle_call(:get_mmdb, from, %{mmdb: mmdb, version: version, waiter: waiter} = state) do
    if mmdb == nil do
      {:noreply, %{state| waiter: [from| waiter]}}
    else
      {:reply, {mmdb, version}, state}
    end
  end

  def handle_call(request, from, state) do
    Logger.error("drop #{inspect request} from #{inspect from}")
    {:reply, {:error, :badarg}, state}
  end

  def handle_cast(request, state) do
    Logger.error("drop #{inspect request}")
    {:noreply, state}
  end

  def handle_info(:check_update, state) do
    case get_geoip_path("GeoLite2-Country") do
      {:error, :download_limit} ->
        reset_timer(:check_update, :check_update, 1200_000)
        {:noreply, state}
      {:error, _reason} ->
        reset_timer(:check_update, :check_update, 120_000)
        {:noreply, state}
      {mmdb, version} ->
        GeoIP.Config.set_version(version)
        Enum.each(state.waiter, fn x -> GenServer.reply(x, {mmdb, version}) end)
        reset_timer(:check_update, :check_update, Skn.Config.get(:check_update_mmdb, 7_200_000))
        {:noreply, %{mmdb: mmdb, version: version, waiter: []}}
    end
  catch
    _, exp ->
      Logger.error("check_update error #{inspect exp}/ #{inspect __STACKTRACE__}")
      reset_timer(:check_update, :check_update, 20_000)
      {:noreply, state}
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
  def get_geoip_path(name) do
    db_dir = GeoIP.Config.get_db_dir()
    check_create_dir(db_dir)
    # filter real db dir
    pattern = name <> "_"
    pz = byte_size(pattern)
    tar =  db_dir <> "/" <> name <> ".tar.gz"
    mmdb_dir = File.ls!(db_dir)
    |> Enum.filter(fn x -> File.dir?(db_dir <> "/" <> x) and String.contains?(x, pattern) end)
    |> Enum.sort() |> Enum.reverse()
    case mmdb_dir do
      [<<_ :: binary-size(pz), yy :: binary-size(4), mm :: binary-size(2), dd :: binary-size(2)>> = v| remain] ->
        clean_old_db(db_dir, remain)
        release_date = Date.from_iso8601!(Enum.join([yy, mm, dd], "-"))
        today = Date.utc_today()
        if Date.diff(today, release_date) >= 7 and check_create_time(tar) do
          case download_and_extract_db(db_dir, name) do
            {:error, _reason} ->
              Logger.info("Using #{v}")
              {db_dir <> "/" <> v <> "/#{name}.mmdb", release_date}
            _ ->
             get_geoip_path(name)
          end
        else
          Logger.info("Using #{v}")
          {db_dir <> "/" <> v <> "/#{name}.mmdb", release_date}
        end
      [] ->
        case download_and_extract_db(db_dir, name) do
          {:error, reason} ->
            {:error, reason}
          _ ->
            get_geoip_path(name)
        end
    end
  end

  defp default_proxy_option, do: CQ.HttpEx.sync_proxy_option(%{}, 25_000, 90_000)
  defp make_request(method, url, headers, body) do
    CQ.HttpEx.request("GEO", method, url, headers, body, default_proxy_option(), 1, [], nil)
  end

  defp is_download_limit?(bin) do
    byte_size(bin) <= 128 and String.contains?(bin, "download limit reached")
  end

  def download_and_extract_db(db_dir, file) do
    tar = db_dir <> "/" <> file <> ".tar.gz"
    maxmind_license = GeoIP.Config.get_license()
    if maxmind_license != nil do
      Logger.info("Try to download #{file} : #{maxmind_license}")
      url = "https://download.maxmind.com/app/geoip_download?edition_id=#{file}&license_key=#{maxmind_license}&suffix=tar.gz"
      bin = make_request("GET", url, %{}, "") |> Map.fetch!(:body)
      if is_download_limit?(bin) == false do
        File.write!(tar, bin, [:write, :binary])
        Logger.info("Finished download #{file}")
        :erl_tar.extract(tar, [:compressed, {:cwd, to_charlist(db_dir)}])
      else
        Logger.error("#{String.trim(bin)}")
        {:error, :download_limit}
      end
    else
      Logger.error("Invalid license key #{maxmind_license}")
      {:error, :invalid_license}
    end
  end

  def clean_old_db(db_dir, remain) do
    remain_size = length(remain)
    if remain_size > 2 do
      Enum.slice(remain, 2, remain_size - 2)
      |> Enum.each(fn x -> File.rm_rf!(db_dir <> "/" <> x) end)
    else
      :ok
    end
  end

  def check_create_dir(db_dir) do
    if File.exists?(db_dir) == false, do: File.mkdir(db_dir)
  end

  def check_create_time(tar) do
    c = (File.stat!(tar).ctime |> :calendar.datetime_to_gregorian_seconds) - 62_167_219_200
    ts_now = System.system_time(:second)
    ts_now - c >= 2 * 3600
  end
end
