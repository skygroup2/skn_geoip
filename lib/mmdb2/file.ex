defmodule MMDB2.File do
  @moduledoc """
    provide api for read/write MMDB
  """
  def default_options, do: [double_precision: nil, float_precision: nil, map_keys: :strings]

  def read_mmdb2(file) do
    contents = File.read!(file)
    case split_contents(contents) do
      [_] -> {:error, :no_metadata}
      [data, meta] -> split_data(meta, data)
    end
  end

  def write_mmdb2(_to_file) do
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
end
