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

module NWN::Gff::Cexolocstr
  def field_value_as_compact
    field_value.merge({'str_ref' => str_ref})
  end
end

module NWN::Gff::Field
  YAMLCompactableFields = [:byte, :char, :word, :short, :dword, :int,
    :dword64, :int64, :float, :double, :cexostr, :resref, :cexolocstr, :list]

  # Returns true if we can later infer the field type.
  def can_infer_type?
    expected = NWN::Gff.get_struct_default_type(@parent.path, field_label)

    raise NWN::Gff::GffError, "#{field_label} has field_type " +
      "#{field_type.inspect}, but infer data says #{expected.inspect}." if
        expected && expected != field_type

    expected == field_type
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

    YAMLCompactableFields.index(field_type) &&
      # exolocs print their str_ref along with their language keys
      (field_type == :cexolocstr || can_infer_str_ref?) &&
      can_infer_type?
  end

  def can_compact_as_list?
    NWN::Gff.get_struct_defaults_for(self.path, '__compact') != nil
  end

  def get_compact_as_list_field
    NWN::Gff.get_struct_defaults_for(self.path, '__compact')
  end

  def field_value_as_compact
    field_value
  end

  def to_yaml(opts = {})
    if (field_type == :list && can_compact_as_list?)
      YAML::quick_emit(nil, opts) do |out|
        out.seq("!", to_yaml_style) do |seq|
          field_value.each {|item|
            calf = get_compact_as_list_field
            case calf
              when Array
                  ar = calf.map {|ik| item[ik] || NWN::Gff.get_struct_default_value(self.path, ik) }

                  raise NWN::Gff::GffError, "cannot compact list-structs which do not " +
                    "have all compactable field values set or are inferrable." if ar.size != ar.compact.size
                  ar.to_yaml_style = :inline
                  seq.add(ar)
              else
                seq.style = :inline
                seq.add(item[calf])
            end
          }
        end
      end

    elsif can_compact_print?
      field_value_as_compact.to_yaml(opts)

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
    new = {}
    @YAMLStructDefaults.each {|k,v|
      new[Regexp.new('^' + k + '$')] = v
    }
    @YAMLStructDefaults = new
  end

  def self.get_struct_defaults
    @YAMLStructDefaults || {}
  end

  def self.get_struct_defaults_for path, key
    sd = NWN::Gff.get_struct_defaults
    sd.keys.each {|rx|
      next unless path =~ rx
      return sd[rx][key] if sd[rx][key]
    }
    nil
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
    element = case element
      when Hash # already uncompacted or a compacted exolocstr
        # It has only got numbers as key, we *assume* its a cexoloc.
        # Thats okay, because type inferration will catch it later and bite us. Hopefully.
        if element.size > 0 && element.keys.select {|x| x.to_s !~ /^(str_ref|\d+)$/}.size == 0
          element = {
            'type' => :cexolocstr,
            'str_ref' => element.delete('str_ref') || NWN::Gff::Field::DEFAULT_STR_REF,
            'value' => element,
          }
        end

        element

      when Array # compacted struct-list
        element = {
          'type' => :list,
          'value' => element,
        }
        path = struct.data_type + "/" + label
        unpack_struct_element = NWN::Gff.get_struct_defaults_for(path, '__compact')
        if unpack_struct_element
          # If it doesn't have unpack data, we need to assume its a compacted list itself.
          # Sorry.
          # Hope this wont bite anyone later on.

          #raise NWN::Gff::GffError,
          #  "Cannot unpack compacted struct list at #{path}, no infer data available." unless
          #    unpack_struct_element

          unpack_struct_element_struct_id =
            NWN::Gff.get_struct_defaults_for(path, "__struct_id")

          raise NWN::Gff::GffError,
            "Cannot infer struct_id of #{path}/#{unpack_struct_element}, " +
            "invalid value: #{unpack_struct_element_struct_id}" unless
              unpack_struct_element_struct_id.is_a?(Fixnum)

          unpack_struct_elements = [unpack_struct_element].flatten

          unpack_struct_element_types = unpack_struct_elements.map {|unpack_struct_element|
            raise NWN::Gff::GffError, "While unpacking #{path}: " +
              "#{unpack_struct_element} is not a field-naime, dummy." unless
                unpack_struct_element.is_a?(String)

            unpack_struct_element_type =
              NWN::Gff.get_struct_default_type(path, unpack_struct_element)

            raise NWN::Gff::GffError,
              "Cannot infer type of #{path}/#{unpack_struct_element}, " +
              "invalid value: #{unpack_struct_element_type}" unless
                unpack_struct_element_type && NWN::Gff::Types.index(unpack_struct_element_type)

            unpack_struct_element_type
          }

          element['value'].map! {|kv|
            kv = [kv].flatten
            st = {}
            st.extend(NWN::Gff::Struct)
            st.struct_id = unpack_struct_element_struct_id
            st.data_type = path

            unpack_struct_elements.each_with_index {|use, index|
              uset = unpack_struct_element_types[index]
              el = st[use] = {
                'label' => use,
                'type' => uset,
                'value' => kv[index]
              }
              el.extend(NWN::Gff::Field)
              el.extend_meta_classes
              el.parent = st
            }

            st
          }
        end
        element

      when Numeric, String # compacted scalar
        {'value' => element}

      else
        fail "Don't know how to un-compact /#{label}: #{element.inspect}, klass #{element.class.to_s}"
    end

    element.extend(NWN::Gff::Field)
    element.field_label = label
    element.parent = struct
    element.str_ref ||= NWN::Gff::Field::DEFAULT_STR_REF

    infer_field_type = NWN::Gff.get_struct_default_type(struct.path, element.field_label)

    if element.field_type && infer_field_type && infer_field_type != element.field_type
      raise NWN::Gff::GffError, "/#{label} has field_type #{element.field_type.inspect}, but infer data says #{infer_field_type.inspect}."

    elsif element.field_type.nil? && infer_field_type.nil?
      raise NWN::Gff::GffError, "Cannot infer implicit type for /#{label} while parsing struct-id #{struct.struct_id}."

    elsif element.field_type.nil? && infer_field_type
      element.field_type = infer_field_type
    end


    element.extend_meta_classes

    struct[label] = element.taint
  }

  NWN::Gff.__yaml_postparse nil, struct if struct.data_type
  struct
}
