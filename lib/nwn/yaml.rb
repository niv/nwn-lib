# This file contains all YAML-specific loading and dumping code.
require 'yaml'

# See http://www.taguri.org/ for the exact meaning of this.
NWN::YAML_DOMAIN = "nwn-lib.elv.es,2008-12"

#:stopdoc:
class Array
  attr_accessor :to_yaml_style
end
class Hash
  attr_accessor :to_yaml_style
end

class Hash
  # Replacing the to_yaml function so it'll serialize hashes sorted (by their keys)
  # Original function is in /usr/lib/ruby/1.8/yaml/rubytypes.rb
  def to_yaml(opts = {})
    YAML::quick_emit(nil, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        if keys.map {|v| v.class }.size > 0
          each do |k, v|
            map.add(k, v)
          end
        else
          sort.each do |k, v|
            map.add(k, v)
          end
        end
      end
    end
  end
end

module NWN::Gff::Struct
  def to_yaml_type
    "!#{NWN::YAML_DOMAIN}/struct"
  end

  def to_yaml(opts = {})
    YAML::quick_emit(nil, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        # Inline certain structs that are small enough.
        map.style = :inline if self.size <= 1 &&
          self.values.select {|x|
            NWN::Gff::YAMLNonInlineableFields.index(x['type'])
          }.size == 0

        map.add('__' + 'data_type', @data_type) if @data_type
        map.add('__' + 'data_version', @data_version) if @data_version && @data_version != DEFAULT_DATA_VERSION
        map.add('__' + 'struct_id', @struct_id) if @struct_id

        sort.each {|k,v|
          map.add(k,v)
        }
      end
    end
  end
end

module NWN::Gff::Field

  def to_yaml(opts = {})
    YAML::quick_emit(nil, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        map.style = :inline unless NWN::Gff::YAMLNonInlineableFields.index(self['type'])
        map.add('type', self['type'])
        map.add('str_ref', self['str_ref']) if has_str_ref?
        map.add('value', self['value'])
      end
    end
  end
end

# This parses the struct and extends all fields with their proper type.
YAML.add_domain_type(NWN::YAML_DOMAIN,'struct') {|t,hash|
  struct = {}
  struct.extend(NWN::Gff::Struct)

  # The metadata
  struct.struct_id = hash.delete('__struct_id')
  struct.data_type = hash.delete('__data_type')
  struct.data_version = hash.delete('__data_version')
  struct.data_version ||= NWN::Gff::Struct::DEFAULT_DATA_VERSION

  raise NWN::Gff::GffError, "no struct_id set for struct at #{struct.path}." if struct.struct_id.nil?

  hash.each {|label,element|
    label.freeze

    element.extend(NWN::Gff::Field)
    element.field_label = label
    element.parent = struct
    element.str_ref ||= NWN::Gff::Field::DEFAULT_STR_REF if element.respond_to?('str_ref=')

    element.extend_meta_classes
    element.validate

    struct[label] = element
  }

  struct
}
