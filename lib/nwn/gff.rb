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

    # These field types can never be inlined in YAML.
    YAMLNonInlineableFields = [:struct, :list]
  end

end

require 'nwn/gff/struct'
require 'nwn/gff/field'
require 'nwn/gff/list'
require 'nwn/gff/cexolocstr'
require 'nwn/gff/reader'
require 'nwn/gff/writer'
