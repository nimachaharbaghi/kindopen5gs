# Prediction of 5GC Data Using a Tiny LLM

## Overview
This project explores predicting **5G Core (5GC) metrics** using a **tiny Large Language Model (LLM)**.

We deploy **OPEN5GS** on a local **Kubernetes (kind)** cluster, collect metrics using **Prometheus**, and apply **Chronos-bolt-tiny** for time-series prediction (e.g., CPU usage).

This repository is in the **very early stage** of development.

---

## Current Plan
- Deploy a Kubernetes cluster using **kind**
- Deploy **OPEN5GS**
- Deploy **Prometheus** to collect metrics
- Extract and preprocess time-series data
- Predict metrics using **Chronos-bolt-tiny**

---

## Bonus (Planned)
- Compare results with **TimeGPT**  
  https://github.com/Nixtla/nixtla
---

# Open5GS + UERANSIM 5G Core Network Deployment on Kubernetes
## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kind Cluster (kind-5gs)                  │
│                                                               │
│  ┌────────────┐                                              │
│  │  UERANSIM  │                                              │
│  │  ┌──────┐  │         ┌──────────────────────┐            │
│  │  │  UE  │  │ ◄─────► │   AMF (Access &      │            │
│  │  └──────┘  │  N1/N2  │   Mobility Mgmt)     │            │
│  │  ┌──────┐  │         └──────────────────────┘            │
│  │  │ gNB  │  │                    │                         │
│  │  └──────┘  │                    │ SBI                     │
│  └────────────┘         ┌──────────┴──────────┐             │
│         │               │                      │             │
│         │ GTP-U         ▼                      ▼             │
│         │      ┌─────────────┐       ┌─────────────┐        │
│         │      │    AUSF     │       │    UDM      │        │
│         │      │   (Auth)    │       │   (User     │        │
│         │      └─────────────┘       │    Data)    │        │
│         │              │              └─────────────┘        │
│         │              │                     │               │
│         ▼              ▼                     ▼               │
│  ┌──────────┐   ┌──────────────────────────────┐            │
│  │   UPF    │   │         NRF (Discovery)       │            │
│  │  (User   │   └──────────────────────────────┘            │
│  │  Plane)  │                  │                             │
│  └──────────┘                  │                             │
│       ▲                        ▼                             │
│       │ PFCP          ┌─────────────┐                        │
│       │               │     SMF     │                        │
│       └───────────────│  (Session   │                        │
│                       │    Mgmt)    │                        │
│                       └─────────────┘                        │
│                              │                               │
│          ┌───────────────────┼───────────────────┐           │
│          ▼                   ▼                   ▼           │
│    ┌─────────┐         ┌─────────┐        ┌─────────┐       │
│    │   PCF   │         │  NSSF   │        │   BSF   │       │
│    │(Policy) │         │ (Slice) │        │(Binding)│       │
│    └─────────┘         └─────────┘        └─────────┘       │
│                                                               │
│    ┌─────────┐         ┌─────────┐                          │
│    │   UDR   │         │ MongoDB │                          │
│    │  (Data  │ ◄─────► │  (Sub-  │                          │
│    │   Repo) │         │ scriber)│                          │
│    └─────────┘         └─────────┘                          │
│                                                               │
│    ┌─────────────────────────────┐                          │
│    │       WebUI (Port 30999)     │                          │
│    └─────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```
---
## Overview

This deployment provides a fully functional 5G Core Network for testing and development purposes. It includes:

- **Open5GS v2.7.6-128-g6489de3**: Complete 5G Core implementation
- **UERANSIM v3.2.7**: 5G UE and gNB simulator
- **MongoDB**: Subscriber database
- **WebUI**: Web interface for subscriber management

---
### Network Functions (NFs)

| NF | Function | Port | Protocol |
|----|----------|------|----------|
| **AMF** | Access and Mobility Management | 7777 | SBI (HTTP/2) |
| **SMF** | Session Management | 7777 | SBI, 8805 PFCP |
| **UPF** | User Plane Function | 2152 (GTP-U), 8805 (PFCP) | GTP-U, PFCP |
| **NRF** | Network Repository Function | 7777 | SBI |
| **AUSF** | Authentication Server | 7777 | SBI |
| **UDM** | Unified Data Management | 7777 | SBI |
| **UDR** | Unified Data Repository | 7777 | SBI |
| **PCF** | Policy Control Function | 7777 | SBI |
| **NSSF** | Network Slice Selection | 7777 | SBI |
| **BSF** | Binding Support Function | 7777 | SBI |
| **WebUI** | Subscriber Management | 9999 (internal), 30999 (NodePort) | HTTP |

---
## Prerequisites

- Docker
- kind (Kubernetes in Docker)
- kubectl
- 8GB+ RAM recommended
- Linux host (tested on Ubuntu)
- Git (to clone source repositories)

---
### 1. Clone source code

The Open5GS and UERANSIM source code is not included in this repository (to keep it lightweight). Clone them separately:

```bash
# Clone Open5GS
git clone https://github.com/open5gs/open5gs.git

