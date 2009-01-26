#!/usr/bin/env nwn-dsl

# This FILTER walks all cexolocstrs and makes sure
# that there are no stray language-ids.
#
# This is obviously only useful for single-language projects.

want Gff::Struct

count = 0

self.each_by_flat_path do |label, field|
  next unless field.is_a?(Gff::Cexolocstr)
  next if field.v.size == 0

  compactable = field.v.values.reject {|x| x == ""}.uniq.size < 2

  unless will_output?
    unless compactable
      log "%s: need interactive." % [label]
      log "  %s" % [field.v.inspect]
    else
      log "%s: can fix for myself." % label
    end

  else
    str = nil
    unless compactable
      log "Cannot compact #{label}, because the contained strings are not unique."
      selection = ask "Use what string?", field.v
      log "Using: #{selection.inspect}"
      str = field.v[selection.to_i]
    else
      str = field.v[field.v.keys.sort[0]]
    end
    field.v.clear
    field.v[0] = str

    field.str_ref = Gff::Field::DEFAULT_STR_REF

    count += 1
  end

end

log "#{count} str-refs modified." if will_output?
