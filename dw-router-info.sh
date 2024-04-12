#!/bin/ash

obtener_pings() {
  local dominio="$1"
  local resultado=$(ping -c 3 "$dominio" | grep "avg")
  local min=$(echo "$resultado" | awk '{print $4}' | awk -F'/' '{print $1}')
  local avg=$(echo "$resultado" | awk '{print $4}' | awk -F'/' '{print $2}')
  local max=$(echo "$resultado" | awk '{print $4}' | awk -F'/' '{print $3}')
  echo "{\"mn\": $min, \"a\": $avg, \"mx\": $max}"
}

recorrer_dominios() {
  local dominios="$1"
  local longitud=$(echo $dominios | wc -w)
  local longitud=$((longitud+1))
  local i=1
  while [ $i -lt $longitud ]
  do
    local dominio=$(echo $dominios | cut -d' ' -f$i)
    local pings=$(obtener_pings "$dominio")
    echo "{\"d\": \"$dominio\", \"pi\": [$pings]}," | awk '{ORS=""}{print}' >> $ts.json
    i=$((i+1))
  done
}

ts=$(date +%s)
ts=result

# Crear archivo JSON
echo "{" | awk '{ORS=""}{print}' > $ts.json

# System timestamp
echo "\"ts\":\"$(date +%s)\"," | awk '{ORS=""}{print}' >> $ts.json

# Router address
ip addr | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | awk 'BEGIN {ORS=""; print "\"rip\":["} {print (NR!=1 ? "," : "") "\"" $1 "\""} END {print "],"}' >> $ts.json

#region IPs Locales
ipLocales=$(for i in $(seq 254); do ping -c1 -W1 7.7.7.$i & done | grep from | awk '{print $4}' | cut -d':' -f1 | awk 'BEGIN {ORS=" "} {print $1}')
echo "\"lpi\": [" | awk '{ORS=""}{print}' >> $ts.json
recorrer_dominios "$ipLocales"
echo "]," | awk '{ORS=""}{print}' >> $ts.json
#endregion

#region Pings dominios
dominios="google.com facebook.com"
echo "\"ipi\": [" | awk '{ORS=""}{print}' >> $ts.json
recorrer_dominios "$dominios"
echo "]," | awk '{ORS=""}{print}' >> $ts.json
#endregion

#region Finalizar JSON
echo "}" | awk '{ORS=""}{print}' >> $ts.json
#endregion

# Eliminar el BSSID de las redes wifi conectadas
uci show wireless | grep wireless.@wifi | grep bssid | awk -F'=' '{system("uci delete " $1)}{system("uci commit wireless")}'
