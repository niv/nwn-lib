bytes = IO.read(ARGV.shift)
require 'gff'
require 'pp'
require 'yaml'

g = Gff::Reader.new(bytes)

y g.hash
