#!/bin/sh
set -e


for in_yml in $@; do
	if [ -z "$in_yml" ]; then
		echo "Need a filename!"
		exit 1
	fi
	tmp=$1.gff

	echo "$in_yml -> $tmp -> $in_yml"

	echo '
		gem "nwn-lib", "0.3.6"
		require "nwn/gff"
		require "nwn/yaml"
		File.open("'$tmp'", "w") {|f|
			f.write NWN::Gff::Writer.dump(
				YAML.load(IO.read("'$in_yml'"))
			)
		}
	' | ruby -rubygems

	../bin/nwn-gff-convert -i "$tmp" -lg -ky -o "$in_yml"

	rm $tmp
done
