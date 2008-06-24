class GffError < Exception; end
module Gff; end

class Gff::Element < Hash # < Struct.new(:type, :label, :value)
end
class Gff::Struct < Gff::Element
end

class Gff::Reader
	attr_reader :hash
	def initialize(bytes)
		@bytes = bytes
		read_all
	end

	def read_all
		offset = 0

		@type, @version,
		@struct_offset, @struct_count,
		@field_offset, @field_count,
		@label_offset, @label_count,
		@field_data_offset, @field_data_count,
		@field_indices_offset, @field_indices_count,
		@list_indices_offset, @list_indices_count =
			@bytes.unpack("a4a4 VV VV VV VV VV VV")

		raise GffError, "Unknown version #{@version}" unless
			@version == "V3.2"
		
		raise GffError, "structOffset at wrong place, not a gff?" unless
			@struct_offset == 56

		struct_len = @struct_count * 12
		field_len  = @field_count * 16
		label_len  = @label_count * 16

		@structs = @bytes[offset + @struct_offset, struct_len].unpack("V*")
		@fields  = @bytes[offset + @field_offset, field_len].unpack("V*")
		@labels  = @bytes[offset + @label_offset, label_len].unpack("A16" * @label_count)
		@field_data = @bytes[offset + @field_data_offset, @field_data_count]
		@field_indices = @bytes[offset + @field_indices_offset, @field_indices_count].unpack("V*")
		@list_indices = @bytes[offset + @list_indices_offset, @list_indices_count].unpack("V*")

		@gff = {}
		all = read_struct 0
		@hash = all
	end

	# This iterates through a struct and reads all fields into a hash, which it returns.
	def read_struct index
		struct = Gff::Struct.new # gff = {}

		type = @structs[index * 3]
		data_or_offset = @structs[index * 3 + 1]
		count = @structs[index * 3 + 2]

		raise GffError, "Struct index #{index} outside of struct_array" if
			index * 3 + 3 > @structs.size + 1

		if count == 1
			lbl, vl = * read_field(data_or_offset)
			struct[lbl] = vl
		else
			return 1 if count == 0
			raise GffError, "Struct index not divisable by 4" if
				data_or_offset % 4 != 0
			data_or_offset /= 4
			for i in data_or_offset...(data_or_offset+count)
				lbl, vl = * read_field(@field_indices[i])
				struct[lbl] = vl
			end
		end

		struct.merge! :type => type
		struct
	end

	# Reads the field at +index+ and returns [label_name, Gff::Element]
	def read_field index
		gff = {}

		field = Gff::Element.new

		index *= 3
		type = @fields[index]
		label_index = @fields[index + 1]
		data_or_offset = @fields[index + 2]
		
		raise GffError, "Label index #{label_index} outside of label array" if
			label_index > @labels.size
		
		label = @labels[label_index]

		if @type == 14 || @type == 15
			raise "UnsupportedDtpyE"
		else
		end
		value = case type
			when 0 #byte
				data_or_offset & 0xff
			when 1 #char
				data_or_offset & 0xff
			when 2 #word
				data_or_offset & 0xffff
			when 3 #short
				[(data_or_offset & 0xffff)].pack("S").unpack("s")[0]
			when 4 #dword
				data_or_offset
			when 5 #int
				[data_or_offset].pack("I").unpack("i")[0]
			when 8 #float
				[data_or_offset].pack("V").unpack("f")[0]
			when 14 #struct
				read_struct data_or_offset
				# raise "substruct: #{str.inspect}"
				# read_struct 
			when 15 #list
				list = []

				raise GffError, "List index not divisable by 4" unless
					data_or_offset % 4 == 0

				data_or_offset /= 4
				
				raise GffError, "List index outside list indices" if
					data_or_offset > @list_indices.size

				count = @list_indices[data_or_offset]

				raise GffError, "List index overflow the list indices array" if
					data_or_offset + count > @list_indices.size

				data_or_offset += 1
				
				for i in data_or_offset...(data_or_offset + count)
					list << read_struct(@list_indices[i])
				end

				list
			else
				raise GffError, "Field data offset #{data_or_offset} outside of field data block" if
					data_or_offset > @field_data.size

				inner_value = case type
					when 6 #dword64
						len = 8
						v1, v2 = @field_data[data_or_offset, len].unpack("II")
						v1 * (2**32) + v2
					when 7 #int64
						len = 8
						@field_data[data_or_offset, len].unpack("q")[0]
					when 9 #double
						len = 8
						@field_data[data_or_offset, len].unpack("d")[0]
					when 10 #cexostring
						len = @field_data[data_or_offset, 4].unpack("V")[0]
						@field_data[data_or_offset + 1, len]
					when 11 #resref
						len = @field_data[data_or_offset, 1].unpack("C")[0]
						@field_data[data_or_offset + 1, len]
					when 12 #cexolocstring
						size, str_ref, str_count =
							@field_data[data_or_offset, 12].unpack("VVV")
						field['_str_ref'] = str_ref
						str = @field_data[data_or_offset + 12, size - 8].
							unpack("VV/a" * str_count)
						len = size + 4
						str
					when 13 #void
						len = @field_data[data_or_offset, 4].unpack("V")
						void = @field_data[data_or_offset + 4, len].unpack("H*")
						raise "void: #{void.inspect}"
				end

				raise GffError, "Field data overflows from the field data block area\
					offset = #{data_or_offset + len}, len = #{@field_data.size}" if
					data_or_offset + len > @field_data.size

				inner_value
		end
		field.merge! :type => type, :value => value

		[label, field]  #::Gff::Element.new(type,label,value)
	end
end
