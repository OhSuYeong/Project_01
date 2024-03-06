## 프로젝트 소개

- **NAT(Network Address Translation)와 VMnet1 활용:**
    - NAT(Network Address Translation)와 VMnet1을 사용하여 노드들이 외부 네트워크와 통신하도록 구성합니다. NAT는 인터넷과 내부 네트워크 간의 통신을 위해 사용될 것이고, VMnet1은 노드들 간의 가상 네트워크를 형성할 것입니다.

### **노드 구성:**

### 1. control 노드:

- **리소스:** cpu2/ram2, minimal install
- **기능:**
    - script를 작성하여 compute1, compute2에 인스턴스 배포
    - MariaDB를 설치하여 인스턴스 생성 정보, 노드 정보 등을 테이블에 저장
    - 인스턴스 배포 시 compute1, compute2의 CPU 사용량을 확인하여 적은 쪽에 배치
    - SSH를 통해 명령 전달하고 명령 전달 시 패스워드 물어보지 않도록 구성
    - Zabbix를 설치하여 각 노드의 메트릭, 디스크 정보 등을 웹을 통해 확인 가능하도록 구성
    - Zabbix 에이전트를 노드에 설치하여 데이터 수집
    - Grafana와 Zabbix 연동 시도

### 2. storage 노드:

- **리소스:** cpu1/ram1, minimal install
- **기능:**
    - NFS 서버로 외부에 특정 디렉토리를 제공
    - 디스크의 용량은 여유 있게 구성
    - RAID1을 통해 FT 구성 (두 개의 디스크를 연결하여 하나의 논리 디스크를 만들고 한쪽이 이상이 없도록 구성)

### 3. backup 노드:

- **리소스:** cpu1/ram1, minimal install
- **기능:**
    - MariaDB 설치하여 control 노드에 있는 DB의 내용과 동일하게 작성하여 동기화
    - DB Replication을 사용하여 변경된 데이터 자동 동기화

### 4. compute1/compute2 노드:

- **리소스:** cpu4/ram4, server with gui (run level 3)
- **기능:**
    - OVS를 사용하고 터널링을 구현하여 인스턴스를 배포
    - VLAN(tag)을 구성하지 않고 라이브 마이그레이션 가능하도록 구성
    - OpenStack에서 제공하는 클라우드 이미지 (CentOS 7, 8)를 이용
    - Virt-resize나 Virt-builder를 사용하여 디스크 크기를 늘리지 않음
    - 생성된 인스턴스는 vswitch01(211.183.3.0/24), vswitch02(임의의 사설 주소)에 모두 연결되며, vswitch02 간 터널링이 구현되어 사설 주소가 통신 가능하도록 함
    - 생성된 인스턴스는 Public key와 root 패스워드를 함께 제공 (211.183.3.0/24는 DHCP를 통해 자동 할당, vswitch02는 임의의 주소를 정적으로 할당)

### **주의사항 및 추가 구성:**

1. virbr0(192.168.122.0/24)에 연결된 인스턴스의 경우 virsh domifaddr centos1로 IP 정보 확인 가능
2. 데이터 백업은 S3 등을 활용하여 구성
3. 다양한 모니터링 도구를 추가할 경우, HAProxy 등을 사용하여 관리 가능
4. 프로젝트를 협업하여 진행할 경우, 버전 관리 시스템(Git 등)을 사용하여 협업 및 변경 이력 관리
5. 프로젝트 완성 후 파일을 업로드할 때 '비밀글 기능'을 체크하여 업로드
6. 테스트 및 피드백을 통해 시스템의 안정성 및 신뢰성 검증

## 클라우드 아키텍처

