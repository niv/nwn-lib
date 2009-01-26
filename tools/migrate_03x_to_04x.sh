#!/bin/sh
# This script automages migrating <= 0.3.6-formatted YAML
# dumps to the current format.
# You need both versions of nwn-lib installed.
set -e

for in_yml in $@; do
	if [ ! -e "$in_yml" ]; then
		echo "$in_yml: does not exist"
		exit 1
	fi
	tmp=$1.gff

	echo -n "$in_yml: "
	( nwn-gff-import _0.3.6_ -y $in_yml | nwn-gff -lg -ky > $tmp ) && mv $tmp $in_yml
	echo "ok."
done
