require 'stringio'
require_relative 'io'
require_relative 'twoda'
require_relative 'settings'
require_relative 'res'
require_relative 'gff'
require_relative 'tlk'
require_relative 'key'
require_relative 'erf'

require_relative 'yaml_support'

begin
  require 'json'
  require_relative 'json_support'
rescue LoadError => e
  # NWN.log_debug "json support not available, install json or json_pure to enable"
end
require_relative 'kivinen_support'
begin
  require 'xml'
  require_relative 'xml_support'
rescue LoadError => e
  # NWN.log_debug "nxml and modpacker support not available, install libxml-ruby to enable"
end

require_relative 'scripting'
