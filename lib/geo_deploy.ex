defmodule GeoIP.Deploy do
  @moduledoc """
    provide some api for working with geo
  """
  require Logger
  import GunEx, only: [
    http_request: 6,
    decode_gzip: 1
  ]

  def get_db_dir do
    Skn.Config.get(:mmdb_dir, "./mmdb2")
  end

  def set_db_dir(path) do
    Skn.Config.set(:mmdb_dir, path)
  end

  def get_license do
    Skn.Config.get(:mmdb_lic, "xlwBl5KsfAS8fTCu")
  end

  def set_license(lic) do
    Skn.Config.set(:mmdb_lic, lic)
  end

  def check_set_license do
    lic = System.get_env("MAXMIND_LICENSE")
    if lic != nil do
      set_license(lic)
    end
  end

  def get_ipv4(ip) do
    url = "http://lumtest.com/myip.json"
    headers = %{
      "x-forwarded-for" => ip,
      "accept-encoding" => "gzip",
      "connection" => "close"
    }
    try do
      case http_request("GET", url, headers, "", GunEx.default_option(), nil) do
        response when is_map(response) ->
          if response.status_code == 200 do
            decode_gzip(response) |> Jason.decode!()
          else
            {:error, response.status_code}
          end
        exp ->
          {:error, exp}
      end
    catch
      _, exp ->
        Logger.error("trace #{inspect __STACKTRACE__}")
        {:error, exp}
    end
  end

  def get_ipv6(_ip) do
    {:error, :not_implemented}
  end
end
