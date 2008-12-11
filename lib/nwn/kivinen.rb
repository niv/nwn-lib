module NWN::Gff::Field
  # Used by NWN::Gff::Struct#kivinen_format to print out data fields.
  def kivinen_format yield_str_ref = true, yield_type = false
    case self.field_type
      when :cexolocstr
        field_value.sort.each {|lid,str|
          yield("/" + lid.to_s, str)
        }
        yield(". ____string_ref", str_ref.to_s) if yield_str_ref

      when :struct
        field_value.kivinen_format {|v,x|
          yield(v, x)
        }

      when :list
        field_value.each_with_index {|item, index|
          item.kivinen_format("/", yield_str_ref, yield_type) {|v, x|
            yield("[" + index.to_s + "]" + v, x)
          }
        }

      else
        yield("", self.field_value.to_s)
    end

    yield(". ____type", NWN::Gff::Types.index(field_type).to_s) if yield_type
  end
end

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
    def kivinen_format prefix = "/", types_too = false, add_prefix = true, file_type = nil, struct_id = nil, &block

      if types_too
        yield(prefix, "")

        ftype = file_type.nil? ? self.type : file_type
        yield(prefix + " ____file_type", ftype) if ftype
        yield(prefix + " ____file_version", self.version) if self.version

        yield(prefix + " ____struct_type", self.struct_id)
      end

      # Now dump all members of this struct.
      self.sort.each {|label, element|
        element.kivinen_format(true, types_too) {|llabel, lvalue|
          yield(prefix + label + llabel, lvalue)
        }
      }

    end
end
