#!/bin/sh
increment=1            # 1 dakika bekleme süresi.
total_duration=10      # Toplam test süresi 10 dakika.
start_time=$(date +%s) # Başlangıç zamanını kaydet.

# Dinamik yük artışı ve azalışı simülasyonu
i=0
while true; do
	# Geçen süreyi hesapla
	current_time=$(date +%s)
	elapsed=$(((current_time - start_time) / 60)) # Dakika cinsinden geçen süre

	if [ $elapsed -ge $total_duration ]; then
		echo "Test süresi doldu: Toplam süre ${elapsed} dakika."
		break
	fi

	# Yük hesaplaması: Testin başında ve sonunda yüksek, ortada düşük
	if [ $elapsed -lt 3 ]; then
		count=40 # İlk 3 dakikada yüksek yük
	elif [ $elapsed -lt 7 ]; then
		count=10 # 4 dakika boyunca yükü düşük tut
	else
		count=40 # Son 3 dakikada yüksek yük
	fi

	echo "${elapsed} dakika: Gönderilen paralel istek sayısı: $count"
	j=1
	while [ $j -le $count ]; do
		timeout 60 wget -q -O- http://php-apache &
		j=$(expr $j + 1)
	done
	wait
	sleep $increment
done
