defmodule GeoIP.Repo do
  require Record

  @geo_mmdb2_fields [id: nil, type: nil, value: nil]
  Record.defrecord :geo_mmdb2, @geo_mmdb2_fields

  def fields(x) do
    Keyword.keys x
  end

  def create_table() do
    :mnesia.create_table(:geo_mmdb2, [disc_copies: [node()], record_name: :geo_mmdb2, attributes: fields(@geo_mmdb2_fields)])
  end
end

defmodule GeoIP.DB.MMDB2 do
  require GeoIP.Repo
  require Record
  def get(id) do
    case :mnesia.dirty_read(:geo_mmdb2, id) do
      [r | _] ->
        %{
          id: GeoIP.Repo.geo_mmdb2(r, :id),
          type: GeoIP.Repo.geo_mmdb2(r, :type),
          value: GeoIP.Repo.geo_mmdb2(r, :value)
        }
      _ ->
        nil
    end
  end

  def list(_type) do

  end

  def set(id, type, value) do
    obj = GeoIP.Repo.geo_mmdb2(id: id, type: type, value: value)
    :mnesia.dirty_write(:geo_mmdb2, obj)
  end

  def delete(id) do
    :mnesia.dirty_delete(:geo_mmdb2, id)
  end
end