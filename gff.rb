class GffError < Exception; end
module Gff; end

module NWN
  module Gff
    class GffError < Exception; end

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

    ComplexTypes = [6, 7, 9, 10, 11, 12, 13, 14, 15].freeze
    SimpleTypes = (Types.keys - ComplexTypes)
    SimpleTypes.freeze

    Formats = {
      :byte => "Cxxx",
      :char => "Cxxx",
      :word => 'Sxx',
      :short => 'sxx',
      :dword => 'I',
      :int => 'i',
      #:dword64 => 'Q',
      #:int64 => '*q',
      :float => 'f',
      #:double => 'd',
      #:cexostr => '*a*',
      #:resref => '*a*',
      #:void => '*HV/a*',
    }.freeze
  end
end

class NWN::Gff::Gff
  include NWN::Gff

  attr_accessor :type
  attr_accessor :version

  def initialize hash, type, version = "V3.2"
    @hash = hash
    @type = type
    @version = version
  end

  def root_struct
    @hash
  end

  def [] k
    h = @hash
    k.split('/').each {|v|
      vv = h[v]
      h = vv
      return vv
    }
  end

  def []= k, v
    # super
  end

end

class NWN::Gff::Element
  attr_accessor :label, :type, :value
  attr_accessor :_str_ref

  def initialize
    # @label, @type, @value = label, type, value
  end
end

class NWN::Gff::Struct < Hash
  attr_accessor :struct_id
  def initialize *a
    @struct_id = 0
    super
  end
end

class NWN::Gff::CExoLocString < Struct.new(:language, :text)
end

class NWN::Gff::Reader
  include NWN::Gff

  attr_reader :hash
  attr_reader :gff

  def initialize bytes
    @bytes = bytes
    read_all
  end

  # Reads +bytes+ as gff data and returns a Gff:Gff object
  def self.read bytes
    self.new(bytes).gff
  end

  private

  def read_all
    type, version,
    struct_offset, struct_count,
    field_offset, field_count,
    label_offset, label_count,
    field_data_offset, field_data_count,
    field_indices_offset, field_indices_count,
    list_indices_offset, list_indices_count =
      @bytes.unpack("a4a4 VV VV VV VV VV VV")

    raise GffError, "Unknown version #{@version}; not a gff?" unless
      version == "V3.2"

    raise GffError, "struct offset at wrong place, not a gff?" unless
      struct_offset == 56

    struct_len = struct_count * 12
    field_len  = field_count * 16
    label_len  = label_count * 16

    @structs = @bytes[struct_offset, struct_len].unpack("V*")
    @fields  = @bytes[field_offset, field_len].unpack("V*")
    @labels  = @bytes[label_offset, label_len].unpack("A16" * label_count)
    @field_data = @bytes[field_data_offset, field_data_count]
    @field_indices = @bytes[field_indices_offset, field_indices_count].unpack("V*")
    @list_indices = @bytes[list_indices_offset, list_indices_count].unpack("V*")
    # puts "FieldDataOffset = #{field_data_offset}, Count = #{field_data_count}"
    @hash = read_struct 0
    @gff = Gff.new(@hash, type, version)
  end

  # This iterates through a struct and reads all fields into a hash, which it returns.
  def read_struct index
    struct = Gff::Struct.new

    type = @structs[index * 3]
    data_or_offset = @structs[index * 3 + 1]
    count = @structs[index * 3 + 2]

    raise GffError, "struct index #{index} outside of struct_array" if
      index * 3 + 3 > @structs.size + 1

    if count == 1
      lbl, vl = * read_field(data_or_offset)
      struct[lbl] = vl
    else
      return 1 if count == 0
      raise GffError, "struct index not divisable by 4" if
        data_or_offset % 4 != 0
      data_or_offset /= 4
      for i in data_or_offset...(data_or_offset+count)
        lbl, vl = * read_field(@field_indices[i])
        struct[lbl] = vl
      end
    end

    struct.struct_id = type
    struct
  end

  # Reads the field at +index+ and returns [label_name, Gff::Element]
  def read_field index
    gff = {}

    field = Element.new

    index *= 3
    type = @fields[index]
    label_index = @fields[index + 1]
    data_or_offset = @fields[index + 2]
    # puts "Reading field #{index}"
    # puts "Label_index = #{label_index}, label = #{@labels[label_index]}"
    # puts "type = #{type}, data_or_offset = #{data_or_offset}"
    raise GffError, "Label index #{label_index} outside of label array" if
      label_index > @labels.size

    raise GffError, "Field data offset #{data_or_offset} outside of field data block (#{@field_data.size})" if
      ComplexTypes.index(type) && data_or_offset > @field_data.size

    raise GffError, "Unknown field type #{type}." unless Types[type]
    type = Types[type]

    label = @labels[label_index]

    value = case type
      when :byte, :char
        data_or_offset & 0xff

      when :word
        data_or_offset & 0xffff

      when :short
        [(data_or_offset & 0xffff)].pack("S").unpack("s")[0]

      when :dword
        data_or_offset

      when :int
        [data_or_offset].pack("I").unpack("i")[0]

      when :float
        [data_or_offset].pack("V").unpack("f")[0]

      when :dword64
        len = 8
        v1, v2 = @field_data[data_or_offset, len].unpack("II")
        v1 * (2**32) + v2

      when :int64
        len = 8
        @field_data[data_or_offset, len].unpack("q")[0]

      when :double
        len = 8
        @field_data[data_or_offset, len].unpack("d")[0]

      when :cexostr
        len = @field_data[data_or_offset, 4].unpack("V")[0]
        @field_data[data_or_offset + 4, len]

      when :resref
        len = @field_data[data_or_offset, 1].unpack("C")[0]
        @field_data[data_or_offset + 1, len]

      when :cexolocstr
        total_size, str_ref, str_count =
          @field_data[data_or_offset, 12].unpack("VVV")
        all = @field_data[data_or_offset + 12, total_size]
        field._str_ref = str_ref

        r = []
        str_count.times {
          id, len = all.unpack("VV")
          str = all[8, len].unpack("a*")[0]
          all = all[(8 + len)..-1]
          r << Gff::CExoLocString.new(id, str)
        }
        len = total_size + 4
        r

      when :void
        len = @field_data[data_or_offset, 4].unpack("V")
        void = @field_data[data_or_offset + 4, len].unpack("H*")
        raise "void: #{void.inspect}"

      when :struct
        read_struct data_or_offset

      when :list
        list = []

        raise GffError, "List index not divisable by 4" unless
          data_or_offset % 4 == 0

        data_or_offset /= 4

        raise GffError, "List index outside list indices" if
          data_or_offset > @list_indices.size

        count = @list_indices[data_or_offset]

        raise GffError, "List index overflow the list indices array" if
          data_or_offset + count > @list_indices.size

        data_or_offset += 1

        for i in data_or_offset...(data_or_offset + count)
          list << read_struct(@list_indices[i])
        end

        list

    end

    raise GffError, "Field data overflows from the field data block area\
      offset = #{data_or_offset + len}, len = #{@field_data.size}" if
      len && data_or_offset + len > @field_data.size

    field.label = label
    field.type = type
    field.value = value

    [label, field]  #::Gff::Element.new(type,label,value)
  end
end
