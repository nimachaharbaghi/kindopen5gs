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
⚠️ Troubleshooting the Subscriber Addition
If the open5gs-dbctl command fails, it is usually due to one of these three common Kubernetes/Docker issues:

ImagePullBackOff / ErrImagePull: Kind cannot find the image. (Fix: Run kind load docker-image local/open5gs:latest --name kind-5gs).

StartError (stat /bin/... no such file): The path to the script inside your specific Docker image is different.

timed out waiting for the condition: The pod started, but the script hung because it couldn't find a MongoDB client (mongosh) inside the container.

Solution: Direct Database Injection If you encounter any of the above, bypass the helper script and inject the subscriber directly into MongoDB:

```bash
kubectl exec -it -n open5gs deployment/mongodb -- mongosh open5gs --eval '
db.subscribers.insertOne({
  "imsi": "999700000000001",
  "security": {
    "k": "465B5CE8B199B49FAA5F0A2EE238A6BC",
    "amf": "8000",
    "opc": "E8ED289DEBA952E4283B54E88E6183CA"
  },
  "ambr": { "uplink": { "value": 1, "unit": 3 }, "downlink": { "value": 1, "unit": 3 } },
  "slice": [{
    "sst": 1,
    "default_indicator": true,
    "session": [{ "nssai": { "sst": 1 }, "qos": { "index": 9 }, "dnn": "internet" }]
  }],
  "access_restriction_data": 32,
  "subscriber_status": 0,
  "network_access_mode": 0
})'
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
first see the availble nodes with:
```bash
kubectl get all -n monitoring
```
there should be a similar output:

```
NAME                                                         READY   STATUS    RESTARTS      AGE
pod/alertmanager-kind-prometheus-kube-prome-alertmanager-0   2/2     Running   0             109s
pod/kind-prometheus-grafana-7cd8657994-p5nph                 3/3     Running   0             2m7s
pod/kind-prometheus-kube-prome-operator-5977cd7b87-7kbxl     1/1     Running   0             2m7s
pod/kind-prometheus-kube-state-metrics-f9f7f64bf-qqxvz       1/1     Running   1 (54s ago)   2m7s
pod/kind-prometheus-prometheus-node-exporter-hxnk2           1/1     Running   0             2m7s
pod/prometheus-kind-prometheus-kube-prome-prometheus-0       2/2     Running   0             108s

NAME                                               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
service/alertmanager-operated                      ClusterIP   None            <none>        9093/TCP,9094/TCP,9094/UDP      109s
service/kind-prometheus-grafana                    NodePort    10.96.27.253    <none>        80:31000/TCP                    2m7s
service/kind-prometheus-kube-prome-alertmanager    NodePort    10.96.32.250    <none>        9093:32000/TCP,8080:31127/TCP   2m7s
service/kind-prometheus-kube-prome-operator        ClusterIP   10.96.85.157    <none>        443/TCP                         2m7s
service/kind-prometheus-kube-prome-prometheus      NodePort    10.96.123.199   <none>        9090:30000/TCP,8080:30197/TCP   2m7s
service/kind-prometheus-kube-state-metrics         ClusterIP   10.96.234.250   <none>        8080/TCP                        2m7s
service/kind-prometheus-prometheus-node-exporter   NodePort    10.96.202.206   <none>        9100:32001/TCP                  2m7s
service/prometheus-operated                        ClusterIP   None            <none>        9090/TCP                        108s

NAME                                                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/kind-prometheus-prometheus-node-exporter   1         1         1       1            1           kubernetes.io/os=linux   2m7s

NAME                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/kind-prometheus-grafana               1/1     1            1           2m7s
deployment.apps/kind-prometheus-kube-prome-operator   1/1     1            1           2m7s
deployment.apps/kind-prometheus-kube-state-metrics    1/1     1            1           2m7s

NAME                                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/kind-prometheus-grafana-7cd8657994               1         1         1       2m7s
replicaset.apps/kind-prometheus-kube-prome-operator-5977cd7b87   1         1         1       2m7s
replicaset.apps/kind-prometheus-kube-state-metrics-f9f7f64bf     1         1         1       2m7s

