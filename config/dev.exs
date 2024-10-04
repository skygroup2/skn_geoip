import Config

config :skn_geoip, :logger, [
  {:handler, :geoip_log, :logger_std_h, %{
    config: %{
      file: to_charlist("#{System.get_env("LOG_DIR", "./log")}/#{node()}.log"),
      max_no_files: 10,
      max_no_bytes: 50 * 1024 * 1024,
    },
    filter_default: :log,
    filters: [
      {:sasl_domain, {&:logger_filters.domain/2, {:stop, :equal, [:otp, :sasl]}}}
    ],
    formatter: {:logger_formatter, %{time_offset: ~c"Z", template: [:time, " ", :level, " ", :mfa, "_", :line, " ", :pid, " ", :msg, "\n"]}},
    level: :debug
  }},
  {:handler, :geoip_log_sasl, :logger_std_h, %{
    config: %{
      file: to_charlist("#{System.get_env("LOG_DIR", "./log")}/#{node()}_sasl.log"),
      max_no_files: 10,
      max_no_bytes: 20 * 1024 * 1024,
    },
    filter_default: :stop,
    filters: [
      {:remote_gl, {&:logger_filters.remote_gl/2, :stop}},
      {:sasl_domain, {&:logger_filters.domain/2, {:log, :equal, [:otp, :sasl]}}}
    ],
    formatter: {:logger_formatter, %{time_offset: ~c"Z", legacy_header: true, single_line: false}},
  }}
]

config :logger,
  backends: [:console, {LoggerFileBackend, :debug_log}],
  level: :debug

config :ssl, protocol_version: [:"tlsv1.2", :"tlsv1.3"]