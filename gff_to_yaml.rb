#!/usr/bin/ruby
file = ARGV.shift
bytes = IO.read(file)
require 'gff'
require 'yaml'

g = NWN::Gff::Reader.read(bytes)
y g
