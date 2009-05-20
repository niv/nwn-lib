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

WELLFORMED_GFF_PATH = File.join(File.expand_path(File.dirname(__FILE__)), "wellformed_gff.binary").freeze
WELLFORMED_GFF = IO.read(WELLFORMED_GFF_PATH).freeze

WELLFORMED_ERF = ([
  "HAK", "V1.0",
  locstr_count = 1, locstr_size = 14,
  entry_count = 3,
  offset_to_locstr = 160,
  offset_to_keys = offset_to_locstr + locstr_size,
  offset_to_res  = offset_to_locstr + locstr_size + entry_count * (16 + 4 + 2 + 2),

  100, 126, # year, dayofyear
  0xdeadbeef, "" #description strref, 116 bytes 0-padding
].pack("A4 A4 VV VV VV VV V  a116") + [
  0, 6, "abcdef" # one locstr
].pack("V V a*") + [
  "resref", 0, 10, 0, # keylist: resref.txt, id = 0
  "help",   1,  1, 0, # keylist: help.bmp, id = 1
  "yegods", 2,  4, 0, # keylist: yegods.wav, id = 2
].pack("a16 V v v" * entry_count) + [
  offset_to_res + entry_count * 8, 6,  # offset, size
  offset_to_res + entry_count * 8 + 6, 4,  # offset, size
  offset_to_res + entry_count * 8 + 6 + 4, 6,  # offset, size
].pack("II" * entry_count) + [
  "resref", "help", "yegods"
].pack("a* a* a*")).freeze

WELLFORMED_ERF_11 = ([
  "HAK", "V1.1",
  locstr_count = 1, locstr_size = 14,
  entry_count = 3,
  offset_to_locstr = 160,
  offset_to_keys = offset_to_locstr + locstr_size,
  offset_to_res  = offset_to_locstr + locstr_size + entry_count * (32 + 4 + 2 + 2),

  100, 126, # year, dayofyear
  0xdeadbeef, "" #description strref, 116 bytes 0-padding
].pack("A4 A4 VV VV VV VV V  a116") + [
  0, 6, "abcdef" # one locstr
].pack("V V a*") + [
  "resref", 0, 10, 0, # keylist: resref.txt, id = 0
  "help",   1,  1, 0, # keylist: help.bmp, id = 1
  "yegods", 2,  4, 0, # keylist: yegods.wav, id = 2
].pack("a32 V v v" * entry_count) + [
  offset_to_res + entry_count * 8, 6,  # offset, size
  offset_to_res + entry_count * 8 + 6, 4,  # offset, size
  offset_to_res + entry_count * 8 + 6 + 4, 6,  # offset, size
].pack("II" * entry_count) + [
  "resref", "help", "yegods"
].pack("a* a* a*")).freeze
