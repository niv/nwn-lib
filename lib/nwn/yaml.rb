require 'yaml'

# See http://www.taguri.org/ for the exact meaning of this.
NWN::YAML_DOMAIN = "nwn-lib.elv.es,2008-12"

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
    YAML::quick_emit(object_id, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        sort.each do |k, v|
          map.add(k, v)
        end
      end
    end
  end
end

module NWN::Gff::Struct
  def to_yaml_properties
    [ '@data_type', '@data_version', '@struct_id' ]
  end

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

        to_yaml_properties.each do |m|
          map.add('__' + m[1..-1], instance_variable_get(m)) if instance_variable_get(m)
        end

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
        map.add('str_ref', self['str_ref']) if self.has_str_ref?
        map.add('value', self['value'])
      end
    end
  end
end

module NWN::Gff
#:stopdoc:
  # This gets called for each parsed struct to set their container element
  # values (see also gff/reader.rb, line 233-ish).
  def self.__yaml_postparse parent, struct
    struct.each {|label,element|
      case element.field_type
        when :list, :struct
          [element.field_value].flatten.each {|item|
            __yaml_postparse(element, item)
            item.element = element
          }
      end
    }
  end
#:startdoc:
end

# This parses the struct and extends all fields with their proper type.
YAML.add_domain_type(NWN::YAML_DOMAIN,'struct') {|t,hash|
  struct = {}
  struct.extend(NWN::Gff::Struct)

  # The metadata
  struct.struct_id = hash.delete('__struct_id')
  struct.data_type = hash.delete('__data_type')
  struct.data_version = hash.delete('__data_version')

  hash.each {|label,element|
     raise NWN::Gff::GffError, "Type nil for label #{label} while parsing struct-id #{struct.struct_id}." if
       element['type'].nil?

    element.extend(NWN::Gff::Field)

    case element['type']
      when :list
        element.extend(NWN::Gff::List)
      when :struct
        element.extend(NWN::Gff::Struct)
      when :cexolocstr
        element.extend(NWN::Gff::CExoLocString)
    end

    element.field_label = label
    element.parent = struct
    struct[label] = element
  }

  NWN::Gff.__yaml_postparse nil, struct
  struct
}
