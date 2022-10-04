#!/bin/bash 

## dep
# apt install -y curl jq

## using the following variables
#
# SERVER_NAME=your_server_name (default hostname)
# SERVER_LOCATION=Country_code (mandatory no default)
# POWER_PUSH_GATEWAY="http://push-gateaway-url:port" (mandatory no default)
# POWER_DATA_URL (default value: https://raw.githubusercontent.com/Al3c5/toolbox/main/power/power.json, usage file:///path/to/your/own/file)
#
# typical cron usage would be 
# */20 * * * * SERVER_NAME=my_server && SERVER_LOCATION=FR && POWER_PUSH_GATEWAY="http://my-monitoring-url:port" && /path/to/push_power.sh 

while :; do
    case $1 in
        -h|-\?|--help)
	    echo "export power  consumption metrics to a pushgateway instance "
	    echo "	--help : help msg "
	    echo "	--debug : only print exported value"
	    echo "	--install : installer for a cron task"
            exit
            ;;
	--install)
	    install="1"
	    break
	    ;;
        --debug)
            debug="1"
            break
            ;;
	-?*)
            echo 'Error: Unknown option (aborded): %s\n' "$1" >&2
	    exit 
            ;;
        *)              
            break
	    ;;
esac
done

install () {
        read -p "Server location " SERVER_LOCATION
        read -p "Prometheus push-gateway url" POWER_PUSH_GATEWAY
        { crontab -l 2>/dev/null ; echo "${CRON_SCHEDULE:-*/15 * * * *}  export SERVER_LOCATION=\"$SERVER_LOCATION\" ; export POWER_PUSH_GATEWAY=\"$POWER_PUSH_GATEWAY\" ; /usr/local/bin/push_power.sh";} | crontab -
	exit 1
}


if [[ "$install" == "1" ]]; then 
	install
	exit 1 
fi

instance="${SERVER_NAME:-$(hostname)}"

tmp_power_json=$(mktemp)
trap "rm $tmp_power_json" EXIT

curl -H 'Cache-Control: no-cache, no-store' -s -o $tmp_power_json ${POWER_DATA_URL:-"https://raw.githubusercontent.com/Al3c5/toolbox/master/power/power.json"}


power_tdp_watt=$(jq ".CPUs[]  | select(.model_name | inside(\"$(lscpu | grep 'Model name:' )\")) | \
	$(lscpu | grep 'CPU(s):' | head -1 | egrep -o '[0-9]{1,}') * \
	.TDP / .thread "  $tmp_power_json ) # CPUs x  cost per CPU
power_g_co2_per_k_watt_h=$( jq ".Countries[]  | select(.code==\"$SERVER_LOCATION\") .carbone_intensity "   $tmp_power_json )

tmp_metrics=$(mktemp)
trap "rm $tmp_metrics" EXIT

url_gw=$POWER_PUSH_GATEWAY/metrics/job/power/instance/$instance


cat <<EOF >> $tmp_metrics
# TYPE power_tdp_watt gauge
power_tdp_watt ${power_tdp_watt:-0}
# TYPE power_g_co2_per_k_watt_h gauge
power_g_co2_per_k_watt_h ${power_g_co2_per_k_watt_h:-0}
EOF

if [[ $debug -eq 1 ]];
	then
		echo "Power.json file"
		jq .  $tmp_power_json
		echo "URL : $url_gw"
		echo 
		cat $tmp_metrics
		exit
fi
cd "$( dirname "${BASH_SOURCE[0]}" )"

cat $tmp_metrics  | curl --insecure -s  --data-binary @- $url_gw