NAME                                                                    READY   AGE
statefulset.apps/alertmanager-kind-prometheus-kube-prome-alertmanager   1/1     109s
statefulset.apps/prometheus-kind-prometheus-kube-prome-prometheus       1/1     108s

```
you can access the web interfaces with this commands and then use(this is only the example):

```bash
kubectl port-forward -n monitoring svc/kind-prometheus-kube-prometheus-prometheus 9090:9090
```


Prometheus: http://localhost:9090/graph

Alertmanager: http://localhost:9093/graph

Grafana: http://<nodeIP>:31000

Grafana Credentials

Use the following credentials to access Grafana:
```
Username: admin

Password: prom-operator
```


---
Next Step  : AI Predictive Analytics 

1. Install Required Libraries

```bash
pip install requests pandas torch matplotlib transformers chronos
```
2. Step A: Metrics Collection (The Python Collector)
We interface directly with the Prometheus HTTP API. The following script queries the container_cpu and container_memory metrics for specific pods over a 3-day window ( example).

Create **collect_amf_metrics.py**:

```bash
import requests
import pandas as pd
from datetime import datetime, timedelta

url = "http://localhost:9090/api/v1/query_range"

# Specifically targeting the AMF (Access and Mobility Management Function)
queries = {
    "amf_cpu": 'sum(rate(container_cpu_usage_seconds_total{namespace="open5gs",pod=~"amf-.*"}[5m]))',
    "amf_memory": 'sum(container_memory_usage_bytes{namespace="open5gs",pod=~"amf-.*"})'
}

# 3 days Metrics
end = datetime.now()
start = end - timedelta(days=3)

for name, query in queries.items():
    params = {
        'query': query,
        'start': start.timestamp(),
        'end': end.timestamp(),
        'step': '1m'
    }

    try:
        response = requests.get(url, params=params).json()
        
        if 'data' in response and response['data']['result'] and len(response['data']['result'][0]['values']) > 0:
            results = response['data']['result'][0]['values']
            df = pd.DataFrame(results, columns=['timestamp', f'{name}_usage'])
            
            # File named exactly like the UPF pattern: 5gc_amf_cpu.csv
            filename = f'5gc_{name}.csv'
            df.to_csv(filename, index=False)
            print(f"Success: {name} data saved to {filename}")
        else:
            print(f"No data found for {name}. Ensure AMF pod is running and port-forward is active.")
    except Exception as e:
        print(f"Error connecting to Prometheus: {e}")

```

==> **Collect_amf_metrics.py** is a telemetry ingestion script designed to gather real-time and historical resource utilization data—specifically CPU usage and Memory consumption—from the Access and Mobility Management Function (AMF). The AMF is a critical Control Plane component in the 5G Core (5GC) responsible for connection and registration management.
Here is the next section for your README, focusing on the expected outputs of the AMF collection and the subsequent prediction process.

3. Expected Output of Collection
Upon successful execution of collect_amf_metrics.py with the command "$ python3 collect_amf_metrics.py, the script serializes the Prometheus time-series data into two structured CSV files. These files serve as the "Ground Truth" for the AI model:

**5gc_amf_cpu.csv**: Contains historical CPU processing rates (cores) sampled every minute.

**5gc_amf_memory.csv**: Contains historical RAM utilization (bytes) sampled every minute.

Data Format Example: | timestamp | amf_cpu_usage | |-----------|---------------| | 1704456000| 0.0452 | | 1704456060| 0.0481 |


4. Resource Forecasting (AI Inference

We utilize the Chronos-T5 (Tiny) foundation model to perform zero-shot time-series forecasting. Unlike traditional RNNs, this model leverages a transformer architecture to treat resource values as "tokens," allowing it to predict 5G patterns without needing per-node training.

Create **amf_predictor.py**: This unified script loads the model once and performs inference on both CPU and Memory datasets to generate a 1-hour (60-minute) predictive horizon.

```bash
import pandas as pd
import torch
import matplotlib.pyplot as plt
import os
from chronos import ChronosPipeline

