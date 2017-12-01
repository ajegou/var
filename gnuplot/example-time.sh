inputs=$1;
output=$2

plot=""
plot+="load 'pngPlotStyle';"
plot+="set output '${output}';"
plot+="set timefmt '%H:%M:%S';"
plot+="set xdata time;"
plot+="set format x '%H:%M:%S';"
plot+="set xlabel 'Time' offset 0,0.5;"
plot+="plot "
for input in $inputs; do
	plot+=" '$input' u 1:2 t '$input',"
	plot+=" '$input' u 1:2 smooth uniq t '$input : average',"
done
plot+="1/0 notitle;"
gnuplot -e "$plot"
