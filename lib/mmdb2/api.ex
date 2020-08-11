defmodule MMDB2.API do
  @moduledoc """
    scalable worker for query GeoIP
  """
  use GenServer
  require Logger

  def size() do
    4
  end

  def name(id) do
    String.to_atom("mmdb2_api#{rem(id, size())}")
  end

  def round_robin() do
    name(Skn.Counter.update_counter(:lookup_seq, 1))
  end

  def lookup(addr) do
    GenServer.call(round_robin(), {:lookup, format_ip_addr(addr)})
  end

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: name(id))
  end

  def init(id) do
    Process.flag(:trap_exit, true)
    Skn.Util.reset_timer(:check_tick, :check_tick, 20_000)
    MMDB2.Updater.wait_for_ready()
    mmdb = MMDB2.Updater.get_geoip_path("GeoLite2-Country")
    {:ok, meta, tree, data} = MMDB2.File.read_mmdb2(mmdb)
    {:ok, %{id: id, meta: meta, tree: tree, data: data}}
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
end
