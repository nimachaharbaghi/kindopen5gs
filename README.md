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
### 2. Clone source code

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

---
# Open5GS + UERANSIM 5G Core Network Deployment on Kubernetes

This repository contains a complete deployment of Open5GS 5G Core Network and UERANSIM (5G UE/RAN Simulator) on a local Kubernetes cluster using kind (Kubernetes in Docker).

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Deployment Components](#deployment-components)
- [Deployment Scripts](#deployment-scripts)
- [Testing the 5G Network](#testing-the-5g-network)
- [Troubleshooting](#troubleshooting)
- [Known Limitations](#known-limitations)

---

## Overview

This deployment provides a fully functional 5G Core Network for testing and development purposes. It includes:

- **Open5GS v2.7.6-128-g6489de3**: Complete 5G Core implementation
- **UERANSIM v3.2.7**: 5G UE and gNB simulator
- **MongoDB**: Subscriber database
- **WebUI**: Web interface for subscriber management

### Network Configuration

- **PLMN**: MCC=999, MNC=70
- **TAC**: 1
- **UE Subnet**: 10.45.0.0/16
- **Gateway**: 10.45.0.1
- **DNS**: 8.8.8.8, 8.8.4.4

---

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

## Installation

### 1. Clone this repository

```bash
git clone <your-repo-url>
cd <repo-directory>
```

### 2. Clone source code

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

## Quick Start

**TLDR**: For automated deployment, use the provided scripts:
```bash
kind create cluster --config kind-5gs.yaml
./build-and-deploy.sh
```

See [Deployment Scripts](#deployment-scripts) below for more options.

---

### Manual Deployment Steps

### 1. Create the Kind Cluster

```bash
kind create cluster --config kind-5gs.yaml
```

This creates a single-node cluster named `kind-5gs` with the following exposed ports:
- `30999`: WebUI access
- `38412`: N2 (NGAP) interface
- `2152`: GTP-U data plane
- `8805`: PFCP control plane

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
```

### 3. Load Images into Kind Cluster

```bash
kind load docker-image local/open5gs:latest --name kind-5gs
kind load docker-image local/ueransim:latest --name kind-5gs
kind load docker-image local/webui:latest --name kind-5gs
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
kubectl apply -f k8s/open5gs/configmap-smf.yaml
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

## Deployment Components

### Dockerfile.open5gs

Builds Open5GS from source with all dependencies including:
- All 5G Core Network Functions
- PFCP, GTP-U protocol support
- iptables for NAT
- UPF entrypoint script for network setup

### Dockerfile.ueransim

Builds UERANSIM from source:
- nr-gnb: 5G gNB simulator
- nr-ue: 5G UE simulator

### Dockerfile.webui

Builds Open5GS WebUI:
- Node.js 18
- Next.js application
- Subscriber management interface

### upf-entrypoint.sh

UPF startup script that:
1. Starts the UPF daemon
2. Waits for ogstun interface creation
3. Brings up the ogstun interface
4. Configures NAT rules for UE subnet (10.45.0.0/16)

### Key Configuration Files

**k8s/open5gs/configmap-amf.yaml**
- AMF configuration with FQDN advertise addresses
- NGAP, SBI endpoints
- PLMN and TAC settings

**k8s/open5gs/configmap-smf.yaml**
- SMF configuration with FQDN advertise addresses
- PFCP, GTP-U, SBI endpoints
- UE IP pool and DNS settings

**k8s/open5gs/configmap-upf.yaml**
- UPF configuration with FQDN advertise addresses
- PFCP and GTP-U endpoints
- Session subnet configuration

**k8s/ueransim/configmap-gnb.yaml**
- gNB configuration
- PLMN, TAC, NGAP settings
- AMF connection details

**k8s/ueransim/configmap-ue.yaml**
- UE configuration
- IMSI, K, OPc credentials
- gNB connection (127.0.0.1 - same pod)

---

## Deployment Scripts

Three shell scripts are provided to simplify deployment and testing:

### `build-and-deploy.sh` - Complete Build & Deploy

**Purpose**: First-time setup - builds all images and deploys

```bash
./build-and-deploy.sh
```

**What it does:**
1. Builds Open5GS Docker image (~10-20 minutes)
2. Builds UERANSIM Docker image (~5-10 minutes)
3. Builds WebUI Docker image (~5-10 minutes)
4. Loads all images into kind cluster
5. Updates Kubernetes manifests to use local images
6. Calls `deploy.sh` to deploy everything

**Total time**: 30-40 minutes
**Use when**: First-time setup or rebuilding images after code changes

---

### `deploy.sh` - Fast Deploy/Redeploy

**Purpose**: Deploy using existing images (much faster)

```bash
./deploy.sh
```

**What it does:**
1. Creates open5gs namespace
2. Deploys MongoDB and waits for ready
3. Deploys WebUI
4. Deploys all Open5GS ConfigMaps
5. Deploys NRF (waits for ready)
6. Deploys SCP (waits for ready)
7. Deploys remaining control plane functions
8. Deploys AMF, SMF, UPF (waits for ready)
9. Deploys UERANSIM ConfigMaps
10. Deploys UERANSIM gNB+UE pod
11. Creates admin account for WebUI (admin/1423)
12. Adds default subscriber to database

**Total time**: 3-5 minutes
**Use when**:
- Redeploying after cleanup
- Testing configuration changes
- Images already built

---

### `cleanup.sh` - Clean Removal

**Purpose**: Remove deployment while keeping cluster and images

```bash
./cleanup.sh
```

**What it does:**
- Deletes all UERANSIM resources
- Deletes all Open5GS network functions
- Deletes all ConfigMaps
- Deletes WebUI and MongoDB
- Deletes the open5gs namespace
- Keeps kind cluster running
- Keeps Docker images for fast redeployment

**Total time**: 1 minute
**Use when**: Testing different configurations, cleaning up

**Common workflow**:
```bash
./cleanup.sh     # Clean up
./deploy.sh      # Fast redeploy (uses existing images)
```

---

### Common Workflows

**First-time deployment:**
```bash
kind create cluster --config kind-5gs.yaml
./build-and-deploy.sh
```

**Testing configuration changes:**
```bash
# Edit configuration files in k8s/open5gs/
./cleanup.sh
./deploy.sh  # Much faster than rebuild!
```

**Rebuilding single component:**
```bash
docker build -t local/webui:latest -f Dockerfile.webui .
kind load docker-image local/webui:latest --name kind-5gs
kubectl rollout restart deployment/webui -n open5gs
```

**Complete teardown:**
```bash
./cleanup.sh
kind delete cluster --name kind-5gs
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

---

## Troubleshooting

### Pods Not Starting

Check pod status:
```bash
kubectl get pods -n open5gs
kubectl describe pod -n open5gs <pod-name>
```

Common issues:
- Image pull errors: Ensure images are loaded with `kind load docker-image`
- Port conflicts: Check if another pod is using the same port
- Resource limits: Ensure sufficient CPU/memory

### UE Registration Failing

Check authentication chain:
```bash
kubectl logs -n open5gs deployment/amf --tail=100
kubectl logs -n open5gs deployment/ausf --tail=100
kubectl logs -n open5gs deployment/udm --tail=100
```

Verify subscriber exists in MongoDB:
```bash
kubectl exec -n open5gs deployment/mongodb -- mongosh open5gs --eval "db.subscribers.find()"
```

### PDU Session Establishment Failing

Check PFCP association:
```bash
kubectl logs -n open5gs deployment/smf --tail=50 | grep PFCP
kubectl logs -n open5gs deployment/upf --tail=50 | grep PFCP
```

Expected: `PFCP associated [IP]:8805`

If "No associated UPF" error:
- Restart UPF: `kubectl rollout restart deployment/upf -n open5gs`
- Wait 30 seconds for PFCP association
- Restart UERANSIM: `kubectl rollout restart deployment/ueransim-gnb -n open5gs`

### Service Discovery Issues

Check NRF logs:
```bash
kubectl logs -n open5gs deployment/nrf --tail=100
```

All NFs should register with NRF using FQDN format:
- `amf.open5gs.svc.cluster.local:7777`
- `smf.open5gs.svc.cluster.local:7777`
- etc.

Verify services:
```bash
kubectl get svc -n open5gs
```

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
## Status
🚧 Work in progress
