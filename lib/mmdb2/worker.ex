defmodule MMDB2.Worker do
  import GunEx, only: [
    http_request: 6,
    get_body: 1
  ]

  def lookup(ip, meta, tree, data, options \\ []) do
    options = Keyword.merge(default_options(), options)

    case MMDB2.Tree.locate(ip, meta, tree) do
      {:error, _} = error -> error
      {:ok, pointer} -> {:ok, MMDB2.Data.value(data, pointer - meta.node_count - 16, options)}
    end
  end

  def read_mmdb2(name) do
    file = get_geoip_path(name)
    contents = File.read!(file)
    case split_contents(contents) do
      [_] -> {:error, :no_metadata}
      [data, meta] -> split_data(meta, data)
    end
  end

  def write_mmdb2() do
    :ok
  end

  @metadata_marker <<0xAB, 0xCD, 0xEF>> <> "MaxMind.com"
  @metadata_max_size 128 * 1024
  def split_contents(contents) when byte_size(contents) > @metadata_max_size do
    :binary.split(contents, @metadata_marker, scope: {byte_size(contents), -@metadata_max_size})
  end

  def split_contents(contents), do: :binary.split(contents, @metadata_marker)

  def split_data(meta, data) do
    meta = MMDB2.Data.value(meta, 0, default_options())

    meta = %{
      binary_format_major_version: meta["binary_format_major_version"],
      binary_format_minor_version: meta["binary_format_minor_version"],
      build_epoch: meta["build_epoch"],
      database_type: meta["database_type"],
      description: meta["description"],
      ip_version: meta["ip_version"],
      languages: meta["languages"],
      node_byte_size: 0,
      node_count: meta["node_count"],
      record_size: meta["record_size"],
      tree_size: 0
    }

    %{node_count: node_count, record_size: record_size} = meta

    node_byte_size = div(record_size, 4)
    tree_size = node_count * node_byte_size

    if tree_size < byte_size(data) do
      meta = %{meta | node_byte_size: node_byte_size}
      meta = %{meta | tree_size: tree_size}

      tree = binary_part(data, 0, tree_size)
      data_size = byte_size(data) - byte_size(tree) - 16
      data = binary_part(data, tree_size + 16, data_size)

      {:ok, meta, tree, data}
    else
      {:error, :invalid_node_count}
    end
  end

  def default_options, do: [double_precision: nil, float_precision: nil, map_keys: :strings]

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