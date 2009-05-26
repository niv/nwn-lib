require 'rubygems'
require 'tempfile'
require 'open3'

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

describe "bin helper", :shared => true do
  before do
    @tmp = Dir.tmpdir
  end

  def run_bin *va
    binary = File.join(File.expand_path(File.dirname(__FILE__)), "..", "bin", subject.to_s)
    incl = File.join(File.expand_path(File.dirname(__FILE__)), "..", "lib")
    old = Dir.pwd
    begin
    Dir.chdir(@tmp)
    Open3.popen3(
      "ruby", "-I#{incl}",
      binary,
      *va
    ) do |i,o,e|
      yield i, o, e
    end
    ensure
    Dir.chdir(old)
    end
  end

  def run *va
    run_bin *va do |i, o, e|
      e = e.read
      e.should == ""
    end
  end

  def run_fail *va
    run_bin *va do |i, o, e|
      e.read.size.should > 0
    end
  end
end
