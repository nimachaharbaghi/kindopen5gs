#!/bin/bash

# Setup ogstun interface and NAT for UPF
echo "Setting up UPF network..."

# Bring up ogstun interface when it's created by open5gs-upfd
# We'll start the UPF in the background to let it create the interface
/bin/open5gs-upfd -c /opt/open5gs/etc/open5gs/upf.yaml &
UPF_PID=$!

# Wait for ogstun interface to be created
echo "Waiting for ogstun interface..."
for i in {1..30}; do
    if ip link show ogstun &>/dev/null; then
        echo "ogstun interface detected"
        break
    fi
    sleep 1
done

# Bring up the interface
if ip link show ogstun &>/dev/null; then
    ip link set ogstun up
    echo "ogstun interface is up"

    # Add NAT rule for internet access
    iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
    echo "NAT rules configured"
else
    echo "Warning: ogstun interface not found"
fi

# Wait for the UPF process
wait $UPF_PID
