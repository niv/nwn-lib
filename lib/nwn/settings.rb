module NWN

  # This writes a debug message to stderr if the environment
  # variable +NWN_LIB_DEBUG+ is set to non-nil or $DEBUG is
  # true (ruby -d).
  def self.log_debug msg
    return false unless ENV['NWN_LIB_DEBUG'] || $DEBUG
    $stderr.puts "(nwn-lib debug) %s: %s" % [caller[0].to_s, msg]
    true
  end
end

if ENV['NWN_LIB_2DA_LOCATION'] && ENV['NWN_LIB_2DA_LOCATION'] != ""
  NWN::TwoDA::Cache.setup ENV['NWN_LIB_2DA_LOCATION']
end
