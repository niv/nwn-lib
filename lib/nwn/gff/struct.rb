# A Gff::Struct is a hash of label->Element pairs with some
# meta-information in local variables.
module NWN::Gff::Struct
  # The file-type this struct represents.
  # This is usually the file extension for root structs,
  # and nil for sub-structs.
  attr_accessor :type

  # The file version. Usually "V3.2" for root structs,
  # and nil for sub-structs.
  attr_accessor :version

  # GFF struct type
  attr_accessor :struct_id
end
