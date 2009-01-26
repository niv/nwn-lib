#!/usr/bin/env nwn-dsl

# The nwn toolset sometimes does weird things with facings;
# they flip signedness for no apparent reason.

# This script fixes that by forcing all facings to be unsigned.

want Gff::Struct

count = 0

self.each_by_flat_path do |label, field|
	next unless field.is_a?(Gff::Field)
	next unless field.field_type == :float
	next unless label =~ %r{\[\d+\]/(Facing|Bearing)$}
	if field.field_value < 0
		field.field_value = field.field_value.abs
		count += 1
	end
end

log "#{count} bearings modified."
