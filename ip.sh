#!/bin/bash

file_path="/shared/ifcfg-eth1"

previous_ip=$(grep 'IPADDR=' "$file_path" | awk -F= '{print $2}')

current_suffix=$(echo "$previous_ip" | awk -F'.' '{print $4}')

new_suffix=$((current_suffix + 1))

if [ "$new_suffix" -gt 253 ]; then
    new_suffix=10
fi

if [ "$new_suffix" -lt 10 ]; then
    new_suffix=10
fi

new_ip="10.10.10.$new_suffix"

new_content="DEVICE=\"eth1\"\nBOOTPROTO=\"none\"\nONBOOT=\"yes\"\nTYPE=\"Ethernet\"\nIPADDR=$new_ip\nPREFIX=24"

echo -e "$new_content" > "$file_path"

#echo "ifcfg-eth1 파일이 수정되었습니다. 새로운 IP 주소: $new_ip".
