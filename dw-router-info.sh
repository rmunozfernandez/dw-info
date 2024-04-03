#! /bin/bash

rangoIp=192.168.1.

timestamp=$(date +%s | awk 'BEGIN {ORS=""; print "\"timestamp\":"} {print (NR!=1 ? "," : "") "\"" $1 "\""} END {print ","}')
pinglocales=$(for i in $(seq 254); do ping -c1 -W1 192.168.1.$i & done | grep from | awk -F'[ =]' '{print $4, $10}' | sed 's/: / /' | awk 'BEGIN {ORS=""; print "\"local_ips\":["} {print (NR!=1 ? "," : "") "{\"ip\":\"" $1 "\",\"ping\":" $2 "}"} END {print "],"}')

echo $timestamp $pinglocales