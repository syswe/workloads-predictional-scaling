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