# Clone UERANSIM
git clone https://github.com/aligungr/UERANSIM.git
```

Your directory structure should look like:
```
your-repo/
├── open5gs/          ← Cloned separately
├── UERANSIM/         ← Cloned separately
├── k8s/
├── Dockerfile.*
└── *.sh
```
---
### Deployment Steps

### 1. Create the Kind Cluster

```bash
kind create cluster --config kind-5gs.yaml
```

This creates a single-node cluster named `kind-5gs` with the following exposed ports:
- `30999`: WebUI access
- `38412`: N2 (NGAP) interface
- `2152`: GTP-U data plane
- `8805`: PFCP control plane
---

### 2. Build Docker Images

Build Open5GS from source:
```bash
docker build -t local/open5gs:latest -f Dockerfile.open5gs .
```

Build UERANSIM from source:
```bash
docker build -t local/ueransim:latest -f Dockerfile.ueransim .
```

Build WebUI:
```bash
docker build -t local/webui:latest -f Dockerfile.webui .
docker tag local/webui:latest local/open5gs-webui:latest

```

### 3. Load Images into Kind Cluster

```bash
kind load docker-image local/open5gs:latest --name kind-5gs
kind load docker-image local/ueransim:latest --name kind-5gs
kind load docker-image local/open5gs-webui:latest --name kind-5gs
```

### 4. Deploy the 5G Core Network

Create namespace:
```bash
kubectl create namespace open5gs
```

Deploy MongoDB:
```bash
kubectl apply -f k8s/open5gs/mongodb.yaml
```

Deploy all Open5GS Network Functions:
```bash
# Deploy core NFs
kubectl apply -f k8s/open5gs/nrf.yaml
kubectl apply -f k8s/open5gs/scp.yaml
kubectl apply -f k8s/open5gs/ausf.yaml
kubectl apply -f k8s/open5gs/udm.yaml
kubectl apply -f k8s/open5gs/udr.yaml
kubectl apply -f k8s/open5gs/pcf.yaml
kubectl apply -f k8s/open5gs/nssf.yaml
kubectl apply -f k8s/open5gs/bsf.yaml

# Deploy ConfigMaps
kubectl apply -f k8s/open5gs/configmap-amf.yaml
kubectl apply -f k8s/open5gs/configmap-ausf.yaml
kubectl apply -f k8s/open5gs/configmap-bsf.yaml
kubectl apply -f k8s/open5gs/configmap-nrf.yaml
kubectl apply -f k8s/open5gs/configmap-nssf.yaml
kubectl apply -f k8s/open5gs/configmap-pcf.yaml
kubectl apply -f k8s/open5gs/configmap-scp.yaml
kubectl apply -f k8s/open5gs/configmap-smf.yaml
kubectl apply -f k8s/open5gs/configmap-udm.yaml
kubectl apply -f k8s/open5gs/configmap-udr.yaml
kubectl apply -f k8s/open5gs/configmap-upf.yaml



