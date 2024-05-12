#!/bin/bash

# Copyright 2022 The Predictive Horizontal Pod Autoscaler Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
