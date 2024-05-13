#!/bin/sh
increment=5
i=1
while [ $i -le 20 ]; do
	count=$(expr $i \* 5) # Using `expr` for arithmetic to ensure compatibility
	echo "Sending $count parallel requests..."
	j=1
	while [ $j -le $count ]; do
		timeout 60 wget -q -O- http://php-apache &
		j=$(expr $j + 1) # Using `expr` here as well
	done
	wait
	sleep $increment
	i=$(expr $i + 1)
done
