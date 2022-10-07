#!/bin/bash

echo "[!] Welcome to the Wireguard config file generation made by Mgh"

read -p "[-] Wireguard Interface Name [wg0]: " wg_name
read -p "[-] Openvpn Interface Name [tun0]: " ov_name

[ -z "$wg_name" ] && wg_name="wg0"
[ -z "$ov_name" ] && ov_name="tun0"

config_name="${wg_name}.conf"

echo "[!] You should do the following before running 'wg-quick up $wg_name'"
echo "  [!] echo 200 vpn >> /etc/iproute2/rt_tables"
echo "  [!] ip -4 rule add pref 1000 iif $ov_name lookup vpn"
echo "  [!] ip -6 rule add pref 1000 iif $ov_name lookup vpn"

read -p "[-] Your Private Key [wg genkey]: " prv_key

[ -z "$prv_key" ] && prv_key="$(wg genkey)"

pub_key="$(wg pubkey <<<$prv_key)"

read -p "[-] Your Address [192.168.1.0/24]: " addr

[ -z "$addr" ] && addr="192.168.1.0/24"

echo "[+] Creating config file"
echo "[+] Adding Interface"

cat >$config_name <<_EOF
[Interface]
PrivateKey = $prv_key
Address = $addr
DNS = 8.8.8.8, 8.8.4.4, 1.1.1.1, 1.0.0.1
Table=vpn
PostUp=ufw route allow in on $wg_name out on $ov_name
PostUp=iptables -t nat -A POSTROUTING -o $wg_name  -j MASQUERADE
PostUp=iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostUp=iptables -A FORWARD -i $ov_name -o $wg_name -j ACCEPT
PostUp=iptables -A FORWARD -i $wg_name  -o $ov_name -j ACCEPT
PostDown=iptables -t nat -D POSTROUTING -o $wg_name  -j MASQUERADE
PostDown=iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostDown=iptables -D FORWARD -i $ov_name -o $wg_name -j ACCEPT
PostDown=iptables -D FORWARD -i $wg_name  -o $ov_name -j ACCEPT
PostDown=ufw route delete allow in on $wg_name out on $ov_name
_EOF

read -p "[-] Number of Peers [1]: " num_peers

[ -z "$num_peers" ] && num_peers=1

cur_peer=1

while [ $cur_peer -le $num_peers ]; do

    read -p "[-] Peer Public Key: " peer_pub_key

    if [ -z "$peer_pub_key" ]; then
        echo "[!] Peer Public Key is required"
        continue
    fi

    read -p "[-] Peer Endpoint: " peer_endpoint

    if [ -z "$peer_endpoint" ]; then
        echo "[!] Peer Endpoint is required"
        continue
    fi

    echo "[+] Adding new Peer"

    cat <<EOT >>$config_name

[Peer]
PublicKey = $peer_pub_key
Endpoint =  $peer_endpoint
AllowedIPs = 0.0.0.0/0
AllowedIPs = 10.8.0.0/24
EOT

    ((cur_peer++))

done

echo "[+] Your Public Key is $pub_key"
