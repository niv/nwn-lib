if ENV['NWN_LIB_INFER_DATA_FILE'] && ENV['NWN_LIB_INFER_DATA_FILE'] != ""
  NWN::Gff.load_struct_defaults(ENV['NWN_LIB_INFER_DATA_FILE'])
end
