#!/bin/bash

# Scriptname
# Scriptname kann geändert werden; Prüfung ob bereits gestartet funktioniert dennoch
script="${0##*/}"
# Prüfen ob das Script schon ausgeführt wird, lässt einen weiteren start nicht zu
# für Benutzung als Cronjob 
for pid in $(pidof -x $script); do
    if [ $pid != $$ ]; then
        echo "[$(date)] : $script : Process is already running with PID $pid"
        exit 1
    fi
done


# Julian
# 24.07.2017
# Comment:
# Script läuft nach dem Start des RPI und Dauerschleife
# wenn beide G-tags 15 Schleifendurchläufe nicht erkannt werden
# wird auf Status Abwesend gesetzt

# -------------------------
# Einstellungen (edit here)
# -------------------------
away=15 	# nach wieviel Durchläufen Status "abwesend"?
gtags=("7C:2F:80:90:22:22" "7C:2F:80:90:33:55")	# G-tags mac Adresses

homeeip="192.168.178.5"
homeeport="7681"
webhooks_key="AAAAAAAAAAAAABBBBBBBBBBCCCCCCCCCCCCCCCCDDDDDDDDDDDDDDDDDDEEEEEEEE"

# ----------------------
# do not edit below here 
# ----------------------
# Startverzögerung
echo "G-tag Scanner for homee"
echo ""
i=5
while [ $i -gt 0 ]; do
	sleep 1
	echo "starts in "$i
	i=$[$i-1]
done

ncounter=1
daheim=0

# Whitelist clear
sudo hcitool lewlclr
# G-tags zur Whitelist
echo "Gültige G-tags"
for i in ${gtags[@]}; do
	echo "$i"
	sudo hcitool lewladd "$i"
	if [ $? -eq 1 ]; then
		echo "Bluetooth error; not installed?"
		exit
	fi
done
echo ""

while true; do
    sudo hcitool lescan --whitelist > scan.txt & sleep 2 && sudo pkill --signal SIGINT hcito   
    NUMOFLINES=$(wc -l < "scan.txt")
    if [ "$NUMOFLINES" -gt "1" ]; then
		# Anwesend
		if [ "$daheim" -eq 0 ]; then
			echo "Status: anwesend"	
			curl "http://$homeeip:$homeeport/api/v2/webhook_trigger?webhooks_key=$webhooks_key&event=anwesend"	
			daheim=1
		fi
		ncounter=1
    else
		# Abwesend
		if [ "$ncounter" -lt "$away" ]; then
			echo "Counter Abwesend: " $ncounter
		fi
		
		if [ "$ncounter" == "$away" ]; then
			echo "Status: abwesend"
			curl "http://$homeeip:$homeeport/api/v2/webhook_trigger?webhooks_key=$webhooks_key&event=abwesend"
			daheim=0
		fi
		ncounter=$[ncounter+ 1]
    fi
    sleep 1
done
