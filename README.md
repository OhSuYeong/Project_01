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