# Deploy AMF, SMF, UPF
kubectl apply -f k8s/open5gs/amf.yaml
kubectl apply -f k8s/open5gs/smf.yaml
kubectl apply -f k8s/open5gs/upf.yaml

# Deploy WebUI
kubectl apply -f k8s/open5gs/webui.yaml
```

### 5. Initialize Database

**Add admin user for WebUI:**
```bash
kubectl exec -n open5gs deployment/webui -- sh -c "cat > /webui/create-admin.js << 'EOF'
const mongoose = require('mongoose');
const Schema = mongoose.Schema;
const passportLocalMongoose = require('passport-local-mongoose');

const Account = new Schema({
  roles: [String]
});

Account.plugin(passportLocalMongoose);
const AccountModel = mongoose.model('Account', Account);

mongoose.connect('mongodb://mongodb:27017/open5gs');

AccountModel.register(new AccountModel({
  username: 'admin',
  roles: ['admin']
}), '1423', function(err, account) {
  if (err) {
    console.error(err);
    process.exit(1);
  }
  console.log('Admin account created successfully');
  process.exit(0);
});
EOF
cd /webui && node create-admin.js"
```

You should see: `Admin account created successfully`


**Add subscriber:**
```bash
kubectl run -it --rm debug --image=local/open5gs:latest --restart=Never -n open5gs -- \
  /bin/open5gs-dbctl add 999700000000001 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA
```

**Subscriber Details:**
- **IMSI**: 999700000000001
- **K (Key)**: 465B5CE8B199B49FAA5F0A2EE238A6BC
- **OPc**: E8ED289DEBA952E4283B54E88E6183CA

### 6. Deploy UERANSIM

Deploy ConfigMaps:
```bash
kubectl apply -f k8s/ueransim/configmap-gnb.yaml
kubectl apply -f k8s/ueransim/configmap-ue.yaml
```

Deploy gNB and UE (combined in single pod):
```bash
kubectl apply -f k8s/ueransim/gnb-ue.yaml
```


### 7. Verify Deployment

Check all pods are running:
```bash
kubectl get pods -n open5gs
```

Expected output - all pods should be `Running`:
```
NAME                            READY   STATUS    RESTARTS   AGE
amf-xxxxxxxxxx-xxxxx            1/1     Running   0          Xm
ausf-xxxxxxxxxx-xxxxx           1/1     Running   0          Xm
bsf-xxxxxxxxxx-xxxxx            1/1     Running   0          Xm
mongodb-xxxxxxxxxx-xxxxx        1/1     Running   0          Xm
nrf-xxxxxxxxxx-xxxxx            1/1     Running   0          Xm
nssf-xxxxxxxxxx-xxxxx           1/1     Running   0          Xm
pcf-xxxxxxxxxx-xxxxx            1/1     Running   0          Xm
scp-xxxxxxxxxx-xxxxx            1/1     Running   0          Xm
smf-xxxxxxxxxx-xxxxx            1/1     Running   0          Xm
udm-xxxxxxxxxx-xxxxx            1/1     Running   0          Xm
udr-xxxxxxxxxx-xxxxx            1/1     Running   0          Xm
ueransim-gnb-xxxxxxxxxx-xxxxx   2/2     Running   0          Xm
upf-xxxxxxxxxx-xxxxx            1/1     Running   0          Xm
webui-xxxxxxxxxx-xxxxx          1/1     Running   0          Xm
```

---

## Testing the 5G Network

### Check UE Registration

```bash
kubectl logs -n open5gs deployment/ueransim-gnb -c ue --tail=50
```

**Expected Output:**
```
[2025-12-06 XX:XX:XX.XXX] [nas] [info] Initial Registration is successful
[2025-12-06 XX:XX:XX.XXX] [nas] [info] PDU Session establishment is successful PSI[1]
[2025-12-06 XX:XX:XX.XXX] [app] [info] Connection setup for PDU session[1] is successful, TUN interface[uesimtun0, 10.45.0.X] is up.
```

### Check AMF Logs

```bash
kubectl logs -n open5gs deployment/amf --tail=50
```

Look for:
- UE registration messages
- NGAP connection establishment

### Check SMF Logs

```bash
kubectl logs -n open5gs deployment/smf --tail=50
```

Look for:
- PDU Session establishment
- UE IP address assignment
- PFCP session creation

### Check UPF Logs

```bash
kubectl logs -n open5gs deployment/upf --tail=50
```

Look for:
- PFCP association with SMF
- UPF session creation
- NAT rules configured
- ogstun interface status

### Verify Data Plane

Check UPF ogstun interface statistics:
```bash
kubectl exec -n open5gs deployment/upf -- ip -s link show ogstun
```

This shows RX/TX packet counts, confirming GTP-U tunnel traffic.

### Access WebUI

Open browser to: `http://localhost:30999`

