defmodule GeoIP.Config do
  @moduledoc """
    provide some api for working with geo
  """
  def get_db_dir do
    Skn.Config.get(:mmdb_dir, "./.mmdb2")
  end

  def set_db_dir(path) do
    Skn.Config.set(:mmdb_dir, path)
  end

  def get_version do
    Skn.Config.get(:mmdb_version, ~D[2020-01-01])
  end

  def set_version(version) do
    Skn.Config.set(:mmdb_version, version)
  end

  def get_license() do
    mmdb_lic_ptr = Skn.Counter.update_counter(:mmdb_lic_ptr, 1)
    mmdb_lic = Skn.Config.get(:mmdb_lic, ["xlwBl5KsfAS8fTCu", "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"])
    if length(mmdb_lic) > 0 do
      Enum.at(mmdb_lic, rem(mmdb_lic_ptr, length(mmdb_lic)))
    else
      nil
    end
  end

  def set_license(lic) do
    Skn.Config.set(:mmdb_lic, lic)
  end

  def check_set_license() do
    lic = System.get_env("MAXMIND_LICENSE")
    if lic != nil do
      set_license(lic)
    end
  end
end
