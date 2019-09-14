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
      case http_request("GET", url, headers, "", default_proxy_option(), nil) do
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

  def default_proxy_option() do
    %{
      recv_timeout: 25000,
      connect_timeout: 35000,
      retry: 0,
      retry_timeout: 5000,
      transport_opts: [{:reuseaddr, true}, {:reuse_sessions, false}, {:linger, {false, 0}}, {:versions, [:"tlsv1.2"]}]
    }
  end
end