module NWN::Gff::List

  # Add a new struct member to this list.
  # You can either add an existing struct to this list
  # (which will reparent it by setting .element), or specify
  # a new struct with a block, or both:
  #
  #   root = Gff::Struct.new 0xffffffff, "UTI", "V3.2"
  #   list = root.add_list 'test', []
  #   list.add_struct 1 do |l|
  #     l.add_byte 'inner_test', 5
  #     l.add_cexolocstr 'exolocstr', { 0 => 'Hello', 4 => 'Hallo' }
  #   end
  #   y root
  #
  # results in:
  #   --- !nwn-lib.elv.es,2008-12/struct
  #   __data_type: UTI
  #   __struct_id: 4294967295
  #   test:
  #   type: :list
  #     value:
  #     - !nwn-lib.elv.es,2008-12/struct
  #       __data_type: UTI/test
  #       __struct_id: 1
  #       exolocstr:
  #         type: :cexolocstr
  #         value:
  #           0: Hello
  #           4: Hallo
  #       inner_test: {type: :byte, value: 5}}
  def add_struct struct_id_or_struct = 0, &block
    struct = case struct_id_or_struct
      when Integer
        s = NWN::Gff::Struct.new
        s.struct_id = struct_id_or_struct
        s

      when NWN::Gff::Struct
        struct_id_or_struct

      else
        raise ArgumentError, "specify either a struct_id or an existing struct"
    end

    struct.element = self

    yield(struct) if block_given?

    self.v << struct
    struct
  end
end