# Redirect cache to the 20GB disk
os.environ['HF_HOME'] = '/mnt/models/huggingface'

# 1. Load Model (Shared for both tasks)
print("Loading Chronos-T5 Model for AMF Analysis...")
pipeline = ChronosPipeline.from_pretrained(
    "amazon/chronos-t5-tiny",
    device_map="cpu",
    torch_dtype=torch.float32,
)

# 2. Process AMF CPU
print("\n--- Analyzing AMF CPU ---")
df_cpu = pd.read_csv("5gc_amf_cpu.csv")
series_cpu = torch.tensor(df_cpu["amf_cpu_usage"].values, dtype=torch.float32)

print("Performing Inference (1-hour horizon)...")
forecast_cpu = pipeline.predict(series_cpu, prediction_length=60)
mean_cpu = forecast_cpu[0].mean(dim=0)

# Plot CPU
plt.figure(figsize=(12, 6))
plt.plot(df_cpu["amf_cpu_usage"].values[-200:], label="Historical AMF CPU", color="tab:blue")
plt.plot(range(200, 260), mean_cpu.numpy(), label="AI 1-Hour Forecast", color="red", linestyle="--")
plt.title("5G AMF CPU Usage: 1-Hour Predictive Horizon")
plt.xlabel("Time (Minutes)")
plt.ylabel("CPU Usage")
plt.legend()
plt.grid(True, alpha=0.3)
plt.savefig("forecast_amf_cpu_1h.png")
print("SUCCESS: forecast_amf_cpu_1h.png saved.")

# 3. Process AMF Memory
print("\n--- Analyzing AMF Memory ---")
df_mem = pd.read_csv("5gc_amf_memory.csv")
series_mem = torch.tensor(df_mem["amf_memory_usage"].values, dtype=torch.float32)

print("Performing Inference (1-hour horizon)...")
forecast_mem = pipeline.predict(series_mem, prediction_length=60)
mean_mem = forecast_mem[0].mean(dim=0)

# Plot Memory
plt.figure(figsize=(12, 6))
plt.plot(df_mem["amf_memory_usage"].values[-200:], label="Historical AMF RAM", color="tab:green")
plt.plot(range(200, 260), mean_mem.numpy(), label="AI 1-Hour Forecast", color="blue", linestyle="--")
plt.title("5G AMF Memory Usage: 1-Hour Predictive Horizon")
plt.xlabel("Time (Minutes)")
plt.ylabel("Memory Usage")
plt.legend()
plt.grid(True, alpha=0.3)
plt.savefig("forecast_amf_memory_1h.png")
print("SUCCESS: forecast_amf_memory_1h.png saved.")

print("\nAll AMF analysis complete!")
```

5. Final Visual Results
After running the predictor with " $ python3 amf_predictor.py " , the system produces two high-resolution visualizations:

**chronos_amf_cpu_recent.png**: Visualizes the predicted CPU demand surge.

**chronos_amf_memory_recent.png**: Visualizes the memory stability forecast.

We can visualise images with the command : 
" $ xdg-open forecast_amf_memory_1h.png "
<img width="1575" height="669" alt="image" src="https://github.com/user-attachments/assets/07d1a557-6f5e-4cd9-a33e-685835467e44" />



**BONUS : Using TimeGPT Model and comparing with local Chrono Model**  : 

```bash
pip install nixtla
```bash

Then go to : **https://dashboard.nixtla.io/**

You need to sign in with a proffession / university email in order to obtain an API-KEY

Then create **timegpt_amf.py** : 

```bash
import pandas as pd
from nixtla import NixtlaClient
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import os
import warnings

warnings.filterwarnings('ignore')

# 1. Initialize Client with your key
# Ensure the key is exactly as provided with no extra spaces
api_key = ' **YOUR-API-KEY**'
nixtla_client = NixtlaClient(api_key=api_key)

