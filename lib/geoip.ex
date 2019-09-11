defmodule GeoIP do
  require Logger
  import GunEx, only: [
    http_request: 6,
    get_body: 1
  ]

  def download_geoLite() do
    url = "https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz"
    headers = %{}
    http_request("GET", url, headers, "", proxy_option(), nil)
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
