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
    read_all
  end

  private

  def read_all
    header = @io.read(160)
    raise IOError, "Cannot read header" unless header &&
      header.size == 160

    type, version,
    struct_offset, struct_count,
    field_offset, field_count,
    label_offset, label_count,
    field_data_offset, field_data_count,
    field_indices_offset, field_indices_count,
    list_indices_offset, list_indices_count =
      header.unpack("a4a4 VV VV VV VV VV VV")

    raise GffError, "Unknown version #{version}; not a gff?" unless
      version == "V3.2"

    raise GffError, "struct offset at wrong place, not a gff?" unless
      struct_offset == 56

    struct_len = struct_count * 12
    field_len  = field_count * 16
    label_len  = label_count * 16

    @io.seek(struct_offset)
    @structs = @io.read(struct_len)
    raise IOError, "cannot read structs" unless @structs && @structs.size == struct_len
    @structs = @structs.unpack("V*")

    @io.seek(field_offset)
    @fields  = @io.read(field_len)
    raise IOError, "cannot read fields" unless @fields && @fields.size == field_len
    @fields  = @fields.unpack("V*")

    @io.seek(label_offset)
    @labels  = @io.read(label_len)
    raise IOError, "cannot read labels" unless @labels && @labels.size == label_len
    @labels = @labels.unpack("A16" * label_count)

    @io.seek(field_data_offset)
    @field_data = @io.read(field_data_count)
    raise IOError, "cannot read field_data" unless @field_data && @field_data.size == field_data_count

    @io.seek(field_indices_offset)
    @field_indices = @io.read(field_indices_count)
    raise IOError, "cannot read field_indices" unless @field_indices && @field_indices.size == field_indices_count
    @field_indices = @field_indices.unpack("V*")

    @io.seek(list_indices_offset)
    @list_indices = @io.read(list_indices_count)
    raise IOError, "cannot read list_indices" unless @list_indices && @list_indices.size == list_indices_count
    @list_indices = @list_indices.unpack("V*")

    @root_struct = read_struct 0, type.strip, version
  end

  # This iterates through a struct and reads all fields into a hash, which it returns.
  def read_struct index, file_type = nil, file_version = nil
    struct = {}.taint
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

    field = {}.taint
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
        @field_data[data_or_offset + 4, len]

      when :resref
        len = @field_data[data_or_offset, 1].unpack("C")[0]
        @field_data[data_or_offset + 1, len]

      when :cexolocstr
        exostr = {}

        total_size, str_ref, str_count =
          @field_data[data_or_offset, 12].unpack("VVV")
        all = @field_data[data_or_offset + 12, total_size]
        field.extend(NWN::Gff::Cexolocstr)
        field.str_ref = str_ref

        str_count.times {
          id, len = all.unpack("VV")
          str = all[8, len].unpack("a*")[0]
          all = all[(8 + len)..-1]
          exostr[id] = str
        }
        len = total_size + 4
        # Filter out empty strings.
        exostr.reject! {|k,v| v.nil? || v.empty?}
        exostr.taint

      when :void
        len = @field_data[data_or_offset, 4].unpack("V")[0]
        @field_data[data_or_offset + 4, len].unpack("H*")[0]

      when :struct
        read_struct data_or_offset, field.path, field.parent.data_version

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
          list << read_struct(@list_indices[i], field.path, field.parent.data_version)
        end

        list.taint

    end

    raise GffError, "Field data overflows from the field data block area\
      offset = #{data_or_offset + len}, len = #{@field_data.size}" if
      len && data_or_offset + len > @field_data.size

    [value].compact.flatten.each {|iv|
      iv.element = field if iv.respond_to?('element=')
    }
    field['value'] = value.taint

    # We extend all fields and field_values with matching classes.
    field.extend_meta_classes
    field.validate

    [label, field]
  end
end