# Verify API Key before running
try:
    if not nixtla_client.validate_api_key():
        print("❌ API Key Rejected by Nixtla. Please check dashboard.nixtla.io")
        exit()
except Exception as e:
    print(f"❌ Authentication failed: {e}")
    exit()

metrics = ['cpu', 'memory']

for metric in metrics:
    file_name = f'5gc_amf_{metric}.csv'
    if not os.path.exists(file_name):
        print(f"⚠️ {file_name} not found.")
        continue
        
    # 2. Preprocess 1-Hour Context
    df = pd.read_csv(file_name)
    df['timestamp'] = pd.to_datetime(df['timestamp'], unit='s')
    
    # Resample to 5-min intervals so 12 steps = 1 hour prediction
    df_clean = df.set_index('timestamp').resample('5min').mean().reset_index().ffill()
    df_context = df_clean.tail(12) # Exactly 1 hour of history
    
    target = next((col for col in df_clean.columns if 'usage' in col), None)

    # 3. Generate 1-Hour Forecast
    print(f"🚀 TimeGPT forecasting AMF {metric.upper()}...")
    try:
        fcst_df = nixtla_client.forecast(
            df=df_context, 
            h=12, 
            time_col='timestamp', 
            target_col=target, 
            freq='5min'
        )
        
        # 4. Professional Visualization
        plt.figure(figsize=(15, 6))
        
        # Plot Actual (Blue)
        plt.plot(df_context['timestamp'], df_context[target], 
                 label='Actual (Last 1h)', color='#1f77b4', marker='o', linewidth=2)
        
        # Plot Prediction (Orange)
        plt.plot(fcst_df['timestamp'], fcst_df['TimeGPT'], 
                 label='TimeGPT Forecast (Next 1h)', color='#ff7f0e', ls='--', marker='x', linewidth=2)
        
        # Separation line at "Now"
        plt.axvline(x=df_context['timestamp'].iloc[-1], color='red', linestyle=':', label='Forecast Start')
        
        # Formatting
        plt.title(f'AMF {metric.upper()} Utilization: 1h History vs 1h Prediction', fontsize=14)
        plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
        plt.grid(True, alpha=0.3)
        plt.legend()
        
        output_file = f'timegpt_amf_{metric}_bonus.png'
        plt.savefig(output_file, dpi=200)
        plt.close()
        print(f"✅ Success! Saved to {output_file}")
        
    except Exception as e:
        print(f"⚠️ Forecast failed for {metric}: {e}")

print("\n🎯 TimeGPT AMF processing finished.")
```

Upon successful execution, the timegpt_amf.py script generates two visual reports: **timegpt_amf_cpu_bonus.png** and **timegpt_amf_memory_bonus.png** . These images show the last 1 hour of actual 5G telemetry followed by a matching 1-hour AI resource forecast."

Finally , Chrono forecast vs TimeGPt comparaison  : 

<img width="1849" height="373" alt="image" src="https://github.com/user-attachments/assets/62306ecb-e6f9-439d-b53b-52ed2e7ea3e1" />


**Observation** :
**Chronos-T5 (Local)**: The local model is very reactive to the most recent data points. Its forecast (red dashed line) tends to follow the immediate trend, which is excellent for detecting sudden, short-term spikes at the network edge.

**TimeGPT (Cloud)** : The cloud-based model produces a much smoother and more generalized forecast (orange dashed line). It is better at "ignoring" minor noise and predicting a stable trend over the full hour.

Infrastructure Trade-off: * Chronos is superior for privacy and latency, as it runs entirely on your local VM without needing an internet connection.

TimeGPT offers a more refined "global" perspective, but requires sending sensitive 5G telemetry to an external cloud API.

Conclustion : 
"While both models accurately predicted that CPU usage would remain low after the initial spike, TimeGPT provided a more stable trend line, whereas the local Chronos-T5 proved to be a highly effective, low-latency alternative for real-time monitoring directly within the 5G cluster."

