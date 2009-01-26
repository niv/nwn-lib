#!/usr/bin/env nwn-dsl

# This script will extract all items the worked-on
# struct is currently in possession of.
o = need ARGV.shift, :bic, :utc, :uti

log "Extracting .."
list = []
list += o['Equip_ItemList'].field_value if o['Equip_ItemList']
list += o['ItemList'].field_value if o['ItemList']
log "#{list.size} items found."
list.each_with_index {|item, index|
  File.open(fname = "item_#{index}.uti", "w") {|file|
    file.write item.to_gff("UTI")
    log "Written item: #{item['Tag'].field_value} as #{fname}"
  }
}

log "All done."
