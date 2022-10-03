#!/bin/bash 

## dep
# apt install -y curl jq

## using the following variables
#
# SERVER_NAME=your_server_name
# SERVER_LOCATION=Country_code
# POWER_PUSH_GATEWAY="http://push-gateaway-url:port"
# POWER_DATA_URL (default value: https://raw.githubusercontent.com/Al3c5/toolbox/main/power/power.json)
#
# typical cron usage would be 
# */20 * * * * SERVER_NAME=my_server && SERVER_LOCATION=FR && POWER_PUSH_GATEWAY="http://my-monitoring-url:port" && /path/to/push_power.sh 

while :; do
    case $1 in
        -h|-\?|--help)
	    echo "export power  consumption metrics to a pushgateway instance (--help : help msg | --debug : only print exported values)"    # Display a usage synopsis.
            exit
            ;;
	--install)
	    curl -s -o $HOME/push_power.sh https://raw.githubusercontent.com/Al3c5/toolbox/main/power/push_power.sh
	    chmod +x  $HOME/push_power.sh 
	    sudo mv  $HOME/push_power.sh  /usr/local/bin 
	    sudo chown root:root /usr/local/bin/push_power.sh
	    read -p "Server name " SERVER_NAME 
	    read -p "Server location " SERVER_LOCATION
	    read -p "Prometheus push-gateway url" POWER_PUSH_GATEWAY
	    read -p "Cron schdeule (default: */20 * * * *)"  CRON_SCHEDULE
	    crontab -l | \
		{cat; echo "${CRON_SCHEDULE:-*/20 * * * *} SERVER_NAME=\"$SERVER_NAME\" && SERVER_LOCATION=\"$SERVER_LOCATION\" && POWER_PUSH_GATEWAY=\"$POWER_PUSH_GATEWAY\" && /usr/local/bin/push_power.sh;"} | \
	 	crontab - 
	    exit
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

instance="${SERVER_NAME:-$(hostname)}"

tmp_power_json=$(mktemp)
trap "rm $tmp_power_json" EXIT

curl -s -o $tmp_power_json ${POWER_DATA_URL:-https://raw.githubusercontent.com/Al3c5/toolbox/main/power/power.json}


power_tdp_watt=$(jq ".CPUs[]  | select(.model_name | inside(\"$(lscpu | grep 'Model name:' )\")) | \
	$(lscpu | grep 'CPU(s):' | head -1 | egrep -o '[0-9]{1,}') * \
	.TDP / .thread "  $tmp_power_json ) # CPUs x  cost per CPU
power_g_co2_per_k_watt_h=$(jq ".Countries[]  | select(.code==\"$SERVER_LOCATION\") .carbone_intensity "  $tmp_power_json)

tmp_metrics=$(mktemp)
trap "rm $tmp_metrics" EXIT

url_gw=$POWER_PUSH_GATEWAY/metrics/job/power/instance/$instance


cat <<EOF >> $tmp_metrics
# TYPE power_tdp_watt gauge
power_tdp_watt ${power_tdp_watt:-0}
# TYPE power_g_co2_per_k_watt_h gauge
power_g_co2_per_k_watt_h ${power_g_co2_per_k_watt_h:-0}
EOF

if [ $debug -eq 1 ]
	then
		echo "$url_gw"
		echo 
		cat $tmp_metrics
		exit
fi
cd "$( dirname "${BASH_SOURCE[0]}" )"

cat $tmp_metrics  | curl --insecure -s  --data-binary @- $url_gw

