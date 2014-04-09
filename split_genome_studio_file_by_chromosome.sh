#!/bin/bash

chromosomes=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X MT XY Y)

if [ -z $1 ]; then
  echo "Missing input file name"
  exit 1
fi



for chr in ${chromosomes[@]}
do
  newfile="${chr}_`basename $1`"
  echo "Splitting out for $chr from $1 into $newfile"
  # head -n 10 "$1" > "$newfile"
  cmd="awk -F '\t' '{if(NR>10 && \$3 == \"$chr\") print \$0}' \"${1}\" >> \"${newfile}\""
  # $cmd
  echo $cmd | sh
done