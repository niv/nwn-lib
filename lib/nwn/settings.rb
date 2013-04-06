module NWN
  SETTING_DEFAULT_VALUES = {
    'NWN_LIB_IN_ENCODING' => 'windows-1252'
  }

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

    if NWN.setting(:debug_traces)
      $stderr.puts "(nwn-lib): %s" % [msg]
      $stderr.puts "  " + caller.join("\n  ") + "\n"
    else
      dir = File.expand_path(File.dirname(File.expand_path(__FILE__)) + "/../../")
      pa = caller.reject {|x| x.index(dir) }[0]
      pa ||= caller[0]
      pa ||= "(no frames)"
      pa = pa[(pa.size - 36) .. -1] if pa.size > 36
      $stderr.puts "(nwn-lib) %s: %s" % [pa, msg]
    end

    true
  end

  # Get or set a ENV var setting.
  # Returns false for "0" values.
  # Returns the old value for new assignments.
  def self.setting sym, value = :_invalid_
    name = "NWN_LIB_#{sym.to_s.upcase}"
    if value != :_invalid_
      ret = setting(sym)
      ENV[name] = value.to_s if value != :_invalid_
      ret
    else
      ENV[name] == "0" ? false : (ENV[name] || SETTING_DEFAULT_VALUES[name])
    end
  end

  IconvState = {} #:nodoc:

  # Converts text from native format (such as json) to Gff (required by NWN).
  def self.iconv_native_to_gff text
    text.encode(NWN.setting(:in_encoding))
  end

  # Converts text from Gff format to native/external, such as json (usually UTF-8).
  def self.iconv_gff_to_native text
    text.encode('UTF-8')
  end
end

NWN::TwoDA::Cache.setup NWN.setting("2da_location") if
  NWN.setting("2da_location")
