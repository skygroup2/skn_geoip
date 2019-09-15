defmodule GeoIP.Repo do
  require Record

  @geo_mmdb2_fields [id: nil, value: nil]
  Record.defrecord :msm_report, @geo_mmdb2_fields

  def fields(x) do
    Keyword.keys x
  end

  def create_table() do
    :mnesia.create_table(:geo_mmdb2, [disc_copies: [node()], record_name: :geo_mmdb2, attributes: fields(@geo_mmdb2_fields)])
  end
end

defmodule GeoIP.DB.MMDB2 do

end