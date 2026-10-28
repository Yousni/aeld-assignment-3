#!/bin/sh
# Author: yousni

filesdir=$1
searchstr=$2

if [ -z "$filesdir" ] || [ -z "$searchstr" ]; then
    echo "Missing argument !!"
    echo "Usage: $0 <arg1> <arg2>"
    echo "<arg1> is path to a directory on the filesystem"
    echo "<arg2> is a text string which will be searched within these files"
    exit 1
fi

if [ ! -d "$filesdir" ]; then
    echo "Directory does not exist"
    exit 1
fi



count_of_files=$(find "$filesdir" -type f | wc -l)
count_of_matching_lines=$(grep -r "$searchstr" "$filesdir" | wc -l)

echo "The number of files are $count_of_files and the number of matching lines are $count_of_matching_lines"

