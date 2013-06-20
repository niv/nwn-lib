# A class that parses binary GFF bytes into ruby-friendly data structures.
class NWN::Gff::Reader
  include NWN::Gff

  attr_reader :root_struct

  private_class_method :new

  # Create a new Reader with the given +io+ and immediately parse it.
  def self.read io
    t = new(io)
    t.root_struct
  end

  def initialize io #:nodoc:
    @io = io
    io.internal_encoding == nil or raise "passed io needs to be binary, is #{io.internal_encoding.inspect}"
    read_all
  end

private

  def read_all
    initial_seek = @io.pos

    type, version,
    struct_offset, struct_count,
    field_offset, field_count,
    label_offset, label_count,
    field_data_offset, field_data_count,
    field_indices_offset, field_indices_count,
    list_indices_offset, list_indices_count =
      @io.e_read(160, "header").unpack("a4a4 VV VV VV VV VV VV")

    raise GffError, "struct offset at wrong place, not a gff?" unless
      struct_offset == 56

    struct_len = struct_count * 12
    field_len  = field_count * 16
    label_len  = label_count * 16

    @io.seek(initial_seek + struct_offset)
    @structs = @io.e_read(struct_len, "structs")
    @structs = @structs.unpack("V*")

    @io.seek(initial_seek + field_offset)
    @fields  = @io.e_read(field_len, "fields")
    @fields  = @fields.unpack("V*")

    @io.seek(initial_seek + label_offset)
    @labels  = @io.e_read(label_len, "labels")
    @labels = @labels.unpack("A16" * label_count)
    @labels.map! {|l| l.force_encoding("ASCII") }

    @io.seek(initial_seek + field_data_offset)
    @field_data = @io.e_read(field_data_count, "field_data")

    @io.seek(initial_seek + field_indices_offset)
    @field_indices = @io.e_read(field_indices_count, "field_indices")
    @field_indices = @field_indices.unpack("V*")

    @io.seek(initial_seek + list_indices_offset)
    @list_indices = @io.e_read(list_indices_count, "list_indices")
    @list_indices = @list_indices.unpack("V*")

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

    file_type = file_type.force_encoding('ASCII') if file_type
    file_version = file_version.force_encoding('ASCII') if file_version

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
        str = @field_data[data_or_offset + 4, len].force_encoding(NWN.setting :in_encoding)
        str.valid_encoding? or raise "Invalid encoding bytes in cexostr: #{str.inspect}"
        str

      when :resref
        len = @field_data[data_or_offset, 1].unpack("C")[0]
        str = @field_data[data_or_offset + 1, len].force_encoding(NWN.setting :in_encoding)
        str.valid_encoding? or raise "Invalid encoding bytes in resref: #{str.inspect}"
        str

      when :cexolocstr
        exostr = {}

        total_size, str_ref, str_count =
          @field_data[data_or_offset, 12].unpack("VVV")
        all = @field_data[data_or_offset + 12, total_size]
        field.extend(NWN::Gff::Cexolocstr)
        field.str_ref = str_ref

        str_count.times {
          id, len = all.unpack("VV")
          str = all[8, len].unpack("a*")[0].force_encoding(NWN.setting :in_encoding)
          str.valid_encoding? or raise "Invalid encoding bytes in cexolocstr: #{str.inspect}"
          all = all[(8 + len)..-1]
          exostr[id] = str
        }
        len = total_size + 4
        exostr

      when :void
        len = @field_data[data_or_offset, 4].unpack("V")[0]
        @field_data[data_or_offset + 4, len].unpack("a*")[0].force_encoding("BINARY")

      when :struct
        read_struct data_or_offset, nil, field.parent.data_version

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
          list << read_struct(@list_indices[i], nil, field.parent.data_version)
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

    # We extend all fields and field_values with matching classes.
    field.extend_meta_classes
    field.validate

    [label, field]
  end
end
