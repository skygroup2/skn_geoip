defmodule MMDB2.Data do
  # standard data types
  @binary 2
  @bytes 4
  @double 3
  @extended 0
  @map 7
  @unsigned_16 5
  @unsigned_32 6
  @pointer 1

  # extended data types
  @extended_array 4
  @extended_boolean 7
  @extended_cache_container 5
  @extended_end_marker 6
  @extended_float 8
  @extended_signed_32 1
  @extended_unsigned_64 2
  @extended_unsigned_128 3

  @doc """
    Decodes the node at the given offset.
  """
  def value(data, offset, options) when byte_size(data) > offset and offset >= 0 do
    <<_::binary-size(offset), rest::binary>> = data
    {value, _rest} = decode(rest, data, options)
    value
  end
  def value(_, _, _), do: nil

  defp decode(<<@binary::size(3), 0::size(5), part_rest::binary>>, _, _) do
    {"", part_rest}
  end

  defp decode(<<@binary::size(3), 29::size(5), len::size(8), part_rest::binary>>, _, _) do
    decode_binary(part_rest, 29 + len)
  end

  defp decode(<<@binary::size(3), 30::size(5), len::size(16), part_rest::binary>>, _, _) do
    decode_binary(part_rest, 285 + len)
  end

  defp decode(<<@binary::size(3), 31::size(5), len::size(24), part_rest::binary>>, _, _) do
    decode_binary(part_rest, 65_821 + len)
  end

  defp decode(<<@binary::size(3), len::size(5), part_rest::binary>>, _, _) do
    decode_binary(part_rest, len)
  end

  defp decode(<<@bytes::size(3), 0::size(5), part_rest::binary>>, _, _) do
    {"", part_rest}
  end

  defp decode(<<@bytes::size(3), 29::size(5), len::size(8), part_rest::binary>>, _, _) do
    decode_binary(part_rest, 29 + len)
  end

  defp decode(<<@bytes::size(3), 30::size(5), len::size(16), part_rest::binary>>, _, _) do
    decode_binary(part_rest, 285 + len)
  end

  defp decode(<<@bytes::size(3), 31::size(5), len::size(24), part_rest::binary>>, _, _) do
    decode_binary(part_rest, 65_821 + len)
  end

  defp decode(<<@bytes::size(3), len::size(5), part_rest::binary>>, _, _) do
    decode_binary(part_rest, len)
  end

  defp decode(<<@double::size(3), 8::size(5), value::size(64)-float, part_rest::binary>>, _, options) do
    {maybe_round_float(value, options[:double_precision]), part_rest}
  end

  defp decode(<<@double::size(3), 8::size(5), value::size(64), part_rest::binary>>, _, options) do
    {maybe_round_float(:erlang.float(value), options[:double_precision]), part_rest}
  end

  defp decode(<<@extended::size(3), 29::size(5), len::size(8), @extended_array, part_rest::binary>>, data_full, options) do
    decode_array(part_rest, data_full, 28 + len, [], options)
  end

  defp decode(<<@extended::size(3), 30::size(5), len::size(16), @extended_array, part_rest::binary>>, data_full, options) do
    decode_array(part_rest, data_full, 285 + len, [], options)
  end

  defp decode(<<@extended::size(3), 31::size(5), len::size(24), @extended_array, part_rest::binary>>, data_full, options) do
    decode_array(part_rest, data_full, 65_821 + len, [], options)
  end

  defp decode(<<@extended::size(3), len::size(5), @extended_array, part_rest::binary>>, data_full, options) do
    decode_array(part_rest, data_full, len, [], options)
  end

  defp decode(<<@extended::size(3), 0::size(5), @extended_boolean, part_rest::binary>>, _, _) do
    {false, part_rest}
  end

  defp decode(<<@extended::size(3), 1::size(5), @extended_boolean, part_rest::binary>>, _, _) do
    {true, part_rest}
  end

  defp decode(<<@extended::size(3), _::size(5), @extended_cache_container, part_rest::binary>>, _, _) do
    {:cache_container, part_rest}
  end

  defp decode(<<@extended::size(3), 0::size(5), @extended_end_marker, part_rest::binary>>, _, _) do
    {:end_marker, part_rest}
  end

  defp decode(<<@extended::size(3), 4::size(5), @extended_float, value::size(32)-float, part_rest::binary>>, _, options) do
    {maybe_round_float(value, options[:float_precision]), part_rest}
  end

  defp decode(<<@extended::size(3), 4::size(5), @extended_float, value::size(32), part_rest::binary>>, _, options) do
    {maybe_round_float(:erlang.float(value), options[:float_precision]), part_rest}
  end

  defp decode(<<@extended::size(3), len::size(5), @extended_signed_32, part_rest::binary>>, _, _) do
    decode_signed(part_rest, len * 8)
  end

  defp decode(<<@extended::size(3), len::size(5), @extended_unsigned_64, part_rest::binary>>, _, _) do
    decode_unsigned(part_rest, len * 8)
  end

  defp decode(<<@extended::size(3), len::size(5), @extended_unsigned_128, part_rest::binary>>, _, _) do
    decode_unsigned(part_rest, len * 8)
  end

  defp decode(<<@map::size(3), 29::size(5), len::size(8), part_rest::binary>>, data_full, options) do
    decode_map(part_rest, data_full, 28 + len, [], options)
  end

  defp decode(<<@map::size(3), 30::size(5), len::size(16), part_rest::binary>>, data_full, options) do
    decode_map(part_rest, data_full, 285 + len, [], options)
  end

  defp decode(<<@map::size(3), 31::size(5), len::size(24), part_rest::binary>>, data_full, options) do
    decode_map(part_rest, data_full, 65_821 + len, [], options)
  end

  defp decode(<<@map::size(3), len::size(5), part_rest::binary>>, data_full, options) do
    decode_map(part_rest, data_full, len, [], options)
  end

  defp decode(<<@pointer::size(3), 0::size(2), offset::size(11), part_rest::bitstring>>, data_full, options) do
    {value(data_full, offset, options), part_rest}
  end

  defp decode(<<@pointer::size(3), 1::size(2), offset::size(19), part_rest::bitstring>>, data_full, options) do
    {value(data_full, 2048 + offset, options), part_rest}
  end

  defp decode(<<@pointer::size(3), 2::size(2), offset::size(27), part_rest::bitstring>>, data_full, options) do
    {value(data_full, 526_336 + offset, options), part_rest}
  end

  defp decode(<<@pointer::size(3), 3::size(2), offset::size(32), part_rest::bitstring>>, data_full, options) do
    {value(data_full, offset, options), part_rest}
  end

  defp decode(<<@unsigned_16::size(3), len::size(5), part_rest::binary>>, _, _) do
    decode_unsigned(part_rest, len * 8)
  end

  defp decode(<<@unsigned_32::size(3), len::size(5), part_rest::binary>>, _, _) do
    decode_unsigned(part_rest, len * 8)
  end

  defp decode_array(data_part, _, 0, acc, _) do
    {Enum.reverse(acc), data_part}
  end

  defp decode_array(data_part, data_full, size, acc, options) do
    {value, rest} = decode(data_part, data_full, options)
    decode_array(rest, data_full, size - 1, [value | acc], options)
  end

  defp decode_binary(data_part, len) do
    <<value::size(len)-binary, rest::binary>> = data_part
    {value, rest}
  end

  defp decode_map(data_part, _, 0, acc, _) do
    {Map.new(acc), data_part}
  end

  defp decode_map(data_part, data_full, size, acc, options) do
    {key, part_rest} = decode(data_part, data_full, options)
    {value, dec_rest} = decode(part_rest, data_full, options)
    key =
      case options[:map_keys] do
        :atoms -> String.to_atom(key)
        :atoms! -> String.to_existing_atom(key)
        :strings -> key
      end
    decode_map(dec_rest, data_full, size - 1, [{key, value} | acc], options)
  end

  defp decode_signed(bin, len) do
    <<value::integer-signed-size(len), rest::binary>> = bin
    {value, rest}
  end

  defp decode_unsigned(bin, len) do
    <<value::integer-unsigned-size(len), rest::binary>> = bin
    {value, rest}
  end

  defp maybe_round_float(value, nil), do: value
  defp maybe_round_float(value, precision), do: Float.round(value, precision)


  def encode(value) when is_binary(value), do: encode(:binary, value)
  def encode(value) when is_boolean(value), do: encode(:boolean, value)
  def encode(:cache_container), do: encode(:cache_container, :cache_container)
  def encode(:end_marker), do: encode(:end_marker, :end_marker)

  @doc """
  Encodes a value to the appropriate MMDB2 representation.
  """
  @type datatype :: :binary | :boolean | :bytes | :cache_container | :end_marker

  def encode(:binary, ""), do: <<@binary::size(3), 0::size(5)>>

  def encode(:binary, binary) when is_binary(binary) and byte_size(binary) >= 65_821,
    do: <<@binary::size(3), 31::size(5), byte_size(binary) - 65_821::size(24), binary::binary>>

  def encode(:binary, binary) when is_binary(binary) and byte_size(binary) >= 285,
    do: <<@binary::size(3), 30::size(5), byte_size(binary) - 285::size(16), binary::binary>>

  def encode(:binary, binary) when is_binary(binary) and byte_size(binary) >= 29,
    do: <<@binary::size(3), 29::size(5), byte_size(binary) - 29::size(8), binary::binary>>

  def encode(:binary, binary) when is_binary(binary),
    do: <<@binary::size(3), byte_size(binary)::size(5), binary::binary>>

  def encode(:boolean, true), do: <<@extended::size(3), 1::size(5), @extended_boolean>>
  def encode(:boolean, false), do: <<@extended::size(3), 0::size(5), @extended_boolean>>

  def encode(:bytes, ""), do: <<@bytes::size(3), 0::size(5)>>

  def encode(:bytes, bytes) when is_binary(bytes) and byte_size(bytes) >= 65_821,
    do: <<@bytes::size(3), 31::size(5), byte_size(bytes) - 65_821::size(24), bytes::binary>>

  def encode(:bytes, bytes) when is_binary(bytes) and byte_size(bytes) >= 285,
    do: <<@bytes::size(3), 30::size(5), byte_size(bytes) - 285::size(16), bytes::binary>>

  def encode(:bytes, bytes) when is_binary(bytes) and byte_size(bytes) >= 29,
    do: <<@bytes::size(3), 29::size(5), byte_size(bytes) - 29::size(8), bytes::binary>>

  def encode(:bytes, bytes) when is_binary(bytes),
    do: <<@bytes::size(3), byte_size(bytes)::size(5), bytes::binary>>

  def encode(:cache_container, :cache_container),
    do: <<@extended::size(3), 0::size(5), @extended_cache_container>>

  def encode(:end_marker, :end_marker),
    do: <<@extended::size(3), 0::size(5), @extended_end_marker>>
end