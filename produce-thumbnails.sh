cd $1
rm *-thumb.$2
for f in *.$2
do
	outfile="${f/\./-thumb.}"
	convert $f -resize "200^>" -gravity center -crop 200x200+0+0 -strip $outfile
done

