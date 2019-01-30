#!/bin/bash
# Usage:
#   curl https://raw.githubusercontent.com/linhua55/lkl_study/master/get-rinetd.sh | bash

export BBR_URL="https://raw.githubusercontent.com/tozy1203/rinetd-bbr/master/rinetd_bbr"
export BBRP_URL="https://raw.githubusercontent.com/tozy1203/rinetd-bbr/master/rinetd_bbr_powered"
export PCC_URL="https://raw.githubusercontent.com/tozy1203/rinetd-bbr/master/rinetd_pcc"

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Please run as root"
    exit 1
fi

for CMD in curl iptables grep cut xargs systemctl ip awk
do
	if ! type -p ${CMD}; then
		echo -e "\e[1;31mtool ${CMD} is not installed, abort.\e[0m"
		exit 1
	fi
done

read -p "1. Select bbr version[1BBR,2PCC,3BBRP]: " SELECT </dev/tty
read -p "2. Input ports you want to speed up: " PORTS </dev/tty

echo -e "3. Clean up rinetd-bbr"
systemctl disable rinetd-bbr.service
killall -9 rinetd-bbr
rm -rf /usr/bin/rinetd-bbr /etc/systemd/system/rinetd-bbr.service

echo "4. Download rinetd-bbr from $RINET_URL"
curl -L "${RINET_URL}" >/usr/bin/rinetd-bbr
chmod +x /usr/bin/rinetd-bbr

case $SELECT in
1)
RINET_URL=$BBR_URL
;;
2) 
RINET_URL=$PCC_URL
;;
3) 
RINET_URL=$BBRP_URL
;;
*)
RINET_URL=$BBR_URL
esac

for d in $PORTS
do          
cat <<EOF >> /etc/rinetd-bbr.conf
0.0.0.0 $d 0.0.0.0 $d 
EOF
done 

IFACE=$(ip -4 addr | awk '{if ($1 ~ /inet/ && $NF ~ /^[ve]/) {a=$NF}} END{print a}')

echo "5. Generate /etc/systemd/system/rinetd-bbr.service"
cat <<EOF > /etc/systemd/system/rinetd-bbr.service
[Unit]
Description=rinetd with bbr
Documentation=https://github.com/linhua55/lkl_study

[Service]
ExecStart=/usr/bin/rinetd-bbr -f -c /etc/rinetd-bbr.conf raw ${IFACE}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "6. Enable rinetd-bbr Service"
systemctl enable rinetd-bbr.service

echo "7. Start rinetd-bbr Service"
systemctl start rinetd-bbr.service

if systemctl status rinetd-bbr >/dev/null; then
	echo "rinetd-bbr started."
	echo "$PORTS speed up completed."
	echo "vi /etc/rinetd-bbr.conf as needed."
	echo "killall -9 rinetd-bbr for restart."
else
	echo "rinetd-bbr failed."
fi
