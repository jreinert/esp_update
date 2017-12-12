module EspUpdate
  record(
    Options,
    bindir : String = ".",
    host : String = "localhost",
    port : Int32 = 3000,
  ) { setter :bindir, :host, :port }
end
