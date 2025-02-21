#!/usr/bin/env bash
# Remove the host UUID
if sudo rm /etc/machine-id; then
    echo "Removed /etc/machine-id"
else
    echo "Failed to remove /etc/machine-id"
fi

# Generate new host UUID
if sudo dbus-uuidgen --ensure=/etc/machine-id; then
    echo "Created new /etc/machine-id"
else
    echo "Failed to create /etc/machine-id"
fi

# Disable IPv6
if sudo sh -c 'echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf'; then
    if sudo sysctl -p; then
        echo "Disabled ipv6"
    fi
else
    echo "Failed to disable ipv6"
fi

# Remove default cloud configuration
if sudo rm /etc/netplan/50-cloud-init.yaml; then
    if sudo sh -c 'echo "network: {config: disabled}" >> /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg'; then
        echo "Removed default IP config"
    fi
else
    echo "Failed to remove default IP config"
fi

# Find available IP address
for IP_HOST in {181..253}; do
    PING_COUNT=0
    for attempt in {1..4}; do
        if ping -c 1 -W 1 192.168.1.$IP_HOST &>/dev/null; then
            break
        fi
        PING_COUNT=$((PING_COUNT + 1))
    done

    if [[ $PING_COUNT -eq 4 ]]; then
        IP_ADDR=192.168.1.$IP_HOST
        echo "Found $IP_ADDR available."
        break
    fi
done

# Define static IP address in netplan yaml
if sudo tee /etc/netplan/00-ens18.yaml > /dev/null << EOF
network:
    ethernets:
        ens18:
            addresses:
            - $IP_ADDR/24
            nameservers:
                addresses:
                - 192.168.1.121
                search:
                - simptum.net
            routes:
            -   to: default
                via: 192.168.1.254
    version: 2
EOF
then
    if sudo netplan apply; then
        echo "Configured IP $IP_ADDR on ens18"
    fi
else
    echo "Failed to configure IP"
fi

# Reconfigure SSH
if sudo rm -f /etc/ssh/ssh_host_*; then
    echo "Removed old host keys"
    if sudo dpkg-reconfigure openssh-server; then
        echo "Generated new host keys"
    else
        echo "Failed to reconfigure sshd"
    fi
else
    echo "Failed to remove SSH host keys"
fi

# Copy public keys to VM
if tee /home/simptum/.ssh/authorized_keys > /dev/null << EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINyMtSrYbNsC0RgzX+onV8potZ2exgJ9B1Yi+aVlHdm5 simptum@fedora
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItLvOa1bY0OHt0HKuR/ynon30+8l8t7Y/c5Ni9Am3ok simptum@CentOS
EOF
then
    echo "Succesfully copied public SSH keys"
else
    echo "Failed to copy public SSH keys"
fi
