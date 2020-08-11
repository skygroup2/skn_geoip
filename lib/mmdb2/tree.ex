defmodule MMDB2.Tree do
  @moduledoc """
    api for traverse mmdb tree for looking geoip
  """
  use Bitwise

  def locate({a, b, c, d}, %{ip_version: 6, node_count: node_count, record_size: record_size}, tree) do
    traverse(<<a :: size(8), b :: size(8), c :: size(8), d :: size(8)>>, 96, node_count, record_size, tree)
  end

  def locate({a, b, c, d}, %{node_count: node_count, record_size: record_size}, tree) do
    traverse(<<a :: size(8), b :: size(8), c :: size(8), d :: size(8)>>, 0, node_count, record_size, tree)
  end

  def locate({0, 0, 0, 0, 0, 65_535, a, b}, meta, tree) do
    locate({a >>> 8, a &&& 0x00FF, b >>> 8, b &&& 0x00FF}, meta, tree)
  end

  def locate({_, _, _, _, _, _, _, _}, %{ip_version: 4}, _), do: {:ok, 0}

  def locate({a, b, c, d, e, f, g, h}, %{node_count: node_count, record_size: record_size}, tree) do
    traverse(<<a :: size(16), b :: size(16), c :: size(16), d :: size(16),
      e :: size(16), f :: size(16), g :: size(16), h :: size(16)>>, 0, node_count, record_size, tree)
  end

#  def fold(0, _record_size, _tree, _data, acc, _fun) do
#    acc
#  end
#
#  def fold(node_count, record_size, tree, data, acc, fun) do
#
#  end

  defp traverse(<<node_bit :: size(1), rest :: bitstring>>, offset, node_count, record_size, tree) when offset < node_count do
    traverse(rest, read_node(offset, node_bit, record_size, tree), node_count, record_size, tree)
  end

  defp traverse(_, offset, node_count, _, _) when offset > node_count, do: {:ok, offset}
  defp traverse(_, offset, node_count, _, _) when offset == node_count, do: {:ok, 0}
  defp traverse(_, offset, node_count, _, _) when offset < node_count, do: {:error, :node_below_count}

  def read_node(offset, index, record_size, tree) do
    node_start = div(offset * record_size, 4)
    node_len = div(record_size, 4)
    node_part = binary_part(tree, node_start, node_len)
    case index do
      0 ->
        record_half = rem(record_size, 8)
        record_left = record_size - record_half
        <<low :: size(record_left), high :: size(record_half), _ :: bitstring>> = node_part
        low + (high <<< record_left)
      1 ->
        <<_ :: size(record_size), right :: size(record_size)>> = node_part
        right
    end
  end
end
