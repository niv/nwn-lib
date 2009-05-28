module NWN

  # This writes a internal warnings and debug messages to stderr.
  #
  # Leaving this on is recommended, since it usually points to
  # (fixable) errors in your resource files. You can turn this off
  # anyways by setting the environment variable +NWN_LIB_DEBUG+
  # to "0" or "off".
  #
  # Will return true when printed, false otherwise.
  def self.log_debug msg
    # Do not print debug messages if explicitly turned off
    return false if [false, "off"].index(setting(:debug))

    pa = caller[0].to_s
    pa = pa[(pa.size - 36) .. -1] if pa.size > 36
    $stderr.puts "(nwn-lib) %s: %s" % [pa, msg]
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
