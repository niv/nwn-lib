require 'psych'

module NWN::Gff::Handler::YAML
  # These field types can never be inlined in YAML.
  NonInlineableFields = [:struct, :list, :cexolocstr]

  # See http://www.taguri.org/ for the exact meaning of this.
  Domain = "nwn-lib.elv.es,2013-07"

  def self.load io
    Psych.load(io)
  end

  def self.dump data, io
    str = Psych.dump(data)
    io.write(str)
    str.size
  end
end

NWN::Gff::Handler.register :yaml, /^(y|yml|yaml)$/, NWN::Gff::Handler::YAML

module NWN::Gff::Struct
  def encode_with out
    out.map("!#{NWN::Gff::Handler::YAML::Domain}:struct") do |map|
      # Inline certain structs that are small enough.
      map.style = Psych::Nodes::Mapping::FLOW if self.size <= 1 &&
        self.values.select {|x|
          NWN::Gff::Handler::YAML::NonInlineableFields.index(x['type'])
        }.size == 0

      map.add('__' + 'data_type', @data_type) if @data_type
      map.add('__' + 'data_version', @data_version) if
        @data_version && @data_version != DEFAULT_DATA_VERSION
      map.add('__' + 'struct_id', @struct_id) if @struct_id != nil

      sort.each {|k, v|
        map.add(k, v)
      }
    end
  end
end

module NWN::Gff::Field
  def encode_with out
    out.map do |map|
      map.tag = nil
      map.style = Psych::Nodes::Mapping::FLOW unless
        NWN::Gff::Handler::YAML::NonInlineableFields.index(self['type'])
      map.add('type', self['type'].to_s)
      map.add('str_ref', self['str_ref']) if has_str_ref?
      map.add('value', self['value'])
    end
  end
end

# This parses the struct and extends all fields with their proper type.
Psych.add_domain_type(NWN::Gff::Handler::YAML::Domain,'struct') {|t,hash|
  struct = {}
  struct.extend(NWN::Gff::Struct)

  # The metadata
  struct.struct_id = hash.delete('__struct_id')
  struct.data_type = hash.delete('__data_type')
  struct.data_version = hash.delete('__data_version')
  struct.data_version ||= NWN::Gff::Struct::DEFAULT_DATA_VERSION

  raise NWN::Gff::GffError, "no struct_id set for struct at #{struct.path}." if
    struct.struct_id.nil?

  hash.each {|label,element|
    label.freeze

    element.extend(NWN::Gff::Field)
    element.field_label = label
    element.parent = struct
    element.str_ref ||= NWN::Gff::Field::DEFAULT_STR_REF if
      element.respond_to?('str_ref=')

    element.extend_meta_classes

    element.field_value.element = element if
      element.field_value.is_a?(NWN::Gff::Struct)

    element.validate

    struct[label] = element
  }

  struct
}

