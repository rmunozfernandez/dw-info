#!/bin/ash

# Configuración
API="http://192.168.188.10:5342/api/test/router"
SEGMENTO_RED="192.168.188."
DOMINIOS="google.com facebook.com"
LIMITE_POST_MINUTO=30

# Eliminar el BSSID de las redes wifi conectadas
uci show wireless | grep wireless.@wifi | grep bssid | awk -F'=' '{system("uci delete " $1)}{system("uci commit wireless")}'

# Metodos
obtener_pings() {
  local dominio="$1"
  local resultado=$(ping -c 3 "$dominio" | grep "avg")
  local min=$(echo "$resultado" | awk '{print $4}' | awk -F'/' '{print $1}')
  local avg=$(echo "$resultado" | awk '{print $4}' | awk -F'/' '{print $2}')
  local max=$(echo "$resultado" | awk '{print $4}' | awk -F'/' '{print $3}')
  local min=$(comprobar_string_vacio "$min")
  local avg=$(comprobar_string_vacio "$avg")
  local max=$(comprobar_string_vacio "$max")
  echo "{\"mn\":$min,\"a\":$avg,\"mx\":$max}"
}

recorrer_dominios() {
  local DOMINIOS="$1"
  local longitud=$(echo $DOMINIOS | wc -w)
  local longitud=$((longitud+1))
  local i=1
  while [ $i -lt $longitud ]
  do
    local dominio=$(echo $DOMINIOS | cut -d' ' -f$i)
    local pings=$(obtener_pings "$dominio")
    echo "{\"d\":\"$dominio\",\"pi\":[$pings]}," | awk '{ORS=""}{print}' >> $archivo_ruta
    i=$((i+1))
  done
}

comprobar_string_vacio() {
  local string="$1"
  if [ -z "$string" ]
  then
    echo "null"
  else
    echo "\"$string\""
  fi
}

# Obtener la ruta de la memoria USB
ruta=$(df -h | grep mnt | awk '{print $6}')

# Si no se encuentra la memoria USB, se guarda en /tmp
if [ -z $ruta ]
then
  ruta=/tmp
fi

archivo_ruta=$ruta/router_info

# Crear archivo JSON
echo "{" | awk '{ORS=""}{print}' >> $archivo_ruta

# System timestamp
echo "\"ts\":\"$(date +%s)\"," | awk '{ORS=""}{print}' >> $archivo_ruta

# Router address
ip addr | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | awk 'BEGIN {ORS=""; print "\"rip\":["} {print (NR!=1 ? "," : "") "\"" $1 "\""} END {print "],"}' >> $archivo_ruta

# IPs Locales
ipLocales=$(for i in $(seq 254); do ping -c1 -W1 $SEGMENTO_RED$i & done | grep from | awk '{print $4}' | cut -d':' -f1 | awk 'BEGIN {ORS=" "} {print $1}')
echo "\"lpi\":[" | awk '{ORS=""}{print}' >> $archivo_ruta
recorrer_dominios "$ipLocales"
echo "]," | awk '{ORS=""}{print}' >> $archivo_ruta

# Pings dominios
echo "\"ipi\":[" | awk '{ORS=""}{print}' >> $archivo_ruta
recorrer_dominios "$DOMINIOS"
echo "]," | awk '{ORS=""}{print}' >> $archivo_ruta

# Finalizar JSON
echo "}" | awk '{print}' >> $archivo_ruta

# Enviar JSON al servidor
contador_peticiones=1

while IFS= read -r line && [ $contador_peticiones -le $LIMITE_POST_MINUTO ]
do
  curl -f -d "$line" -H "Content-Type: application/json" -X POST $API || exit 1
  sed -i '1d' "$archivo_ruta"
  contador_peticiones=$((contador_peticiones+1))
done < "$archivo_ruta"