![아키텍처_240108_144448_2](https://github.com/OhSuYeong/Project_01/assets/101083171/e4eee842-b0c4-4e75-8644-06b16ffa04b0)


---

## 1. VMware 설치

| 이름 | 공인 ip | 내부 ip | 설치 모드 | cpu/ram | disk |
| --- | --- | --- | --- | --- | --- |
| control | 211.183.3.100 | 192.168.1.100 | minimal install | 2/2 | 20 |
| compute1 | 211.183.3.101 | 192.168.1.101 | server with GUI | 4/4 | 20 |
| compute2 | 211.183.3.102 | 192.168.1.102 | server with GUI | 4/4 | 20 |
| storage | 211.183.3.99 | 192.168.1.99 | minimal install | 1/1 | 80 |
| backup | 211.183.3.98 | 192.168.1.98 | minimal install | 1/1 | 20 |
|  | DG:211.183.3.2
DNS:8.8.8.8 | DG: -
DNS: - |  |  |  |

계정 : root/test123, user1/user1(관리자로 전환 가능하도록 해야 함)

storage 는 반드시 수동 파티셔닝 한다 → RAID를 위해 아래 확인 필요

- SWAP : 4 GB
- /boot : 1GB
- / : 15GB
- /cloud : 나머지 전부 ← /cloud 만들어야 함

# /etc/hosts 변경 후 각 노드 간 통신 상태 확인하기(backend)

```bash
for node in storage control compute1 compute2; do ping -c 3 $node ; done
```

# 각 노드 업데이트와 필요한 기본 패키지 설치하기

```bash
dnf update -y && dnf -y install net-tools vim curl wget git psmisc && echo “==========finished==========”
```

# user1 사용자는 각 노드에서 sudo 명령어를 사용하여 일시적으로 루트의 권한으로 특정 명령어 사용이 가능해야 한다. 단, 이 경우 자신의 패스워드를 입력하는 일은 없어야 한다 => /etc/sudoers 파일에 기록

아래의 내용을 /etc/sudoers 파일의 111번째 줄 정도에 추가

```bash
user1           ALL=(ALL)       NOPASSWD: ALL
```

# root, user1 은 vi 를 실행하면 자동으로 vim 이 실행되어야 한다.  => ~/.bashrc

```bash
echo "alias vi='vim'" >> /root/.bashrc
```

```bash
echo "alias vi='vim'" >> /home/user1/.bashrc
```

---

**[Storage]**

**1. raid 구성**

setting에서 먼저 hard disk를 2개 추가한다.

lsblk 명령어로 추가된 디스크를 확인

fdisk /dev/sd~ 디스크 2개를 모두 설정할 것

Command (m for help): n
Partition type:
p   primary (0 primary, 0 extended, 4 free)
e   extended
Select (default p): enter
Using default response p
Partition number (1-4, default 1): enter
First sector (2048-2097151, default 2048): enter
Using default value 2048
Last sector, +sectors or +size{K,M,G} (2048-2097151, default 2097151): enter
Using default value 2097151
Partition 1 of type Linux and of size 1023 MiB is set

Command (m for help): t
Selected partition 1
Hex code (type L to list all codes): fd
Changed type of partition 'Linux' to 'Linux raid autodetect'

Command (m for help): p -> id와 System이 fd와 Linux raid autodetect'로 바뀌었는지 확인할 것

```bash
dnf install -y mdadm
```

```bash
mdadm --create /dev/md9 --level=1 --raid-devices=2 /dev/sdb /dev/sdc #->뒤의 볼륨은 개인마다 다를 수 있다.
```

**2. 생성 시 조회 하는 법**

```bash
mdadm --detail /dev/md9
mkfs.ext4 /dev/md9
```

```bash
mkdir /Raid01
mount /dev/md9 /Raid01
```

```bash
vi /etc/fstab
/dev/md9        /Raid01 ext4     defaults        0 0
```

---

## 2. NFS 서버 구성

**[Storage]**

```bash
dnf -y install epel-release nfs-utils
systemctl status nfs-server
sudo systemctl start nfs-server
sudo systemctl enable nfs-server
```

```bash
mkdir /shared/
chmod 777 /shared/
```

vi /etc/exports에서 작성

```bash
/Raid01 compute*(rw,sync,no_root_squash)
```

```bash
sudo systemctl restart nfs-server
```

/cloud가 아닌 /Raid01을 공유 폴더로 지정

```bash
[root@storage /]# vi /etc/exports
/Raid01          compute*(rw,sync,no_root_squash)
```

```bash
chmod 777 /Raid01
```

**[연결할 노드(compute*)에 작성]**

```bash
[root@compute1 /]# mount -t nfs storage:/Raid01 /shared
[root@compute1 /]# ls
bin boot dev etc home lib lib64 media mnt opt proc root run sbin shared srv sys tmp usr var
[root@compute1 /]# cd shared/
[root@compute1 shared]# ls
lost+found
```

vi /etc/fstab에 공유 폴더 지정

```bash
storage:/Raid01          /Myshare           nfs      defaults        0 0
```

/cloud가 아닌 /Raid01을 공유폴더로 지정

```bash
[root@storage /]# vi /etc/exports
/Raid01          compute*(rw,sync,no_root_squash)
```

```bash
chmod 777 /Raid01
```

```bash
[root@compute1 /]# mount -t nfs storage:/Raid01 /shared
[root@compute1 /]# ls
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  shared  srv  sys  tmp  usr  var
[root@compute1 /]# cd shared/
[root@compute1 shared]# ls
lost+found
```

---

## 3. Mariadb 설치

- control과 backup에 Mariadb 설치

```bash
dnf -y update
dnf -y install mariadb
rpm -qa mariadb
```

---

## 4. NFS 서버로 storage와 compute1,2 mount 시키기

- 방화벽은 모두 해제. 재부팅 이후에도 비활성화 되어야 한다.

```bash
systemctl stop firewalld && systemctl disable firewalld
```

- SELinux 도 종료해 둔다. 재부팅 이후에도 비활성화 되어야 한다.

```bash
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

- 시스템에 설치된 장치의 상태 확인

```bash
nmcli device status
```

- nfs 서버 동작을 위한 tool 설치

```bash
dnf -y install nfs-utils
```

**[storage]**

```bash
[root@storage ~]# chmod 777 /cloud
[root@storage ~]# vi /etc/exports
/cloud          compute*(rw,sync,no_root_squash)
[root@storage ~]# systemctl enable nfs-server --now
[root@storage ~]# systemctl restart nfs-server #nfs 서버 restart
```

**[compute1, 2]**

```bash
[root@compute1 ~]# showmount -e storage
Export list for storage:
/cloud compute*
[root@compute1 ~]# mount -t nfs storage:/cloud /shared #mount 시키기
[root@compute1 ~]# mount | grep /shared #mount 확인
```

/etc/fstab 파일 수정

```bash
[root@compute1 ~]# tail -1 /etc/fstab
storage:/cloud          /shared           nfs      defaults        0 0
```

---

## 5. KVM 동작을 위한 compute 노드 설정(compute1/compute2)

```bash
dnf -y install qemu-kvm libvirt virt-manager virt-viewer openssh-askpass virt-install libguestfs-tools
```

vi /etc/libvirt/qemu.conf  이후 519행 쯤에 가서 가장 앞에 있는 주석(#) 제거, 523 행 가장 앞의 주석도 제거한다.

```bash
user=”root”
group = "root"
```

마지막으로 kvm 을 실행/활성화 한다.

systemctl enable libvirtd --now

- 이미지 다운로드 /cloud

```bash
[root@storage Raid01]# wget https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-2003.qcow2.xz

[root@storage Raid01]# xz -d CentOS-7-x86_64-GenericCloud-2003.qcow2.xz

[root@storage Raid01]# mv CentOS-7-x86_64-GenericCloud-2003.qcow2 CentOS7.qcow2

[root@storage Raid01]# wget https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.1.1911-20200113.3.x86_64.qcow2

[root@storage Raid01]# mv CentOS-8-GenericCloud-8.1.1911-20200113.3.x86_64.qcow2 CentOS8.qcow2
```

- control 에서 storage, compute 노드를 모두 제어
    - control 노드
        
        ```bash
        [root@control ~]# ssh-keygen -q -N "" -f control.pem
        
        [root@control ~]# mkdir .ssh ; chmod 700 .ssh
        
        [root@control ~]# touch .ssh/known_hosts
        
        [root@control ~]# ssh-keyscan 192.168.1.99 >> .ssh/known_hosts
        
        [root@control ~]# ssh-keyscan 192.168.1.98 >> .ssh/known_hosts
        
        [root@control ~]# ssh-keyscan 192.168.1.101 >> .ssh/known_hosts
        
        [root@control ~]# ssh-keyscan 192.168.1.102 >> .ssh/known_hosts
        ```
        
    - 나머지 노드
        
        ```bash
        [root@compute1 ~]$ mkdir .ssh ; chmod 700 .ssh
        
        [root@compute1 ~]$ touch .ssh/authorized_keys
        
        [root@compute1 ~]$ chmod 644 .ssh/authorized_keys
        
        [root@compute1 ~]$ vi .ssh/authorized_keys   # control 의 pub 키를 저장시킨다
        ```
        
    - control 의 /home/user1/.ssh/config 에 클라이언트 설정을 작성
    
    ```bash
    [root@control ~]$ touch .ssh/config
    
    [root@control ~]$ chmod 644 .ssh/config
    
    [root@control ~]$ vi .ssh/config
    
    Host storage
    HostName 192.168.1.99
    User root
    IdentityFile ~/control.pem
    
    Host compute1
    HostName 192.168.1.101
    User root
    IdentityFile ~/control.pem
    
    Host compute2
    HostName 192.168.1.102
    User root
    IdentityFile ~/control.pem
    
    Host backup
    HostName 192.168.1.98
    User root
    IdentityFile ~/control.pem
    ```
    
    - 접속 확인
        
        ```bash
        [root@control ~]$ ssh storage 'sudo ls /cloud | head -2'
        
        a.txt
        
        centos1.qcow2
        
        [root@control ~]$ ssh compute1 'sudo virsh list --all'
        
        Id   Name      State
        
        -------------------------
        
        -    centos1   shut off
        
        [root@control ~]$ ssh compute2 'sudo virsh list --all'
        
        Id   Name   State
        
        -------------------
        
        [root@control ~]$
        ```
        

---

## 6. CentOS8 에서 OpenVswitch(ovs) 설치 및 환경 설정 (compute1,2)

```bash
dnf install -y https://repos.fedorapeople.org/repos/openstack/openstack-yoga/rdo-release-yoga-1.el8.noarch.rpm

yum install openvswitch libibverbs -y

dnf update -y openvswitch libibverbs

systemctl enable openvswitch --now

systemctl status openvswitch
```

**[최종확인]**

```bash
[root@compute1 ~]# ovs-vsctl show

9ad4f087-78ba-4350-9df1-51e88801e960

ovs_version: "3.1.4"
```

<aside>
💡 run level 낮추기:systemctl set-default multi-user.target
reboot

</aside>

- ovs 기반의 bridge, port 조정 (compute1,2)
    
    ```bash
    [root@compute1 ~]# cd /etc/sysconfig/network-scripts/
    
    [root@compute1 network-scripts]# ls ifcfg-*
    
    ifcfg-ens160 ifcfg-ens224 ifcfg-lo
    
    [root@compute1 network-scripts]# cp ifcfg-ens160 ifcfg-vswitch01
    
    [root@compute1 network-scripts]# vi ifcfg-vswitch01
    
    TYPE=OVSBridge
    
    BOOTPROTO=none
    
    NAME=vswitch01
    
    DEVICE=vswitch01
    
    DEVICETYPE=ovs
    
    ONBOOT=yes
    
    IPADDR=211.183.3.101
    
    PREFIX=24
    
    GATEWAY=211.183.3.2
    
    DNS1=8.8.8.8
    ```
    
    ```bash
    [root@compute1 network-scripts]# vi ifcfg-ens160
    
    TYPE=OVSPort
    
    BOOTPROTO=none
    
    NAME=ens160
    
    DEVICE=ens160
    
    DEVICETYPE=ovs
    
    ONBOOT=yes
    
    OVS_BRIDGE=vswitch01
    
    [root@compute1 network-scripts]#
    
    [root@compute1 network-scripts]# ifup vswitch01 && ifup ens160
    
    [root@compute1 network-scripts]# ovs-vsctl show
    
    9ad4f087-78ba-4350-9df1-51e88801e960
    
    Bridge vswitch01
    Port vswitch01
    Interface vswitch01
    type: internal
    Port ens160
    Interface ens160
    ovs_version: "3.1.4"
    ```
    
- 각 컴퓨트 노드에 vswitch02(내부 연결용) 생성
    
    ```bash
    [root@compute1 network-scripts]# ovs-vsctl add-br vswitch02
    
    [root@compute1 network-scripts]# ovs-vsctl show
    
    Bridge vswitch02
    Port vswitch02
    Interface vswitch02
    type: internal
    Bridge vswitch01
    Port vswitch01
    Interface vswitch01
    type: internal
    Port ens160
    Interface ens160
    ovs_version: "3.1.4"
    ```
    
- 오버레이 네트워크(터널링) 구성하기
    
    ```bash
    [root@compute1 shared]# ovs-vsctl add-port vswitch02 gre12 -- set interface gre12 type=gre options:remote_ip=211.183.3.102
    
    [root@compute2 shared]# ovs-vsctl add-port vswitch02 gre21 -- set interface gre21 type=gre options:remote_ip=211.183.3.101
    
    [root@compute1 network-scripts]# ovs-vsctl show
    ```
    

<aside>
💡 vlan(tag) 는 구성하지 말고 라이브 마이그레이션 가능하도록 해야 함! (cli)

</aside>

- 라이브 마이그레이션 확인 (compute1,2에서 체크만 후에 스크립트에 추가)

```bash
virsh migrate --live --unsafe --verbose <옮길 가상머신 이름> qemu+ssh://<옮겨질 상대 IP>/system
```

---

## 7. Mariadb 레플리케이션 설정

```bash
yum -y install mariadb-server
```

```bash
########control 노드에서

vi /etc/my.cnf.d/mariadb-server.cnf

[mysqld]
log-bin=mysql-bin
server-id=1
```

위 두 줄 추가

```bash
systemctl restart mariadb
mkdir /mariadb_backup
mariabackup --backup --target-dir /mariadb_backup -u root
systemctl restart mariadb
mysql -u root -p
```

```bash
MariaDB > GRANT REPLICATION SLAVE on *.* TO 'backup'@'%' IDENTIFIED BY 'test123';
MariaDB > FLUSH PRIVILEGES;
MariaDB [(none)]> show master status;
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000006 |      1652931 |              |                  |
+------------------+----------+--------------+------------------+
여기서 FIle명과 Position 번호를 보기->backup에서 넣을 것임

############backup 노드에서
vi /etc/my.cnf.d/mariadb-server.cnf

[mysqld]
log-bin=mysql-bin
server-id=2
```

위 두 줄 추가하기!!!

```bash
systemctl restart mariadb
mysql -u root -p

MariaDB > stop slave
MariaDB > CHANGE MASTER TO MASTER_HOST="192.168.1.100", MASTER_USER="backup", MASTER_PASSWORD="test123", MASTER_PORT=3306, MASTER_LOG_FILE="mysql-bin.000003", MASTER_LOG_POS=342;
MariaDB > start slave

MariaDB [(none)]> show slave status\G;
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
```

위 두 줄 뜨나 확인
이후 control에서 db 생성해서 backup에서 확인

```bash
create database test;

show databases #—> 확인

systemctl enable mariadb #각 노드에서 마지막으로 실행
```

---

## 8. Node DB 구성

- 데이터베이스 생성

```bash
CREATE DATABASE IF NOT EXISTS Info;
```

- - 해당 데이터베이스 선택

```bash
USE Info;
```

- - 테이블 생성

```bash
CREATE TABLE IF NOT EXISTS node_tbl (
node_id INT PRIMARY KEY,
node_name VARCHAR(10),
cpu INT,
ram INT,
harddisk INT,
network1 VARCHAR(20),
network2 VARCHAR(20)
);
```

- - table에 값 insert

```bash
INSERT INTO node_tbl (node_id, node_name, cpu, ram, harddisk, network1, network2) VALUES (1, 'backup', 1, 1, 20, '211.183.3.98', '192.168.1.98');
INSERT INTO node_tbl (node_id, node_name, cpu, ram, harddisk, network1, network2) VALUES (2, 'storage', 1, 1, 80, '211.183.3.99', '192.168.1.99');
INSERT INTO node_tbl (node_id, node_name, cpu, ram, harddisk, network1, network2) VALUES (3, 'storage', 2, 2, 20, '211.183.3.100', '192.168.1.100');
INSERT INTO node_tbl (node_id, node_name, cpu, ram, harddisk, network1, network2) VALUES (4, 'compute1', 4, 4, 20, '211.183.3.101', '192.168.1.101');
INSERT INTO node_tbl (node_id, node_name, cpu, ram, harddisk, network1, network2) VALUES (5, 'compute2', 4, 4, 20, '211.183.3.102', '192.168.1.102');
```

```bash
CREATE TABLE IF NOT EXISTS instance_tbl (instance_id INT PRIMARY KEY, instance_name VARCHAR(20), centos_version VARCHAR(10), flavor VARCHAR(10), location VARCHAR(10));
```

- 수정

```bash
mysql -u root -p
show databases;
use Info;
drop instance_tbl
#새로운 instance_tbl
CREATE TABLE IF NOT EXISTS instance_tbl( instance_uuid INT NOT NULL AUTO_INCREMENT PRIMARY KEY, instance_id VARCHAR(10), instance_name VARCHAR(20), centos_versios VARCHAR(10), flavor VARCHAR(10), location VARCHAR(10)) AUTO_INCREMENT=1;
GRANT ALL PRIVILEGES ON Info.* TO 'info'@'%' IDENTIFIED BY 'info';
FLUSH PRIVILEGES;
```

```bash
systemctl restart mariadb
```

---

## 9. Zabbix 설치 및 설정 [control]

1. **httpd, mariadb 설치**

```bash
sudo -i
dnf install -y httpd mariadb mariadb-devel mariadb-server
```

먼저 root 권한으로 들어간 다음, zabbix server 설치에 필요한 httpd와 mariadb를 설치

1. **Zabbix 설치**

```bash
rpm -ivh https://repo.zabbix.com/zabbix/5.0/rhel/8/x86_64/zabbix-release-5.0-1.el8.noarch.rpm
dnf clean all
dnf -y install zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-agent
```

dnf clean all은 캐시 패키지를 제거하는 명령

1. **mariaDB 설정**

```bash
systemctl enable mariadb
systemctl start mariadb
```

start는 system을 지금 바로 시작하는 것이고, enable은 재부팅 시 자동으로 시작

mariadb 접속

```bash
mysql -u root -p
```

여기서 password는 없음

```bash
create database zabbix character set utf8 collate utf8_bin;
grant all privileges on zabbix.* to zabbixid@localhost identified by 'password';
flush privileges;
exit
```

zabbix라는 DB를 만들고, 사용자의 id와 비번을 zabbixid, password로 설정

flush로 변경사항을 적용한 뒤 exit

zabbix의 기본 테이블 만들기

```bash
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -u zabbixid -p zabbix
```

```bash
show tables;
```

테이블 생성 확인

1. **Zabbix 설정들 변경**

4-1) vi /etc/zabbix/zabbix_server.conf

```bash
91 DBHost=localhost				#주석 제거
100 DBName=zabbix				#DB이름 작성
116 DBUser=zabbixid				#user이름 작성
124 DBPassword=password				#주석 제거 후 password 작성
```

4-2) vi /etc/php-fpm.d/zabbix.conf

```bash
php_value[date.timezone] = Asia/Seoul
```

맨 마지막 줄의 주석(;)을 제거한 후 timezone을 Asia/Seoul로 바꿔준다

4-3) vi /etc/selinux/config

```bash
SELINUX=disabled
```

enforcing을 disabled로 바꿔준다

1. **시스템 시작**

```bash
systemctl enable zabbix-server
systemctl enable zabbix-agent
systemctl enable httpd
reboot
```

zabbix-server, zabbix-agent, httpd를 enable해둔 후 재부팅

1. **Zabbix 접속**

http://**서버 퍼블릭 IP**/zabbix

지금까지의 설정을 검토해준 후, Next step > Finish까지 누르면 로그인 창

초기 id/비번 : Admin/zabbix

---

## 10. Zabbix agent 설치 및 설정 [control 제외 나머지 노드]

1. **TimeZone 변경**

```bash
mv /etc/localtime /etc/localtime_org
ln -s /usr/share/zoneinfo/Asia/Seoul /etc/localtime
```

localtime 파일의 원본을 localtime_org로 백업해두고, 심볼릭링크를 사용해 Asia/Seoul의 타임존을 가져옴

1. **zabbix agent 설치**

```bash
rpm -ivh http://repo.zabbix.com/zabbix/5.0/rhel/8/x86_64/zabbix-agent-5.0.1-1.el8.x86_64.rpm
```

1. **conf파일 설정**

```bash
vi /etc/zabbix/zabbix_agentd.conf

119 Server=211.183.3.100
171 Hostname=[해당 노드 이름]
```

1. **서비스 실행**

```bash
systemctl enable zabbix-agent
systemctl start zabbix-agent
```

1. **Server에서 Agent 등록**

**http://서버 퍼블릭 IP/zabbix**로 접속

6-1) Host grops 생성

Configuration-Host grops에서 Create host group으로 centos8-agent 생성

6-2) Host 생성

Configuration-Hosts 탭에서 Create host로 들어가 Host에서 호스트 명, 표시명, 6-1에서 생성한 호스트 그룹 해당 노드의 IP 주소 작성

Templates에서 Template OS Linux by Zabbix agent로 선택 → ADD

Configuration-Hosts에 들어가서 각 노드 별로 ZBX 초록불 확인

![Untitled](https://prod-files-secure.s3.us-west-2.amazonaws.com/1d1f5e17-6d94-451c-9271-c698ee060384/a40d554c-e850-4b1b-8472-0f1b1fed73cb/Untitled.png)

## <Zabbix 동작 모습>

![1.PNG](https://prod-files-secure.s3.us-west-2.amazonaws.com/1d1f5e17-6d94-451c-9271-c698ee060384/22d3f713-c91a-486f-a2ba-00c8a20e8b7d/1.png)

위는 대쉬보드

![2.PNG](https://prod-files-secure.s3.us-west-2.amazonaws.com/1d1f5e17-6d94-451c-9271-c698ee060384/a6aa1f61-ecd7-42e9-8c77-711993f244f5/2.png)

위는 각 노드 별로 CPU 사용량 체크

---

## 11. 네트워크까지 설정된 가상머신 만들기 스크립트

**[compute1,2]**

```bash
yum -y install sysstat
```

control에서 마이 그레이션이 가능하도록 compute1과 compute2끼리도 key-pair로 ssh 연결을 해놓는다.

[compute1,2]

```bash
[root@compute1 ~]# ssh-keygen -q -N "" -f compute*.pem

[root@compute1 ~]# touch .ssh/known_hosts

[root@compute1 ~]# ssh-keyscan 192.168.1.102 >> .ssh/known_hosts
```

위 진행 후 authorized_keys에 상대 노드의 public key 추가

/Raid01 공유된 디렉토리에 ifcfg-eth1 파일 필요함

```bash
#파일 내용
DEVICE="eth1"
BOOTPROTO="none"
ONBOOT="yes"
TYPE="Ethernet"
IPADDR=10.10.10.10
PREFIX=24
```

/shared 디렉토리에 [ip.sh](http://ip.sh/) 파일생성 및 수정

```bash
touch ip.sh && chmod +x ip.sh
```

```bash
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
```

**<가상 머신 만들기 스크립트 코드>**

```bash
1 #!/bin/bash
  2
  3 fcomp(){
  4         com1=$(ssh compute1 "mpstat | grep all | gawk '{print \$4}'")
  5         com2=$(ssh compute2 "mpstat | grep all | gawk '{print \$4}'")
  6         echo "CPU USAGE: compute1=$com1, compute2=$com2"
  7 }
  8
  9 fcheckvm() {
 10     echo "=========compute1========="
 11     ssh compute1 'virsh list --all'
 12     echo "=========compute2========="
 13     ssh compute2 'virsh list --all'
 14 }
 15
 16 fdeletevm() {
 17     fcheckvm
 18     echo -n "select compute: "
 19     read compute
 20     echo -n "select delete vname: "
 21     read delvname
 22     status1=$(ssh $compute "virsh list --all | grep $delvname")
 23     status2=$(echo $status1 | gawk '{print $3}')
 24     if [ $status2 = "running" ]; then
 25         ssh $compute "virsh destroy $delvname"
 26     fi
 27     ssh $compute "virsh undefine $delvname --remove-all-storage"
 28     echo "delete finished"
 29     mysql Info -u info -pinfo <<EOF
 30 DELETE FROM instance_tbl WHERE instance_name = '$delvname';
 31 EOF
 32
 33     read nnn
 34 }
 35
 36 fmakevm() {
 37     echo
 38     fversion
 39     echo -n "enter vname: "
 40     read vname
 41     echo  "select option: "
 42     echo "1) m1.small(vcpu:1, ram:2048)"
 43     echo "2) m1.medium(vcpu:2, ram:2048)"
 44     echo "3) m1.large(vcpu:4, ram:4096)"
 45     fflavor
 46     echo -n "enter root password: "
 47     read -s rootpwd
 48     echo
 49     echo "========================"
50     # 파일 경로 설정 (storage 노드의 /Raid01/ifcfg-eth1)
 51     file_path="/Raid01/ifcfg-eth1"
 52
 53     # 현재 IP 주소 추출
 54     previous_ip=$(ssh storage "grep 'IPADDR=' \"$file_path\" | awk -F= '{print \$2}'")
 55
 56     # 현재 IP 주소와 시작 IP 주소를 비교하여 뒷자리 수 추출
 57     current_suffix=$(echo "$previous_ip" | awk -F'.' '{print $4}')
 58
 59     # 뒷자리 수를 1 증가
 60     new_suffix=$((current_suffix + 1))
 61
 62     # 뒷자리 수가 253을 초과하면 10으로 초기화
 63     if [ "$new_suffix" -gt 253 ]; then
 64         new_suffix=10
 65     fi
 66
 67     # 뒷자리 수가 10 미만이면 10으로 설정
 68     if [ "$new_suffix" -lt 10 ]; then
 69         new_suffix=10
 70     fi
 71
 72     # 새로운 IP 주소 생성
 73     new_ip="10.10.10.$new_suffix"
 74
 75     # 수정할 내용 생성
 76     new_content="DEVICE=\"eth1\"\nBOOTPROTO=\"none\"\nONBOOT=\"yes\"\nTYPE=\"Ethernet\"\nIPADDR=$new_ip\nPREFIX=24"
 77
 78     # 파일 수정 (storage 노드에서 실행)
 79     ssh storage "echo -e \"$new_content\" > \"$file_path\""
 80     echo "ifcfg-eth1 파일이 수정되었습니다. 새로운 IP 주소: $new_ip"
 81
 82     fcomp
 83
 84     if [ "$version" = centos7 ]
 85         then
 86                 if [[ $com1 < $com2 ]] # com1 < com2
 87                 then # com1
 88                         ssh compute1 "cd /shared && cp  CentOS7.qcow2 $vname.qcow2 && virt-customize -a ${vname}.qcow2 --root-password password:$rootpwd --upload /shared/ifcfg-eth1:/etc    /sysconfig/network-scripts/ifcfg-eth1 --firstboot-command 'ifup eth1' && virt-install --name $vname --vcpus $vcpu --ram $ram --disk /shared/$vname.qcow2 --network=bridge:vswitch01,model    =virtio,virtualport_type=openvswitch --network=bridge:vswitch02,model=virtio,virtualport_type=openvswitch,target=${vname}_port1   --import --noautoconsole"
 89                         read nnn
 90                         var=$(ssh compute1 "virsh list --all | grep $vname | gawk '{print \$1}'")
 91                         instance_id=$((var))
 92                         if [[ $flavor = 1 ]]
 93                         then
 94                                 mysql Info -u info -pinfo <<EOF
 95 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.small', 'compute1');
 96 EOF
97                         elif [[ $flavoe = 2 ]]
 98                         then
 99                                 mysql Info -u info -pinfo <<EOF
100 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.medium', 'compute1');
101 EOF
102                         else
103                                 mysql Info -u info -pinfo <<EOF
104 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.large', 'compute1');
105 EOF
106                         fi
107                 else # com2
108                         ssh compute2 "cd /shared && cp  CentOS7.qcow2 $vname.qcow2 && virt-customize -a ${vname}.qcow2 --root-password password:$rootpwd --upload /shared/ifcfg-eth1:/etc    /sysconfig/network-scripts/ifcfg-eth1 --firstboot-command 'ifup eth1' && virt-install --name $vname --vcpus $vcpu --ram $ram --disk /shared/$vname.qcow2 --network=bridge:vswitch01,model    =virtio,virtualport_type=openvswitch --network=bridge:vswitch02,model=virtio,virtualport_type=openvswitch,target=${vname}_port1   --import --noautoconsole"
109                         read nnn
110                         var=$(ssh compute1 "virsh list --all | grep $vname | gawk '{print \$1}'")
111                         instance_id=$((var))
112                         if [[ $flavor = 1 ]]
113                         then
114                                 mysql Info -u info -pinfo <<EOF
115 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.small', 'compute2');
116 EOF
117                         elif [[ $flavoe = 2 ]]
118                         then
119                                 mysql Info -u info -pinfo <<EOF
120 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.medium', 'compute2');
121 EOF
122                         else
123                                 mysql Info -u info -pinfo <<EOF
124 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.large', 'compute2');
125 EOF
126                         fi
127                 fi
128         elif [ "$version" = centos8 ] ####### centos 8 change
129         then
130                 if [[ $com1 < $com2 ]] # com1 < com2
131                 then # com1
132                         ssh compute1 "cd /shared && cp  CentOS8.qcow2 $vname.qcow2 && virt-customize -a ${vname}.qcow2 --root-password password:$rootpwd --upload /shared/ifcfg-eth1:/etc    /sysconfig/network-scripts/ifcfg-eth1 --firstboot-command 'ifup eth1' && virt-install --name $vname --vcpus $vcpu --ram $ram --disk /shared/$vname.qcow2 --network=bridge:vswitch01,model    =virtio,virtualport_type=openvswitch --network=bridge:vswitch02,model=virtio,virtualport_type=openvswitch,target=${vname}_port1   --import --noautoconsole"
133                         read nnn
134                         var=$(ssh compute1 "virsh list --all | grep $vname | gawk '{print \$1}'")
135                         instance_id=$((var))
136                         if [[ $flavor = 1 ]]
137                         then
138                                 mysql Info -u info -pinfo <<EOF
139 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.small', 'compute1');
140 EOF
141                         elif [[ $flavoe = 2 ]]
142                         then
143                                 mysql Info -u info -pinfo <<EOF
144 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.medium', 'compute1');
145 EOF
146                         else
147                                 mysql Info -u info -pinfo <<EOF
148 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.large', 'compute1');
149 EOF
150                         fi
151                 else # com2
152                         ssh compute2 "cd /shared && cp  CentOS8.qcow2 $vname.qcow2 && virt-customize -a ${vname}.qcow2 --root-password password:$rootpwd --upload /shared/ifcfg-eth1:/etc    /sysconfig/network-scripts/ifcfg-eth1 --firstboot-command 'ifup eth1' && virt-install --name $vname --vcpus $vcpu --ram $ram --disk /shared/$vname.qcow2 --network=bridge:vswitch01,model    =virtio,virtualport_type=openvswitch --network=bridge:vswitch02,model=virtio,virtualport_type=openvswitch,target=${vname}_port1   --import --noautoconsole"
153                         read nnn
154                         var=$(ssh compute1 "virsh list --all | grep $vname | gawk '{print \$1}'")
155                         instance_id=$((var))
156                         if [[ $flavor = 1 ]]
157                         then
158                                 mysql Info -u info -pinfo <<EOF
159 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.small', 'compute2');
160 EOF
161                         elif [[ $flavoe = 2 ]]
162                         then
163                                 mysql Info -u info -pinfo <<EOF
164 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.medium', 'compute2');
165 EOF
166                         else
167                                 mysql Info -u info -pinfo <<EOF
168 INSERT INTO instance_tbl VALUES(DEFAULT, $instance_id, '$vname', '$version', 'm1.large', 'compute2');
169 EOF
170                         fi
171                 fi
172         fi
173 }
174
175 fversion() {
176     echo -n "select version(centos7 or centos8): "
177     read version
178     if [ $version != centos7 ] && [ $version != centos8 ]; then
179         echo "ERROR!!! enter version(centos7, centos8)"
180         read nnn
181         fversion
182     fi
183 }
184
185 fflavor() {
186     read flavor
187     case $flavor in
188         1) vcpu=1; ram=2048 ;;
189         2) vcpu=2; ram=2048 ;;
190         3) vcpu=4; ram=4096 ;;
191         *) echo "select number in 1, 2, 3"; read nnn; fflavor ;;
192     esac
193 }
194
195 fmigratevm() {
196     fcheckvm
197     echo -n "select source compute: "
198     read source_compute
199     echo -n "select target compute: "
200     read target_compute
201     echo -n "select migrate vm: "
202     read migrate_vm
203
204     # 라이브 마이그레이션 실행
205     ssh $source_compute "virsh migrate --live --persistent --undefinesource $migrate_vm qemu+ssh://$target_compute/system"
206     var=$(ssh $source_compute "virsh list --all | grep $migrate_vm | gawk '{print \$1}'")
207     instance_id=$((var))
208
209
210     if [[ $source_compute = "compute1" ]]; then
211         target_compute="compute2"
212     else
213         target_compute="compute1"
214     fi
215
216
217     mysql Info -u info -pinfo <<EOF
218 UPDATE instance_tbl SET location = '$target_compute' WHERE instance_name = '$migrate_vm';
219 EOF
220
221
222
223     # 마이그레이션 후 가상 머신 목록 출력
224     echo "=========source compute========="
225     ssh $source_compute 'virsh list --all'
226     echo "=========target compute========="
227     ssh $target_compute 'virsh list --all'
228 }
229
230 menu() {
231     clear
232     echo
233     echo "====================================="
234     echo -e "\t1) make virtual machine"
235     echo -e "\t2) check virtual machine"
236     echo -e "\t3) delete virtual machine"
237     echo -e "\t4) migrate virtual machine"
238     echo -e "\t0) Exit menu"
239     echo "====================================="
240     echo -en "\t\tEnter option: "
241     read option
242 }
243
244 while [ 1 ]; do
245     menu
246     case $option in
247         0)
248             echo
249             break ;;
250         1)
251             fmakevm ;;
252         2)
253             fcheckvm
254             read nnn ;;
255         3)
256             fdeletevm ;;
257         4)
258             fmigratevm ;;
259     esac
260 done
```

---

## 12. Zabbix와 Grafana 연동

1. **Zabbix Server에 Grafana 설치**

```bash
dnf -y install initscripts urw-fonts wget
```

https://grafana.com/grafana/download 에서 최신 버전으로 install

```bash
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server
```

```bash
grafana-cli plugins install alexanderzobnin-zabbix-app
systemctl restart grafana-server
```

1. **보안그룹 설정(포트 오픈)**

```bash
firewall-cmd --zone=public --add-port=3000/tcp --permanent
firewall-cmd --reload
```

1. **Grafana 접속**

[http://서버IP:3000](http://xn--ip-v41jw5m:3000/) 으로 접속

초기 아이디/비번은 **admin/admin**

1. **Zabbix 연동**

설정 > Plugins 로 들어간 후 zabbix를 검색해보면 플러그인이 이미 있는걸 확인할 수 있다 (아까 플러그인 설치했음)

이 자빅스 플러그인을 누르고 들어가서 Enable 버튼

설정 > Data Sources > Add data source

자빅스를 검색해 select

이제 자빅스 Data Source를 입력

HTTP/URL - [http://서버IP/zabbix/api_jsonrpc.php](http://xn--ip-v41jw5m/zabbix/api_jsonrpc.php)

Zabbix API details - Username/Password : Zabbix 계정정보 입력

1. **Grafana DashBoard 추가**

그라파나 대쉬 보드 사이트 : https://grafana.com/grafana/dashboards/?search=zabbix

grafana로 돌아와 + > Import 를 눌러 복사한 url을 넣고 load

zabbix - zabbix를 선택해준 후 Import

<Grafana DashBoard 화면>
![Untitled](https://prod-files-secure.s3.us-west-2.amazonaws.com/1d1f5e17-6d94-451c-9271-c698ee060384/a596ed64-551f-4824-97ff-5adcc9cae340/Untitled.png)
