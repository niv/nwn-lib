require 'rubygems'

Thread.abort_on_exception = true

unless Object.const_defined?('NWN')
  $:.unshift(File.join(File.dirname(__FILE__), "../lib/"))
  require 'nwn/all'
  include NWN
end

GffFieldValidations = {
  :void => [[""], []],
  :byte => [[0, 255], [256, -1]],
  :char => [[0, 255], [256, -1]],
  :resref => [["", "a" * 16], ["a" * 17]],
  :double => [[0.0], ["x"]],
  :dword => [[0, 0xffffffff], [-1, 0xffffffff + 1]],
  :dword64 => [[0, 0xffffffffffff], [-1, 0xffffffffffff + 1]],
  :float => [[0.0], ["x"]],
  :int => [[-0x80000000, 0x7fffffff], [0x80000001, 0x7fffffff + 1]],
  :int64 => [[-0x800000000000, 0x7fffffffffff], [0x800000000001, 0x7fffffffffff + 1]],
  :short => [[-0x8000, 0x7fff], [-0x8001, 0x7fff + 1]],
  :word => [[0, 0xffff], [-1, 0xffff + 1]],
}.freeze
