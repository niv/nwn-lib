# A class that parses binary GFF bytes into ruby-friendly data structures.
class NWN::Gff::Reader
  include NWN::Gff

  attr_reader :root_struct

  # This is a hash containing the following options:
  # [+float_rounding+]
  #  Round floating numbers to this many righthand positions.
  #  Defaults to nil (for no rounding). This can be set to prevent
  #  minor toolset fiddlings from showing up in diffs.
  #  Note that this is somewhat experimental and may introduce
  #  accumulating rounding errors over periods of time.
  #  Suggested values:
  #   *.git: 4
  # [+float_is_unsigned]
  #  Converts all floating point values to unsigned.
  #  This is an experimentatl feature, and as such may induce
  #  unexpected data mangling/precision loss. Use at own risk.
  #  Defaults to false.
  #  Suggested values:
  #   true for all files that only contain orientation values. (like *.git)
  #   Note that this may pose problems with lvars.
  attr_accessor :options

  # Create a new Reader with the given +bytes+ and immediately parse it.
  # This is not needed usually; use Reader.read instead.
  def initialize bytes, options = {}
    @bytes = bytes
    @options = {
      :float_rounding => nil,
      :float_is_unsigned => false,
    }.merge(options)

    read_all
  end

  # Reads +bytes+ as gff data and returns a NWN::Gff:Gff object.
  def self.read bytes, options = {}
    self.new(bytes, options).root_struct
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
    @root_struct = read_struct 0, type.strip, version
  end

  # This iterates through a struct and reads all fields into a hash, which it returns.
  def read_struct index, file_type = nil, file_version = nil
    struct = {}
    struct.extend(NWN::Gff::Struct)

    type = @structs[index * 3]
    data_or_offset = @structs[index * 3 + 1]
    count = @structs[index * 3 + 2]

    raise GffError, "struct index #{index} outside of struct_array" if
      index * 3 + 3 > @structs.size + 1

    struct.struct_id = type
    struct.data_type = file_type
    struct.data_version = file_version

    if count == 1
      lbl, vl = * read_field(data_or_offset, struct)
      struct[lbl] = vl
    else
      if count > 0
        raise GffError, "struct index not divisable by 4" if
          data_or_offset % 4 != 0
        data_or_offset /= 4
        for i in data_or_offset...(data_or_offset+count)
          lbl, vl = * read_field(@field_indices[i], struct)
          struct[lbl] = vl
        end
      end
    end

    struct
  end

  # Reads the field at +index+ and returns [label_name, Gff::Field]
  def read_field index, parent_of
    gff = {}

    field = {}
    field.extend(NWN::Gff::Field)

    index *= 3
    type = @fields[index]
    label_index = @fields[index + 1]
    data_or_offset = @fields[index + 2]

    raise GffError, "Label index #{label_index} outside of label array" if
      label_index > @labels.size

    label = @labels[label_index]

    raise GffError, "Unknown field type #{type}." unless Types[type]
    type = Types[type]

    raise GffError, "Field '#{label}' (type: #{type} )data offset #{data_or_offset} outside of field data block (#{@field_data.size})" if
      ComplexTypes.index(type) && data_or_offset > @field_data.size

    field['type'] = type
    field['label'] = label
    field.parent = parent_of

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
        vsx = [data_or_offset].pack("V").unpack("f")[0]
        vsx = @options[:float_rounding] ? ("%.#{@options[:float_rounding]}f" % vsx).to_f : vsx
        @options[:float_is_unsigned] ? vsx.abs : vsx

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
        exostr = {}
        exostr.extend(NWN::Gff::CExoLocString)
        total_size, str_ref, str_count =
          @field_data[data_or_offset, 12].unpack("VVV")
        all = @field_data[data_or_offset + 12, total_size]
        field.str_ref = str_ref

        str_count.times {
          id, len = all.unpack("VV")
          str = all[8, len].unpack("a*")[0]
          all = all[(8 + len)..-1]
          exostr[id] = str
        }
        len = total_size + 4
        exostr

      when :void
        len = @field_data[data_or_offset, 4].unpack("V")[0]
        @field_data[data_or_offset + 4, len].unpack("H*")[0]

      when :struct
        read_struct data_or_offset

      when :list
        list = []
        list.extend(NWN::Gff::List)

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
          list << read_struct(@list_indices[i], field.path, field.parent.data_version)
        end

        list

    end

    raise GffError, "Field data overflows from the field data block area\
      offset = #{data_or_offset + len}, len = #{@field_data.size}" if
      len && data_or_offset + len > @field_data.size

    [value].compact.flatten.each {|iv|
      iv.element = field if iv.respond_to?('element=')
    }
    field['value'] = value

    [label, field]
  end
end
