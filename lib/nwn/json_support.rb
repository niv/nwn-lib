require 'json'
require 'base64'

module NWN::Gff::Struct
  def json_box
    t = Hash[self]
    t.merge!({
      '__struct_id' => self.struct_id
    })
    t.merge!({
      '__data_version' => self.data_version,
    }) if self.data_version && self.data_version !=
      NWN::Gff::Struct::DEFAULT_DATA_VERSION
    t.merge!({
      '__data_type' => self.data_type
    }) if @data_type
    t
  end
  private :json_box

  def to_json(*a)
    json_box.to_json(*a)
  end
end

module NWN::Gff::Field
  def json_box
    t = Hash[self]
    t.delete('label')
    case field_type
      when :void
        t['value'] = Base64::strict_encode64(t['value'])
    end
    t
  end
  private :json_box

  def to_json(*a)
    json_box.to_json(*a)
  end
end

module NWN::Gff::Handler::JSON
  def self.json_unbox_field element, parent_label, parent
    element.extend(NWN::Gff::Field)
    element.field_label = parent_label
    element.parent = parent
    element.str_ref ||= NWN::Gff::Field::DEFAULT_STR_REF if element.respond_to?('str_ref=')

    element.extend_meta_classes
    case element.field_type
      when :cexolocstr
        element.field_value.keys.each {|key|
          val = element.field_value.delete(key)
          element.field_value[key.to_i] = val
        }

      when :void
        element.field_value = Base64::strict_decode64(element.field_value)

      when :list
        mod = {}
        element.field_value.each_with_index {|x,idx|
          mod[idx] = self.json_unbox_struct(x, element)
        }
        mod.each {|x,y|
          element.field_value[x] = y
        }
      when :struct
        element.field_value = self.json_unbox_struct(element.field_value, element)
    end
    element.validate
    element
  end

  def self.json_unbox_struct o, parent = nil
    o.extend(NWN::Gff::Struct)
    o.element = parent if parent
    o.struct_id = o.delete('__struct_id')
    o.data_type = o.delete('__data_type')
    o.data_version = o.delete('__data_version')
    o.data_version ||= NWN::Gff::Struct::DEFAULT_DATA_VERSION

    NWN.log_debug("Unboxed without a root data type") if
      !parent && !o.data_type
    NWN.log_debug("Unboxed with explicit data type #{o.data_type.inspect}") if
      parent && o.data_type

    o.each {|label,element|
      o[label] = self.json_unbox_field(element, label, o)
    }

    o
  end

  def self.load io
    json = if io.respond_to?(:to_str)
      io.to_str
    elsif io.respond_to?(:to_io)
      io.to_io.read
    else
      io.read
    end

    self.json_unbox_struct(JSON.parse(json), nil)
  end

  def self.dump struct, io
    d = if NWN.setting(:pretty_json)
      ::JSON.pretty_generate(struct)
    else
      ::JSON.generate(struct)
    end
    io.puts d
    d.size + 1
  end
end

NWN::Gff::Handler.register :json, /^json$/, NWN::Gff::Handler::JSON
