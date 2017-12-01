inputFile="./clustering.std"
tempFile="/tmp/clustering.tmp"
datFile="./clustering"
plotFile="./clustering.png"


if [[ "$1" != "skip" ]]; then


egrep 'Clustering network|Iteration ' $inputFile > $tempFile

declare -A colors
incr=0

while read line; do
	if [[ $line =~ "Clustering network" ]]; then
		network=$(echo $line | sed 's;.*Clustering network ;;' | sed 's; with.*;;')
		if [[ "${colors[$network]}" == "" ]]; then
			echo "Unknown network $network"
			colors[$network]=$incr
			incr=$(($incr + 1))
			> $datFile-$network.dat
		fi
		color=${colors[$network]}
	else
		date=$(echo "$line" | sed -e 's;,.*;;')
		iteration=$(echo "$line" | sed -e 's;.*Iteration ;;' -e 's;,.*;;')
		users=$(echo "$line" | sed -e 's;.*, ;;' -e 's; users.*;;')
		time=$(echo "$line" | sed -e 's;.*Done in ;;' -e 's; |.*;;')
		variations=$(echo "$line" | sed -e 's;.*| ;;' -e 's; variation.*;;')
		echo -e "$date\t$network\t$color\t$iteration\t$users\t$time\t$variations" >> $datFile-$network.dat
	fi
done < $tempFile

fi

for datafile in ./$datFile*.dat; do

	if [[ "$(cat $datafile)" != "" ]]; then
toplot=""
toplot+="set terminal png size 2000,1000;"
toplot+="set output '$datafile.png';"
toplot+="set timefmt '%Y-%m-%d %H:%M:%S';"
toplot+="set xdata time;"
toplot+="set xlabel 'Time';"
toplot+="set y2tics;"
toplot+="set datafile separator '\t';"
toplot+="plot '$datafile' u 1:4 lc 3 title 'Iteration',"
toplot+="'' u 1:7 lc 4 axes x1y2 title 'Nb changes';"

gnuplot -e "$toplot";
fi
done
