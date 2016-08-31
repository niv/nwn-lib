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

    # A namesoace for all Gff file format handlers.
    module Handler
      # Registers a new format handler that can deal with file formats for nwn-lib gff handling.
      #
      # [+name+]   The name of this format as a symbol. Must be unique.
      # [+fileFormatRegexp+] A regular expression matching file extensions for auto-detection.
      # [+klass+]  A object that responds to load(io) and dump(gff,io). load(io) reads from io
      #            and always returns a NWN::Gff::Struct describing a root struct, dump(gff, io)
      #            dumps the gff root struct in the handlers format to io and returns the number
      #            of bytes written.
      # [+reads+]  Boolean, indicates if this handler can read it's format and return gff data.
      # [+writes+] Boolean, indicates if this handler can emit gff data in it's format.
      def self.register name, fileFormatRegexp, klass, reads = true, writes = true
        raise ArgumentError, "Handler for #{name.inspect} already registered." if
          NWN::Gff::InputFormats[name.to_sym] || NWN::Gff::OutputFormats[name.to_sym]
        NWN::Gff::InputFormats[name.to_sym] = klass if reads
        NWN::Gff::OutputFormats[name.to_sym] = klass if writes
        NWN::Gff::FileFormatGuesses[name.to_sym] = fileFormatRegexp
      end

      module Gff
        def self.load io
          NWN::Gff::Reader.read(io)
        end
        def self.dump data, io
          NWN::Gff::Writer.dump(data, io)
        end
      end

      module Pretty
        def self.dump data, io
          old = $> ; $> = StringIO.new
          pp data
          sz = $>.pos
          $>.seek(0)
          io.write $>.read
          $> = old
          sz
        end
      end

      module Marshal
        def self.dump data, io
          d = ::Marshal.dump(data)
          io.write(d)
          d.size
        end

        def self.load io
          ::Marshal.load(io)
        end
      end
    end

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

    InputFormats = {}
    OutputFormats = {}
    FileFormatGuesses = {}

    Handler.register :gff, /^(ut[cdeimpstw]|git|are|gic|mod|ifo|fac|ssf|dlg|itp|bic|jrl)$/, NWN::Gff::Handler::Gff
    Handler.register :marshal, /^marshal$/, NWN::Gff::Handler::Marshal
    Handler.register :pretty, /^$/, NWN::Gff::Handler::Pretty, false, true

    def self.guess_file_format(filename)
      extension = File.extname(filename.downcase)[1..-1]
      matches = FileFormatGuesses.select {|fmt,rx| extension =~ rx }
      if matches.size == 1
        matches.keys[0]
      else
        nil
      end
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

require_relative 'gff/struct'
require_relative 'gff/cexolocstr'
require_relative 'gff/field'
require_relative 'gff/list'
require_relative 'gff/reader'
require_relative 'gff/writer'
