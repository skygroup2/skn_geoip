import Config

config :lager,
  log_root: :os.getenv('LAGER_LOG_DIR', '#{File.cwd!()}/log'),
  crash_log: '#{node()}_crash.log',
  handlers: [
    {:lager_file_backend,
     [{:file, '#{node()}.log'}, {:level, :debug}, {:size, 104_857_600}, {:date, '$D0'}]}
  ]

config :logger,
  backends: [:console, LoggerLagerBackend],
  handle_otp_reports: true,
  handle_sasl_reports: true,
  level: :debug

config :ssl, protocol_version: :"tlsv1.2"
