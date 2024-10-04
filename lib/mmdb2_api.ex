defmodule MMDB2.API do
  @moduledoc """
    scalable worker for query GeoIP
  """
  use GenServer
  require Logger
  import Skn.Util, only: [
    reset_timer: 3
  ]
  @worker_size 8

  def round_robin() do
    seq = Skn.Counter.update_counter(:lookup_seq, 1) |> rem(@worker_size)
    worker_name(seq)
  end

  def lookup(addr) do
    GenServer.call(round_robin(), {:lookup, format_ip_addr(addr)})
  catch
    _, _exp ->
      {:error, :timeout}
  end

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: worker_name(id))
  end

  def init(id) do
    Process.flag(:trap_exit, true)
    reset_timer(:reload_db, :reload_db, 10_000)
    {:ok, %{id: id, meta: nil, tree: nil, data: nil, version: nil}}
  end

  def handle_call({:lookup, _ip}, _from, %{meta: nil, tree: nil, data: nil} = state) do
    {:reply, {:error, :db_not_ready}, state}
  end

  def handle_call({:lookup, ip}, _from, %{meta: meta, tree: tree, data: data} = state) do
    case MMDB2Decoder.lookup(ip, meta, tree, data) do
      {:ok, value} ->
        {:reply, {:ok, value}, state}
      exp ->
        {:reply, exp, state}
    end
  end

  def handle_call(request, from, state) do
    Logger.error "drop #{inspect request} from #{inspect from}"
    {:reply, {:error, :badarg}, state}
  end

  def handle_cast(request, state) do
    Logger.error "drop #{inspect request}"
    {:noreply, state}
  end

  def handle_info(:reload_db, %{version: version} = state) do
    # check read new db
    reset_timer(:reload_db, :reload_db, 120_000)
    if GeoIP.Config.get_version() != version do
      case MMDB2.Updater.get_mmdb(5_000) do
        {:error, _reason} ->
          {:noreply, state}
        {mmdb, version} ->
          {:ok, meta, tree, data} = read_mmdb2(mmdb)
          {:noreply, %{state| meta: meta, tree: tree, data: data, version: version}}
      end
    else
      {:noreply, state}
    end
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

  def read_mmdb2(filename) do
    database = File.read!(filename)
    MMDB2Decoder.parse_database(database)
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

  Enum.each(0..(@worker_size - 1), fn x ->
    name = String.to_atom("mmdb_api#{x}")
    def worker_name(unquote(x)), do: unquote(name)
  end)

  def worker_size(), do: @worker_size
end
