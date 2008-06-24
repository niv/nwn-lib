bytes = IO.read(ARGV.shift)
require 'gff'
require 'pp'

g = Gff::Reader.new(bytes)

pp g.hash
