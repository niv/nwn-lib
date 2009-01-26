#!/bin/sh

cmp() {
	gffcmp.pl -d $1 $2 | \
		fgrep -v "File $2 do not match" | \
		egrep -v "^Number of items in localized string array .* differ, " | \
		egrep -v "^Localized string array .* differ, key .* missing$" | \
		egrep -v "^Key .* missing from" | \
		fgrep -v "Number of keys at level" | \
		fgrep -v "First gff has extra key"
}

tmp=/tmp/nwn-gff-tmp

for x in $@; do

	echo "| $x: test kivinen printer: y -> k | cmp" | ts
	nwn-gff -i$x -kk -t | gffencode.pl - -o $tmp
	cmp $x $tmp

	echo "| $x: test gff printer: y -> g | cmp" | ts
	nwn-gff -i$x -kg > $tmp
	cmp $x $tmp

	echo "| $x: test marshal re-read: m -> m -> k | cmp" | ts
	nwn-gff -i$x -km | nwn-gff -lm -kk -t | gffencode.pl - -o $tmp
	cmp $x $tmp

	echo "| $x: test yaml re-read: y -> y -> k | cmp" | ts
	nwn-gff -i$x -ky | nwn-gff -ly -ky | tee /tmp/blah | \
		nwn-gff -ly -kk -t | gffencode.pl - -o $tmp
	cmp $x $tmp
done

exit 0
