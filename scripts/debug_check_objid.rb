# This is a debug script used to verify anchored YAML dump loads.
# There was/is a bug in some earlier ruby YAML libs that would
# incorrectly anchor objects within large dumps; this prints out
# those duplicate object ids.

$obj_ids = {}

def chk path, obj
  if $obj_ids[obj.object_id] && $obj_ids[obj.object_id][1] == obj
    log "Duplicate object ID:"
    log "  #{path}"
    log "  #{$obj_ids[obj.object_id]}"
  else
    $obj_ids[obj.object_id] = [path, obj]
  end
end

self.each_by_flat_path do |path, obj|
  case obj
    when Gff::Field
      chk path + ".v", obj.v unless obj.v.is_a?(Numeric) || obj.v.is_a?(String)
      chk path + ".l", obj.l unless obj.l.is_a?(String)
      chk path, obj
    else
      chk path, obj
  end
end

log "#{$obj_ids.size} object ids verified."
