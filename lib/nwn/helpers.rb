require 'nwn/gff'
require 'nwn/twoda'

module NWN

  module TwoDA

    # This is a simple 2da cache.
    module Cache

      @_cache = {}
      @_root = nil

      # Set the file system path where all 2da files reside.
      # Call this on application startup.
      def self.setup root
        @_root = root
      end

      # Get the 2da file with the given name. +name+ is without extension.
      def self.get(name)
        raise Exception, "You need to set up the cache first through Cache.setup." unless @_root
        @_cache[name.downcase] ||= read_2da(name.downcase)
      end

      def self.read_2da name # :nodoc:
        Table.parse IO.read(@_root + '/' + name + '.2da')
      end

      private_class_method :read_2da
    end
  end

  module Gff

    # Parses +s+ as an arbitary GFF object and yields for each field found,
    # with the proper prefix.
    #
    # [+s+]          The gff object to yield pairs for; can be one of NWN::Gff::Gff, NWN::Gff::Struct, Array (for lists), or NWN::Gff::Element.
    # [+prefix+]     Supply a prefix to add to the output.
    # [+types_too+]  Yield type definitions as well (gffprint.pl -t).
    # [+add_prefix+] Add a prefix <tt>(unknown type)</tt> of no type information can be derived from the input.
    # [+file_type+]  File type override. If non-null, add a global struct header with the given file type (useful for passing to gffencode.pl)
    # [+struct_id+]  Provide a struct_id override (if printing a struct).
    def self.kivinen_format s, prefix = "/", types_too = false, add_prefix = true, file_type = nil, struct_id = nil, &block
      if s.is_a?(NWN::Gff::Gff)
        if types_too
          yield("/", "")
          yield("/ ____file_type", file_type.nil? ? s.type : file_type)
          yield("/ ____file_version", s.version)
        end
        s = NWN::Gff::Element.new("", :struct, s.root_struct)
      elsif file_type != nil
        yield("/", "")
        yield("/ ____file_type", file_type)
        yield("/ ____file_version", "V3.2")
      end

      if s.is_a?(Array)
        v = NWN::Gff::Element.new(add_prefix ? "(unlabeled list)" : "", :list, s)
      end

      if s.is_a?(NWN::Gff::Struct)
        s = NWN::Gff::Element.new(add_prefix ? "(unlabeled struct)" : "", :struct, s)
      end

      if s.is_a?(String)
        yield("(unlabeled string)" + prefix, s)
        return
      end

      case s.type
        when :struct
          yield(prefix + " ____struct_type", struct_id.nil? ? s.value.struct_id : struct_id) if types_too
          s.value.sort.each {|k,v|
            kivinen_format v, prefix + s.label + (s.label == "" ? "" : "/"), types_too do |l,v|
              yield(l, v)
            end
          }

        when :cexolocstr

          s.value.each {|kk,vv|
            yield(prefix + s.label + "/" + kk.to_s, vv.gsub(/([\000-\037\177-\377%])/) {|v| "%" + v.unpack("H2")[0] })
          }
          yield(prefix + s.label + ". ____string_ref", s.str_ref)

        when :list
          s.value.each_with_index {|vv, idx|
            if types_too
              yield(prefix + s.label + "[#{idx}]/", prefix + s.label + "[#{idx}]")
              yield(prefix + s.label + "[#{idx}]/" + " ____struct_type", 0)
            end
            vv.each {|kkk, vvv|
              kivinen_format vvv, prefix + s.label + "[#{idx}]/", types_too do |l,v|
                yield(l,v)
              end
            }
          }
        when :cexostr
          yield(prefix + s.label, s.value.gsub(/([\000-\037\177-\377%])/) {|v| "%" + v.unpack("H2")[0] })
        else
          yield(prefix + s.label, s.value)
      end

      if types_too && s.label != ""
        yield(prefix + s.label + ". ____type", Types.index(s.type).to_s)
      end
    end

    module Helpers
      # This sets up the IPRP cache. Used internally; no need to call this yourself.
      def self._ip_cache_setup #:nodoc:
        return if defined? @costtables
        @costtables = {}
        @paramtables = {}
        @costtable_index = NWN::TwoDA::Cache.get('iprp_costtable')
        @paramtable_index = NWN::TwoDA::Cache.get('iprp_paramtable')
        @costtable_index.by_col('Name').each_with_index {|p,idx|
          next if @costtables[p.downcase]
          @costtables[p.downcase] = @costtables[idx] = NWN::TwoDA::Cache.get(p.downcase)
        }
        @paramtable_index.by_col('TableResRef').each_with_index {|p,idx|
          next if @paramtables[p.downcase]
          @paramtables[p.downcase] = @paramtables[idx] = NWN::TwoDA::Cache.get(p.downcase)
        }
        @properties = NWN::TwoDA::Cache.get('itemprops')
        @propdef = NWN::TwoDA::Cache.get('itempropdef')
        @subtypes = []
        @propdef.by_col('SubTypeResRef').each_with_index {|st, idx|
          @subtypes[idx] = NWN::TwoDA::Cache.get(st.downcase) if st != "****"
        }
        @prop_id_to_costtable = []
        @propdef.by_col('CostTableResRef').each_with_index {|st, idx|
          @prop_id_to_costtable[idx] = st.to_i if st != "****"
        }
        @prop_id_to_param1 = []
        @propdef.by_col('Param1ResRef').each_with_index {|st, idx|
          @prop_id_to_param1[idx] = st.to_i if st != "****"
        }
      end

      def self.resolve_or_match_partial name_spec, list #:nodoc:
        name_spec = name_spec.downcase

        raise ArgumentError, "?-expand: #{list.inspect}" if name_spec == '?'

        list.each {|l|
          return l if l.downcase == name_spec
        }

        substrings = list.select {|l| l.downcase.index(name_spec) }
        if substrings.size == 1
          return substrings[0]
        elsif substrings.size > 1
          raise ArgumentError, "Cannot resolve #{name_spec}. Partial matches: #{substrings.inspect}."
        end

        raise ArgumentError, "Cannot resolve #{name_spec}."
      end

      # This creates a NWN::Gff::Struct describing the item property in question.
      #
      # [+name+]    The iprp name to resolve, for example <tt>Damage_Bonus_vs_Racial_Group</tt>
      # [+subtype+] The iprp subtype, for example <tt>Elf</tt>
      # [+value+]   The iprp value, for example <tt>2d12</tt>
      # [+param+]  The iprp param1, for example <tt>Acid</tt>
      # [+chance+]  The iprp appearance chance (whats this?)
      #
      # Depends on the 2da cache set up correctly.
      #
      # Note that the given arguments can be resolved with partial matches as well, as long
      # as they are unique. (<tt>Fir -> Fire</tt>)
      #
      # Arguments are case-insensitive.
      def self.item_property name, subtype = nil, value = nil, param1 = nil, chance_appear = 100
        self._ip_cache_setup

        struct = NWN::Gff::Struct.new

        name = resolve_or_match_partial name, @properties.by_col('Label')
        index = @properties.by_col('Label').index(name)
        raise ArgumentError, "Cannot find property #{name}" unless index

        raise ArgumentError, "Property #{name} needs subtype of type #{NWN::TwoDA::Cache.get('itempropdef').by_col('SubTypeResRef', index)}, but none given." if
          @subtypes[index] && !subtype
        raise ArgumentError, "Property #{name} does not need subtype, but subtype given." if
          !@subtypes[index] && subtype

        subindex = 255

        if subtype
          subtype = resolve_or_match_partial subtype, @subtypes[index].by_col('Label')

          subindex = @subtypes[index].by_col('Label').index(subtype)
          raise ArgumentError, "Cannot find subtype #{subtype} for property #{name}" unless
            subindex

          raise ArgumentError, "Property #{name} requires a cost value of type #{@costtable_index.by_row(@prop_id_to_costtable[index], 'Name')}, but none given" if
            !value && @prop_id_to_costtable[index]
          raise ArgumentError, "Property #{name} does not require a cost value, but value given" if
            value && !@prop_id_to_costtable[index]
        end

        _cost = 255
        _cost_value = 0

        if value
          ct = @prop_id_to_costtable[index]
          value = resolve_or_match_partial value, @costtables[ct.to_i].by_col('Label')

          costvalue = @costtables[ct.to_i].by_col('Label').index(value)
          raise ArgumentError, "Cannot find CostValue for #{value}" unless costvalue
          _cost = ct
          _cost_value = costvalue
        end
        struct.merge!({
          'CostTable' => Element.new('CostTable', :byte, _cost),
          'CostValue' => Element.new('CostValue', :word, _cost_value)
        })


        raise ArgumentError, "Property #{name} requires a param1 value of type #{@paramtable_index.by_row(@prop_id_to_param1[index], 'TableResRef')}, but none given" if
          !param1 && @prop_id_to_param1[index]
        raise ArgumentError, "Property #{name} does not require a param1 value, but value given" if
          param1 && !@prop_id_to_param1[index]

        _param1 = 255
        _param1_value = 0

        if param1
          pt = @prop_id_to_param1[index]
          param1 = resolve_or_match_partial param1, @paramtables[pt.to_i].by_col('Label')

          param1value = @paramtables[pt.to_i].by_col('Label').index(param1)
          raise ArgumentError, "Cannot find Param1 for #{param1}" unless param1value
          _param1 = pt
          _param1_value = param1value
        end
        struct.merge!({
          'Param1' => Element.new('Param1', :byte, _param1),
          'Param1Value' => Element.new('Param1Value', :byte, _param1_value)
        })

        struct.merge!({
          'PropertyName' => Element.new('PropertyName', :word, index),
          'Subtype' => Element.new('Subtype', :word, subindex),
          'ChanceAppear' => Element.new('ChanceAppear', :byte, chance_appear)
        })

        struct.struct_id = 0
        struct
      end

    end
  end
end
