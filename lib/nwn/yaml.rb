require 'yaml'

# See http://www.taguri.org/ for the exact meaning of this.
NWN::YAML_DOMAIN = "nwn-lib.elv.es,2008-12"

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


class NWN::Gff::Gff
  def to_yaml_properties
    [ '@type', '@version', '@hash' ]
  end

  def to_yaml_type
    "!#{NWN::YAML_DOMAIN}/gff"
  end

  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        to_yaml_properties.each do |m|
          map.add(m[1..-1], instance_variable_get(m))
        end
      end
    end
  end
end

class NWN::Gff::Struct
  def to_yaml_properties
    [ '@struct_id', '@hash' ]
  end

  def to_yaml_type
    "!#{NWN::YAML_DOMAIN}/struct"
  end

  def to_yaml(opts = {})
    YAML::quick_emit(nil, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        # Inline certain structs that are small enough.
        map.style = :inline if hash.size <= 1 &&
          hash.values.select {|x|
            NWN::Gff::Element::NonInline.index(x.type)
          }.size == 0

        to_yaml_properties.each do |m|
          map.add(m[1..-1], instance_variable_get(m))
        end
      end
    end
  end
end

class NWN::Gff::CExoLocString
  def to_yaml_type
    "!#{NWN::YAML_DOMAIN}/cexolocstr"
  end
end

class NWN::Gff::Element
  def to_yaml_properties
    [ '@type', '@str_ref', '@value' ]
  end

  def to_yaml_type
    "!#{NWN::YAML_DOMAIN}/element"
  end

  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        map.style = :inline unless NonInline.index(self.type)
        to_yaml_properties.each do |m|
          map.add(m[1..-1], instance_variable_get(m)) unless instance_variable_get(m).nil?
        end
      end
    end
  end
end

YAML.add_domain_type(NWN::YAML_DOMAIN,'element') {|t,v|
  YAML.object_maker(NWN::Gff::Element, v)
}

YAML.add_domain_type(NWN::YAML_DOMAIN,'cexolocstr') {|t,v|
  YAML.object_maker(NWN::Gff::CExoLocString, v)
}

YAML.add_domain_type(NWN::YAML_DOMAIN,'struct') {|t,v|
  YAML.object_maker(NWN::Gff::Struct, v)
}

YAML.add_domain_type(NWN::YAML_DOMAIN,'gff') {|t,v|
  YAML.object_maker(NWN::Gff::Gff, v)
}
