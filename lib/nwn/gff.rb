require 'pp'

module NWN
  module Gff
    # This error gets thrown if reading or writing fails.
    class GffError < RuntimeError; end

    # This error gets thrown if a supplied value does not
    # fit into the given data type, or you are trying to assign
    # a type to something that does not hold type.
    #
    # Example: You're trying to pass a value greater than 2**32
    # into a int.
    class GffTypeError < RuntimeError; end

    # Gets raised if you are trying to access a path that does
    # not exist.
    class GffPathInvalidError < RuntimeError; end

    # This hash lists all possible NWN::Gff::Field types.
    Types = {
      0 => :byte,
      1 => :char,
      2 => :word,
      3 => :short,
      4 => :dword,
      5 => :int,
      6 => :dword64,
      7 => :int64,
      8 => :float,
      9 => :double,
      10 => :cexostr,
      11 => :resref,
      12 => :cexolocstr,
      13 => :void,
      14 => :struct,
      15 => :list,
    }.freeze

#:stopdoc:
# Used internally to figure out if a field is stored directly
# or by reference.
    ComplexTypes = [6, 7, 9, 10, 11, 12, 13, 14, 15].freeze
    SimpleTypes = (Types.keys - ComplexTypes)
    SimpleTypes.freeze
#:startdoc:

    Formats = {
      :byte => "Cxxx",
      :char => "Cxxx",
      :word => 'Sxx',
      :short => 'sxx',
      :dword => 'I',
      :int => 'i',
      :dword64 => 'II',
      :int64 => 'q',
      :float => 'f',
      :double => 'd',
    }.freeze

    # Registers a new format handler that can deal with file formats for nwn-lib gff handling.
    def self.register_format_handler name, fileFormatRegexp, klass, reads = true, writes = true
      InputFormats[name.to_sym] = klass if reads
      OutputFormats[name.to_sym] = klass if writes
      FileFormatGuesses[fileFormatRegexp] = name.to_sym
    end

    class Handler
      def self.load io
        NWN::Gff::Reader.read(io)
      end
      def self.dump data, io
        NWN::Gff::Writer.dump(data, io)
      end
    end

    class Pretty
      def self.dump data, io
        old = $> ; $> = io ; pp data.box ; $> = old
      end
    end

    InputFormats = {}
    OutputFormats = {}
    FileFormatGuesses = {}

    register_format_handler :gff, /^(ut[cdeimpstw]|git|are|gic|mod|ifo|fac|ssf|dlg|itp|bic)$/, NWN::Gff::Handler
    register_format_handler :marshal, /^marshal$/, Marshal
    register_format_handler :pretty, /^$/, Pretty, false, true

    def self.guess_file_format(filename)
      extension = File.extname(filename.downcase)[1..-1]
      FileFormatGuesses[FileFormatGuesses.keys.select {|key| extension =~ key}[0]]
    end

    def self.read(io, format)
      if InputFormats[format]
        InputFormats[format].load(io)
      else
        raise NotImplementedError, "Don't know how to read #{format}."
      end
    end

    def self.write(io, format, data)
      if OutputFormats[format]
        OutputFormats[format].dump(data, io)
      else
        raise NotImplementedError, "Don't know how to write #{format}."
      end
    end
  end
end

require 'nwn/gff/struct'
require 'nwn/gff/cexolocstr'
require 'nwn/gff/field'
require 'nwn/gff/list'
require 'nwn/gff/reader'
require 'nwn/gff/writer'
