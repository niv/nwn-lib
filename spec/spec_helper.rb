Bundler.setup(:default, :test)

require 'tempfile'
require 'fileutils'
require 'open3'

Thread.abort_on_exception = true

unless Object.const_defined?('NWN')
  $:.unshift(File.join(File.dirname(__FILE__), "../lib/"))
  require 'nwn/all'
  include NWN
end

$options = {}

NWN.setting(:debug, 0)

GffFieldValidations = {
  :void => [[""], []],
  :byte => [[0, 255], [256, -1]],
  :char => [[0, 255], [256, -1]],
  :resref => [["", "a" * 16], ["a" * 17]],
  :double => [[0.0], ["x"]],
  :dword => [[0, 0xffffffff], [-1, 0xffffffff + 1]],
  :dword64 => [[0, 0xffffffffffffffff], [-1, 0xffffffffffffffff + 1]],
  :float => [[0.0], ["x"]],
  :int => [[-0x80000000, 0x7fffffff], [0x80000001, 0x7fffffff + 1]],
  :int64 => [[-0x8000000000000000, 0x7fffffffffffffff], [-0x8000000000000000 - 1, 0x7fffffffffffffff + 1]],
  :short => [[-0x8000, 0x7fff], [-0x8001, 0x7fff + 1]],
  :word => [[0, 0xffff], [-1, 0xffff + 1]],
}.freeze

WELLFORMED_GFF_PATH = File.join(File.expand_path(File.dirname(__FILE__)), "wellformed_gff.bic").freeze
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

WELLFORMED_TLK = ([
  "TLK", "V3.0",
  language_id = 0,
  string_count = 5,
  offset_to_str = 21,
].pack("a4 a4 I I I") + [ # string data table
  # flags, soundresref, volvariance, pitchvariance, offset_to_str, sz, soundlen
  0x1, "", 0, 0, -1 + 40 * string_count, 1, 0.0,
  0x3, "textsnd", 0, 0, -1 + 40 * string_count + 1, 2, 0.0,
  0x7, "textsndlen", 0, 0, -1 + 40 * string_count + 3, 3, 2.0,
  0x1, "", 0, 0, -1 + 40 * string_count + 6, 4, 0.0,
  0x2, "justsnd", 0, 0, -1 + 40 * string_count + 10, 0, 0.0,
].pack("I A16 I I I I f" * string_count) + [
  "1", "22", "333", "4444"
].join("")).freeze

WELLFORMED_BIF_0 = ([
  "BIFF", "V1",
  var_res_count = 2,
  fix_res_count = 0,
  var_table_offset = 20
].pack("a4 a4 V V V") + [
  id0 = 124, var_table_offset + (16 * var_res_count),         size0 = 10, type0 = 0,
  id1 = 125, var_table_offset + (16 * var_res_count) + size0, size1 = 10, type1 = 0,
].pack("VVVV VVVV") + [
  "abcdefghij", "0123456789"
].pack("a* a*")
).freeze

WELLFORMED_KEY = ([
  "KEY", "V1",
  bif_count = 1, key_count = 2,
  offset_to_file_table = 8 + (4 * 6) + 32,
  offset_to_key_table = offset_to_file_table + bif_count * 12 + 8,
  100, 126, ""
].pack("a4 a4 VVVVVV a32") + [ # file table containing bifs
  bifsize = WELLFORMED_BIF_0.size, bifname0offset = offset_to_file_table + 12, fnsize = 8, drives = 0,
].pack("VVvv") + [ #filename table
  "bif0.bif"
].pack("a*") + [ # key table
  "abcdef", 0, 124,
  "123456", 0, 125
].pack("a16 v V a16 v V")
).freeze


TWODA_WELLFORMED = <<-EOT
2DA V2.0

    Col1  Col2
0   a     b
1   c     d
EOT

TWODA_MISALIGNED = <<-EOT
2DA V2.0

   Col1
0  a
1  b
2  c
3  d
4  e
6  f
2  g
7  h
EOT

TWODA_WHITESPACE = <<-EOT
2DA   V2.0  


       Col1
0   4
EOT

TWODA_MISSING_COLUMN = <<-EOT
2DA V2.0

    Col1   Col2  Col3
0   a1     b1    c1
1   a2     b2
EOT

TWODA_TOO_MANY_CELLS = <<-EOT
2DA V2.0

    Col1
0   a1     b1    c1
1   a2     b2
2   "a2     b2    c1"
EOT


TWODA_EMPTY_AND_QUOTES = <<-EOT
2DA V2.0

    Col1  Col2
0   ****  b
1   c     d
2   ""    f
3   "g g" h
EOT

TWODA_MISSING_ID = <<-EOT
2DA V2.0

   Col1
   a
0  b
1  c
2  d
EOT

module BinHelper
  def tmpfile
    Tempfile.new('nwn-lib', @tmpdir, :encoding => 'BINARY')
  end

  def run_bin *va
    binary = File.join(File.expand_path(File.dirname(__FILE__)), "..", "bin", subject.to_s)
    incl = File.join(File.expand_path(File.dirname(__FILE__)), "..", "lib")
    old = Dir.pwd
    Dir.chdir(@tmpdir) if defined?(@tmpdir)
    begin
      return Open3.capture2e(
        "ruby", "-rubygems", "-I#{incl}",
        binary,
        *va
      )
    ensure
      Dir.chdir(old)
    end
  end

  def run *va
    stdout_str, ret = run_bin *va
    ret.should == 0
  end

  def run_fail *va
    stdout_str, ret = run_bin *va
    ret.should_not == 0
  end
end
