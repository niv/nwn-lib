require 'rubygems'

Thread.abort_on_exception = true

unless Object.const_defined?('NWN')
  $:.unshift(File.join(File.dirname(__FILE__), "../lib/"))
  require 'nwn/all'
  include NWN
end
