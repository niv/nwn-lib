module NWN

  # This writes a debug message to stderr if the environment
  # variable +NWN_LIB_DEBUG+ is set to non-nil or $DEBUG is
  # true (ruby -d).
  def self.log_debug msg
    return false unless ENV['NWN_LIB_DEBUG'] || $DEBUG
    $stderr.puts "(nwn-lib debug) %s: %s" % [caller[0].to_s, msg]
    true
  end

  # Get or set a ENV var setting.
  # Returns false for "0" values.
  # Returns the old value for new assignments.
  def self.setting sym, value = :_invalid_
    name = "NWN_LIB_#{sym.to_s.upcase}"
    if value != :_invalid_
      ret = ENV[name] == "0" ? false : ENV[name]
      ENV[name] = value.to_s if value != :_invalid_
      ret
    else
      ENV[name] == "0" ? false : ENV[name]
    end
  end
end

NWN::TwoDA::Cache.setup NWN.setting("2da_location") if
  NWN.setting("2da_location")
