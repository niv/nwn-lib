module NWN::Gff::Handler::Kivinen
  def self.load io
    raise NotImplementedError, "Reading kivinen not supported"
  end

  def self.dump struct, io
    ret = ""
    format struct, $options[:types], nil, nil do |l,v|
      ret += "%s:\t%s\n" % [l, v]
    end
    io.puts ret
    ret.size
  end

  # Parses +s+ as an arbitary GFF object and yields for each field found,
  # with the proper prefix.
  #
  # [+struct+]     The root-struct to dump
  # [+prefix+]     Supply a prefix to add to the output.
  # [+types_too+]  Yield type definitions as well (gffprint.pl -t).
  # [+add_prefix+] Add a prefix <tt>(unknown type)</tt> of no type information can be derived from the input.
  # [+file_type+]  File type override. If non-null, add a global struct header with the given file type (useful for passing to gffencode.pl)
  # [+struct_id+]  Provide a struct_id override (if printing a struct).
  def self.format struct, types_too = false, add_prefix = true, file_type = nil, struct_id = nil, &block

    if types_too
      yield("/", "")

      ftype = file_type ? file_type : struct.data_type
      yield("/ ____file_type", ftype) if ftype
      yield("/ ____file_version", struct.data_version) if struct.data_version

      yield("/ ____struct_type", struct.struct_id)
    end

    struct.each_by_flat_path {|path, field|
      case field
        when String
          yield(path, field)

        when NWN::Gff::Struct
          yield(path + "/", path)
          yield(path + "/ ____struct_type", field.struct_id)

        when NWN::Gff::Field

          case field.field_type
            when :list
            when :struct
              yield(path + "/", path)
              yield(path + "/ ____struct_type", field.field_value.struct_id)
            when :cexolocstr
            when :void
              yield(path, field.field_value.unpack("H*")[0])
            else
              yield(path, field.field_value)
          end

          yield(path + ". ____string_ref",field.str_ref) if
            field.has_str_ref? || field.field_type == :cexolocstr

          yield(path + ". ____type", NWN::Gff::Types.key(field.field_type)) if
            types_too

      end
    }
  end
end

NWN::Gff::Handler.register :kivinen, /^k(ivinen)?$/, NWN::Gff::Handler::Kivinen, false, true
