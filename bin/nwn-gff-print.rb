#!/usr/bin/ruby

require 'optparse'
require 'nwn/gff'
require 'yaml'

format = nil

OptionParser.new do |o|
  o.banner = "Usage: nwn-gff-print [options] file | -"
  o.on "-y", "--yaml", "Dump as yaml" do
    format = :yaml
  end
  o.on "-k", "--kivinen", "Dump as kivinens dump format (like the perl tools)" do
    format = :kivinen
  end
end.parse!

file = ARGV.shift or begin
  $stderr.puts "Required argument: filename to process, or - for stdin (try -h)."
  exit 1
end
if file == "-"
  bytes = $stdin.read
else
  bytes = IO.read(file)
end

g = NWN::Gff::Reader.read(bytes)

def k_format_struct s, prefix = "/", &block
  case s.type
    when :struct
      s.each {|k,v|
        yield(prefix + k, v)
      }
    when :cexolocstr
      s.value.each {|vv|  
        yield(prefix + s.label + "/" + vv.language.to_s, vv.text)
      }
      yield(prefix + s.label + ". ___string_ref", s._str_ref)
    when :list
      s.value.each_with_index {|vv, idx|
        vv.each {|kkk, vvv|
          k_format_struct vvv, prefix + s.label + "[#{idx}]/" do |l,v|
            yield(l,v)
          end
        }
      }
    else
      yield(prefix + s.label, s.value)
  end
end

case format
  when :yaml
    y g
  when :kivinen
    g.root_struct.each {|rk,rv|
      k_format_struct rv do |label, value|
        puts "%s:\t%s" % [label, value]
      end
    }
  else
    puts "Unknown format; try -h"
end
