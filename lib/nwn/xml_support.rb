require 'base64'

class NWN::Gff::Handler::XML

private

  def struct_to_xml struct
    s = XML::Node.new('struct')
    case @format
      when :nxml
        s['id'] = struct.struct_id.to_s
        s['dataType'] = struct.data_type if struct.data_type
        s['dataVersion'] = struct.data_version if
          struct.data_version != NWN::Gff::Struct::DEFAULT_DATA_VERSION
      when :modpacker
        s['id'] = [struct.struct_id].pack("L").unpack("l")[0].to_s
        s['nwnLibDataType'] = struct.data_type if struct.data_type
        s['nwnLibDataVersion'] = struct.data_version if
          struct.data_version != NWN::Gff::Struct::DEFAULT_DATA_VERSION
    end

    struct.sort.each {|(*,v)|
      s << field_to_xml(v)
    }
    s
  end

  def field_to_xml field
    e = case @format
      when :nxml
        XML::Node.new('field')
      when :modpacker
        XML::Node.new('element')
    end
    e['name'] = field.field_label
    e['type'] = case @format
      when :modpacker
        NWN::Gff::Types.key(field.field_type).to_s
      when :nxml
        field.field_type.to_s
    end

    case field.field_type
      when :cexolocstr
        case @format
          when :modpacker
            e['value'] = [field.str_ref].pack("L").unpack("l")[0].to_s
          when :nxml
            e['strRef'] = field.str_ref.to_s if
              field.str_ref != NWN::Gff::Cexolocstr::DEFAULT_STR_REF
        end

        field.field_value.each {|lid, tx|
          e << se = XML::Node.new("localString")
          se['languageId'] = lid.to_s
          se['value'] = NWN.iconv_gff_to_native(tx)
        }

      when :cexostr
        e['value'] = NWN.iconv_gff_to_native(field.field_value)

      when :struct
        e << struct_to_xml(field.field_value)

      when :list
        field.field_value.each {|ee|
          e << struct_to_xml(ee)
        }

      when :void
          e['value'] = Base64::strict_encode64(field.field_value)

      else
        e['value'] = field.field_value.to_s
    end

    e
  end

  def xml_to_struct e, parent_data_version = nil
    case @format
      when :nxml
        struct_id    = e['id'] || raise("No struct id for: #{e.path}")
        struct_id    = struct_id.to_i
        data_type    = e['dataType']
        parent_data_version ||= NWN::Gff::Struct::DEFAULT_DATA_VERSION
        data_version = e['dataVersion'] || parent_data_version
      when :modpacker
        struct_id    = [e['id'].to_i].pack("l").unpack("L")[0]
        data_type    = e['nwnLibDataType']
        data_version = e['nwnLibDataVersion'] || parent_data_version
    end

    st = NWN::Gff::Struct.new(struct_id, data_type, data_version)
    e.each_element {|f|
      xml_to_field(f, st, parent_data_version) if
        f.name == case @format
          when :modpacker ; 'element'
          when :nxml ; 'field'
        end
    }
    st
  end

  def xml_to_field field, struct, parent_data_version
    name = field['name'] || raise("No name for field: #{field.path}")
    type = case @format
      when :nxml
        field['type']
      when :modpacker
        NWN::Gff::Types[field['type'].to_i]
    end || raise("No type for field: #{field.path}")
    v    = field['value']

    f = struct.add_field(name, type,
      case type.to_sym
        when :cexostr
          NWN.iconv_native_to_gff(v)
        when :cexolocstr
          Hash[field.children.reject {|x| x.node_type != XML::Node::ELEMENT_NODE }.map {|ee|
            [ee['languageId'].to_i, NWN.iconv_native_to_gff(ee['value'] || '')]
          }]
        when :list
          field.children.reject {|x| x.node_type != XML::Node::ELEMENT_NODE }.map {|ee|
            xml_to_struct(ee, parent_data_version)
          }
        when :struct
          xml_to_struct(field.children.select {|x|
              x.node_type == XML::Node::ELEMENT_NODE
            }[0], parent_data_version)
        when :byte, :char, :word, :short, :dword, :int,
            :dword64, :int64
          v.to_i
        when :float, :double
          v.to_f
        when :resref
          v
        when :void
          Base64::strict_decode64(v)
        else
          raise ArgumentError, "Invalid field type #{type.inspect}. Bug."
      end
    )

    f.str_ref = case @format
      when :nxml
        field['strRef'] || NWN::Gff::Cexolocstr::DEFAULT_STR_REF
      when :modpacker
        [v.to_i].pack("l").unpack("L")[0]
    end if f.is_a?(NWN::Gff::Cexolocstr)

    f
  end

public

  def initialize fmt
    @format = fmt
  end

  def load io
    doc = XML::Parser.io(io)
    root = doc.parse.root
    ret = case @format
      when :nxml
        xml_to_struct(root)
      when :modpacker
        struct = root.children.select {|x| x.node_type == XML::Node::ELEMENT_NODE && x.name == 'struct' }[0]
        xml_to_struct(struct, root['version'])
      else
        raise ArgumentError, "Unsupported XML format registered: #{@format.inspect}"
    end

    ret
  end

  def dump data, io
    doc = XML::Document.new
    doc.root = case @format
      when :nxml
        struct_to_xml(data)
      when :modpacker
        nd = XML::Node.new('gff')
        nd['type'] = [data.data_type].pack("A4")
        nd['version'] = [data.data_version].pack("A4")
        nd << struct_to_xml(data)
        nd
      else
        raise ArgumentError, "Unsupported XML format registered: #{@format.inspect}"
    end
    t = doc.to_s
    io.write(t)

    t.size
  end
end

NWN::Gff::Handler.register :nxml, /^nxml$/, NWN::Gff::Handler::XML.new(:nxml)
NWN::Gff::Handler.register :modpacker, nil, NWN::Gff::Handler::XML.new(:modpacker)
