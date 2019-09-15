defmodule GeoIP.API do
  require Logger
  import GunEx, only: [
    http_request: 6,
    decode_gzip: 1
  ]

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
end