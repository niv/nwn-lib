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
  def to_yaml_type
    "!#{NWN::YAML_DOMAIN}/struct"
  end

  # Returns true if we can later infer the struct_id with the given path.
  def can_infer_struct_id?
    NWN::Gff.get_struct_defaults_for(self.path, '__struct_id') != nil
  end

  # Returns true if we can infer the data version of this struct (if it has parent).
  def can_infer_data_version?
    @data_version == DEFAULT_DATA_VERSION || (
      @element && @element.parent && @element.parent.data_version == @data_version
    )
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
        map.add('__' + 'data_version', @data_version) if @data_version && !can_infer_data_version?
        map.add('__' + 'struct_id', @struct_id) if @struct_id && !can_infer_struct_id?

        reject {|k, v|
          # Dont emit fields that would result in their default values anyways.
          v.can_infer_type? && v.can_infer_str_ref? && v.can_infer_value?
        }.sort.each {|k,v|
          map.add(k,v)
        }
      end
    end
  end
end

module NWN::Gff::Field
  YAMLCompactableFields = [:byte, :char, :word, :short, :dword, :int,
    :dword64, :int64, :float, :double, :cexostr, :resref, :list]

  # Returns true if we can later infer the field type.
  def can_infer_type?
    expected = NWN::Gff.get_struct_default_type(@parent.path, field_label)
    # We can compact cexostrs into a :resref, if they're shorter than 17 bytes.
    # They'll get written out as :resref afterwards.
    expected == field_type || (expected == :resref && field_type == :cexostr && field_value.size <= 16)
  end

  # Returns true if we can later infer the default value.
  def can_infer_value?
    NWN::Gff.get_struct_default_value(@parent.path, field_label) == field_value
  end

  # Returns true if we can infer the str ref later on.
  def can_infer_str_ref?
    !has_str_ref?
  end

  # Can we print this field without any syntactic gizmos?
  def can_compact_print?
    YAMLCompactableFields.index(field_type) && can_infer_str_ref? && can_infer_type?
  end

  def to_yaml(opts = {})
    if can_compact_print?
      field_value.to_yaml(opts)

    else
      YAML::quick_emit(nil, opts) do |out|
        out.map(taguri, to_yaml_style) do |map|
          map.style = :inline unless NWN::Gff::YAMLNonInlineableFields.index(self['type'])
          map.add('type', self['type']) unless can_infer_type?
          map.add('str_ref', self['str_ref']) if self.has_str_ref? && !can_infer_str_ref?
          map.add('value', self['value']) unless can_infer_value?
        end
      end
    end
  end
end

module NWN::Gff
  @YAMLStructDefaults = {}

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

  # This loads structs defaults from the given file, which will
  # be used for field_type inferring and autocompletion/filtering of default values.
  # A sample file has been provided with nwn-lib, called gff-bioware.yml
  def self.load_struct_defaults file
    @YAMLStructDefaults = YAML.load(IO.read(file))
    @YAMLStructDefaults.each {|k,v|
      @YAMLStructDefaults.delete(k)
      @YAMLStructDefaults[Regexp.new('^' + k + '$')] = v
    }
  end

  def self.get_struct_defaults
    @YAMLStructDefaults || {}
  end

  def self.get_struct_defaults_for path, key
    sd = NWN::Gff.get_struct_defaults
    matching = sd.keys.reject {|vx| path !~ vx }
    return nil if matching.empty?
    path = matching[0]

    if sd[path] && dd = sd[path][key]
      dd
    else
      nil
    end
  end

  def self.get_struct_default_type path, key
    dd = get_struct_defaults_for(path, key)
    dd.is_a?(Array) ? dd[0] : dd
  end

  def self.get_struct_default_value path, key
    dd = get_struct_defaults_for(path, key)
    dd.is_a?(Array) ? dd[1] : nil
  end
end

# This parses the struct and extends all fields with their proper type.
YAML.add_domain_type(NWN::YAML_DOMAIN,'struct') {|t,hash|
  struct = {}.taint
  struct.extend(NWN::Gff::Struct)

  # The metadata
  struct.struct_id = hash.delete('__struct_id')
  struct.data_type = hash.delete('__data_type')
  struct.data_version = hash.delete('__data_version')
  struct.data_version ||= NWN::Gff::Struct::DEFAULT_DATA_VERSION

  if struct.struct_id.nil? && s_id = NWN::Gff.get_struct_defaults_for(struct.path, '__struct_id')
    struct.struct_id = s_id.to_i
  elsif struct.struct_id.nil?
    raise NWN::Gff::GffError, "Cannot infer implicit struct_id for struct at #{struct.path}."
  end

  hash.each {|label,element|
    # Its not a hash, so it is a compacted value.
    element = {'value' => element} if !element.is_a?(Hash)

    element.extend(NWN::Gff::Field)
    element.field_label = label
    element.parent = struct
    element.str_ref ||= NWN::Gff::Field::DEFAULT_STR_REF

    if element.field_type.nil? && field_type = NWN::Gff.get_struct_default_type(struct.path, element.field_label)
      element.field_type = field_type
    elsif element.field_type.nil?
     raise NWN::Gff::GffError, "Cannot infer implicit type for /#{label} while parsing struct-id #{struct.struct_id}."
    end

    case element.field_type
      when :list
        element.extend(NWN::Gff::List)
      when :struct
        element.extend(NWN::Gff::Struct)
      when :cexolocstr
        element.field_value.extend(NWN::Gff::CExoLocString)
        element.field_value.compact!
    end

    struct[label] = element.taint
  }

  NWN::Gff.__yaml_postparse nil, struct if struct.data_type
  struct
}