**Default Credentials:**
- Username: `admin`
- Password: `1423`

From WebUI you can:
- View registered subscribers
- Add/remove/edit subscribers
- Monitor active sessions


### Clean Restart

To restart everything:
```bash
# Delete all resources
kubectl delete namespace open5gs

# Recreate namespace
kubectl create namespace open5gs

# Redeploy (follow deployment steps again)
```

---

## Known Limitations

### 1. Internet Connectivity

**Status**: ❌ Not functional

**Reason**: The kind cluster runs in Docker with isolated networking. While the 5G control and user plane are fully functional, UE traffic cannot reach the external internet.

**Workarounds**:
- Use a production Kubernetes cluster with proper external networking
- Configure advanced CNI plugins (Calico, Flannel with specific settings)
- Accept this as a protocol testing environment

### 2. What Works

✅ **Fully Functional:**
- UE Registration (N1 signaling)
- Authentication (AUSF/UDM/UDR)
- PDU Session Establishment
- GTP-U tunnel creation
- PFCP session management
- Service-based interface (SBI) communication
- Network Function discovery (NRF)
- All 5G control plane procedures

✅ **Partially Functional:**
- User plane forwarding within cluster
- GTP encapsulation/decapsulation
- UE IP address assignment
- TUN interface setup

❌ **Not Functional:**
- Internet access from UE
- External traffic routing

---

## Deploying Prometheus on a kind Cluster Using Helm

This section describes how to deploy **Prometheus**, **Grafana**, and **Alertmanager** on a local **kind (Kubernetes in Docker)** cluster using the **kube-prometheus-stack** Helm chart.

---

### Kube-Prometheus-Stack

The **kube-prometheus-stack** is a collection of Kubernetes manifests, Grafana dashboards, and Prometheus rules managed by the **Prometheus Operator**. It provides an end-to-end monitoring solution for Kubernetes clusters.

> **Note:** Helm must be installed before proceeding.

---
## Add Helm Repositories

Add the Prometheus Community and Stable Helm repositories:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update
```
---
###Create Monitoring Namespace

Create a dedicated namespace for monitoring:
```bash
kubectl create namespace monitoring
```
---

###Install kube-prometheus-stack

Install the kube-prometheus-stack and expose services using NodePort:

Prometheus: 30000

Grafana: 31000

Alertmanager: 32000
```bash 
helm install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30000 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=31000 \
  --set alertmanager.service.type=NodePort \
  --set alertmanager.service.nodePort=32000 \
  --set prometheus-node-exporter.service.type=NodePort \
  --set prometheus-node-exporter.service.nodePort=32001
```
After deployment, you should see output similar to:

```
NAME: kind-prometheus
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
```

---
###Verify Installation

Check that all pods are running:
```bash
kubectl get pods -n monitoring -l release=kind-prometheus
```
Verify all resources in the namespace:
```bash 
kubectl get all -n monitoring
```
---
###Access Monitoring Dashboards

Prometheus: http://<nodeIP>:30000/graph

Alertmanager: http://<nodeIP>:32000/graph

Grafana: http://<nodeIP>:31000

Grafana Credentials

Use the following credentials to access Grafana:
```
Username: admin

Password: prom-operator
```


---
## Status
🚧 Work in progress
