#!/bin/bash

fcomp(){
         com1=$(ssh compute1 "mpstat | grep all | gawk '{print \$4}'")
         com2=$(ssh compute2 "mpstat | grep all | gawk '{print \$4}'")
         echo "CPU USAGE: compute1=$com1, compute2=$com2"
 }

 fcheckvm() {
     echo "=========compute1========="
     ssh compute1 'virsh list --all'
     echo "=========compute2========="
     ssh compute2 'virsh list --all'
 }

 fdeletevm() {
     fcheckvm
     echo -n "select compute: "
     read compute
     echo -n "select delete vname: "
     read delvname
     status1=$(ssh $compute "virsh list --all | grep $delvname")
     status2=$(echo $status1 | gawk '{print $3}')
     if [ $status2 = "running" ]; then
         ssh $compute "virsh destroy $delvname"
     fi
     ssh $compute "virsh undefine $delvname --remove-all-storage"
     echo "delete finished"
     mysql Info -u info -pinfo <<EOF
 DELETE FROM instance_tbl WHERE instance_name = '$delvname';
 EOF

     read nnn
 }

 fmakevm() {
     echo
     fversion
     echo -n "enter vname: "
     read vname
     echo  "select option: "
     echo "1) m1.small(vcpu:1, ram:2048)"
     echo "2) m1.medium(vcpu:2, ram:2048)"
     echo "3) m1.large(vcpu:4, ram:4096)"
     fflavor
     echo -n "enter root password: "
     read -s rootpwd
     echo
     echo "========================"
     # 파일 경로 설정 (storage 노드의 /Raid01/ifcfg-eth1)
     file_path="/Raid01/ifcfg-eth1"

     # 현재 IP 주소 추출
     previous_ip=$(ssh storage "grep 'IPADDR=' \"$file_path\" | awk -F= '{print \$2}'")

     # 현재 IP 주소와 시작 IP 주소를 비교하여 뒷자리 수 추출
     current_suffix=$(echo "$previous_ip" | awk -F'.' '{print $4}')

     # 뒷자리 수를 1 증가
     new_suffix=$((current_suffix + 1))

     # 뒷자리 수가 253을 초과하면 10으로 초기화
     if [ "$new_suffix" -gt 253 ]; then
         new_suffix=10
     fi

      # 뒷자리 수가 10 미만이면 10으로 설정
     if [ "$new_suffix" -lt 10 ]; then
         new_suffix=10
     fi

     # 새로운 IP 주소 생성
     new_ip="10.10.10.$new_suffix"

     # 수정할 내용 생성
     new_content="DEVICE=\"eth1\"\nBOOTPROTO=\"none\"\nONBOOT=\"yes\"\nTYPE=\"Ethernet\"\nIPADDR=$new_ip\nPREFIX=24"

     # 파일 수정 (storage 노드에서 실행)
     ssh storage "echo -e \"$new_content\" > \"$file_path\""
     echo "ifcfg-eth1 파일이 수정되었습니다. 새로운 IP 주소: $new_ip"

     fcomp

     if [ "$version" = centos7 ]
         then
                 if [[ $com1 < $com2 ]] # com1 < com2
                 then # com1
                         ssh compute1 "cd /shared && cp  CentOS7.qcow2 $vname.qcow2 && virt-customize -a ${vname}.qcow2 --root-password password:$rootpwd --upload /shared/ifcfg-eth1:/etc    /sysconfig/network-scripts/ifcfg-eth1 --firstboot-command 'ifup eth1' && virt-install --name $vname --vcpus $vcpu --ram $ram --disk /shared/$vname.qcow2 --network=bridge:vswitch01,model    =virtio,virtualport_type=openvswitch --network=bridge:vswitch02,model=virtio,virtualport_type=openvswitch,target=${vname}_port1   --import --noautoconsole"
                         read nnn
                         var=$(ssh compute1 "virsh list --all | grep $vname | gawk '{print \$1}'")
                         instance_id=$((var))
                         if [[ $flavor = 1 ]]
                         then
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.small', 'compute1');
 EOF
                         elif [[ $flavoe = 2 ]]
                         then
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.medium', 'compute1');
 EOF
                         else
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.large', 'compute1');
 EOF
                         fi
                 else # com2
                         ssh compute2 "cd /shared && cp  CentOS7.qcow2 $vname.qcow2 && virt-customize -a ${vname}.qcow2 --root-password password:$rootpwd --upload /shared/ifcfg-eth1:/etc    /sysconfig/network-scripts/ifcfg-eth1 --firstboot-command 'ifup eth1' && virt-install --name $vname --vcpus $vcpu --ram $ram --disk /shared/$vname.qcow2 --network=bridge:vswitch01,model    =virtio,virtualport_type=openvswitch --network=bridge:vswitch02,model=virtio,virtualport_type=openvswitch,target=${vname}_port1   --import --noautoconsole"
                         read nnn
                         var=$(ssh compute1 "virsh list --all | grep $vname | gawk '{print \$1}'")
                         instance_id=$((var))
                         if [[ $flavor = 1 ]]
                         then
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.small', 'compute2');
 EOF
                         elif [[ $flavoe = 2 ]]
                         then
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.medium', 'compute2');
 EOF
                         else
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.large', 'compute2');
 EOF
                         fi
                 fi
         elif [ "$version" = centos8 ] ####### centos 8 change
         then
                 if [[ $com1 < $com2 ]] # com1 < com2
                 then # com1
                         ssh compute1 "cd /shared && cp  CentOS8.qcow2 $vname.qcow2 && virt-customize -a ${vname}.qcow2 --root-password password:$rootpwd --upload /shared/ifcfg-eth1:/etc    /sysconfig/network-scripts/ifcfg-eth1 --firstboot-command 'ifup eth1' && virt-install --name $vname --vcpus $vcpu --ram $ram --disk /shared/$vname.qcow2 --network=bridge:vswitch01,model    =virtio,virtualport_type=openvswitch --network=bridge:vswitch02,model=virtio,virtualport_type=openvswitch,target=${vname}_port1   --import --noautoconsole"
                         read nnn
                         var=$(ssh compute1 "virsh list --all | grep $vname | gawk '{print \$1}'")
                         instance_id=$((var))
                         if [[ $flavor = 1 ]]
                         then
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.small', 'compute1');
 EOF
                         elif [[ $flavoe = 2 ]]
                         then
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.medium', 'compute1');
 EOF
                         else
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.large', 'compute1');
 EOF
                         fi
                 else # com2
                         ssh compute2 "cd /shared && cp  CentOS8.qcow2 $vname.qcow2 && virt-customize -a ${vname}.qcow2 --root-password password:$rootpwd --upload /shared/ifcfg-eth1:/etc    /sysconfig/network-scripts/ifcfg-eth1 --firstboot-command 'ifup eth1' && virt-install --name $vname --vcpus $vcpu --ram $ram --disk /shared/$vname.qcow2 --network=bridge:vswitch01,model    =virtio,virtualport_type=openvswitch --network=bridge:vswitch02,model=virtio,virtualport_type=openvswitch,target=${vname}_port1   --import --noautoconsole"
                         read nnn
                         var=$(ssh compute1 "virsh list --all | grep $vname | gawk '{print \$1}'")
                         instance_id=$((var))
                         if [[ $flavor = 1 ]]
                         then
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.small', 'compute2');
 EOF
                         elif [[ $flavoe = 2 ]]
                         then
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.medium', 'compute2');
 EOF
                         else
                                 mysql Info -u info -pinfo <<EOF
 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.large', 'compute2');
 EOF
                         fi
                 fi
         fi
 }

 fversion() {
     echo -n "select version(centos7 or centos8): "
     read version
     if [ $version != centos7 ] && [ $version != centos8 ]; then
         echo "ERROR!!! enter version(centos7, centos8)"
         read nnn
         fversion
     fi
 }

 fflavor() {
     read flavor
     case $flavor in
         1) vcpu=1; ram=2048 ;;
         2) vcpu=2; ram=2048 ;;
         3) vcpu=4; ram=4096 ;;
         *) echo "select number in 1, 2, 3"; read nnn; fflavor ;;
     esac
 }

 fmigratevm() {
     fcheckvm
     echo -n "select source compute: "
     read source_compute
     echo -n "select target compute: "
     read target_compute
     echo -n "select migrate vm: "
     read migrate_vm

     # 라이브 마이그레이션 실행
     ssh $source_compute "virsh migrate --live --persistent --undefinesource $migrate_vm qemu+ssh://$target_compute/system"
     var=$(ssh $source_compute "virsh list --all | grep $migrate_vm | gawk '{print \$1}'")
     instance_id=$((var))


     if [[ $source_compute = "compute1" ]]; then
         target_compute="compute2"
     else
         target_compute="compute1"
     fi


     mysql Info -u info -pinfo <<EOF
 UPDATE instance_tbl SET location = '$target_compute' WHERE instance_name = '$migrate_vm';
 EOF



     # 마이그레이션 후 가상 머신 목록 출력
     echo "=========source compute========="
     ssh $source_compute 'virsh list --all'
     echo "=========target compute========="
     ssh $target_compute 'virsh list --all'
 }

 menu() {
     clear
     echo
     echo "====================================="
     echo -e "\t1) make virtual machine"
     echo -e "\t2) check virtual machine"
     echo -e "\t3) delete virtual machine"
     echo -e "\t4) migrate virtual machine"
     echo -e "\t0) Exit menu"
     echo "====================================="
     echo -en "\t\tEnter option: "
     read option
 }

 while [ 1 ]; do
     menu
     case $option in
         0)
             echo
             break ;;
         1)
             fmakevm ;;
         2)
             fcheckvm
             read nnn ;;
         3)
             fdeletevm ;;
         4)
             fmigratevm ;;
     esac
 done
