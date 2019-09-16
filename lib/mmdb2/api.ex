defmodule MMDB2.API do
  import GunEx, only: [
    http_request: 6,
    get_body: 1
  ]

  def create_db() do

  end

  def lookup(ip, meta, tree, data, options \\ []) do
    options = Keyword.merge(MMDB2.File.default_options(), options)

    case MMDB2.Tree.locate(ip, meta, tree) do
      {:error, _} = error -> error
      {:ok, pointer} -> {:ok, MMDB2.Data.value(data, pointer - meta.node_count - 16, options)}
    end
  end



  def import_mmdb2() do
    cc = "GeoLite2-Country"
    asn = "GeoLite2-ASN"
    city = "GeoLite2-City"

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
      "./" <> ret <> "/#{name}.mmdb"
    else
      download_geoip_db("#{name}.tar.gz")
      get_geoip_path(name)
    end
  end

  def download_geoip_db(file) do
    tar = "./" <> file
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