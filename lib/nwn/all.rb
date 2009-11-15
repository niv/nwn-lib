require 'stringio'
require 'nwn/io'
require 'nwn/twoda'
require 'nwn/settings'
require 'nwn/res'
require 'nwn/gff'
require 'nwn/tlk'
require 'nwn/key'
require 'nwn/erf'
require 'nwn/yaml_support'
begin
  require 'json'
  require 'nwn/json_support'
rescue LoadError => e
  NWN.log_debug "json support not available, install json or json_pure to enable"
end
require 'nwn/kivinen_support'
require 'nwn/scripting'
