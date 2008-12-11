module NWN::Gff::Struct

    # yield (key, value) for each element, recursing into substructs.

    # Parses +s+ as an arbitary GFF object and yields for each field found,
    # with the proper prefix.
    #
    # [+prefix+]     Supply a prefix to add to the output.
    # [+types_too+]  Yield type definitions as well (gffprint.pl -t).
    # [+add_prefix+] Add a prefix <tt>(unknown type)</tt> of no type information can be derived from the input.
    # [+file_type+]  File type override. If non-null, add a global struct header with the given file type (useful for passing to gffencode.pl)
    # [+struct_id+]  Provide a struct_id override (if printing a struct).
    def kivinen_format types_too = false, add_prefix = true, file_type = nil, struct_id = nil, &block

      if types_too
        yield("/", "")

        ftype = file_type ? file_type : self.data_type
        yield("/ ____file_type", ftype) if ftype
        yield("/ ____file_version", self.data_version) if self.data_version

        yield("/ ____struct_type", self.struct_id)
      end

      self.each_by_flat_path {|path, field|
        case field
          when String
            yield(path, field)

          when NWN::Gff::Struct
            yield(path, path)
            yield(path + " ____struct_type", field.struct_id)

          when NWN::Gff::Field
            case field.field_type
              when :list
              when :struct
              when :cexolocstr
              else
                yield(path, field.field_value)
            end

            yield(path + ". ____string_ref",field.str_ref) if
              field.has_str_ref?
            yield(path + ". ____type", NWN::Gff::Types.index(field.field_type)) if
              types_too

        end
      }
    end
end
