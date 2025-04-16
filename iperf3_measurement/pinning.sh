#!/bin/bash

# Function to pin threads to a specified core
pin_threads_to_core() {
    local core=$1
    shift
    for tid in "$@"; do
        taskset -cp "$core" "$tid" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Pinned thread $tid to core $core"
        else
            echo "Failed to pin thread $tid to core $core"
        fi
    done
}

# Function to get QEMU process PIDs for VM1 and VM2 and extract vCPU and vhost threads
get_qemu_pids() {
    local vm1_uuid vm2_uuid
    vm1_uuid=$(grep "^vm1_uuid=" /tmp/vminfo | cut -d'=' -f2)
    vm2_uuid=$(grep "^vm2_uuid=" /tmp/vminfo | cut -d'=' -f2)

    if [ -z "$vm1_uuid" ] || [ -z "$vm2_uuid" ]; then
        echo "Failed to retrieve VM UUIDs from /tmp/vminfo"
        return 1
    fi

    VM1_PID=$(ps -ax | grep qemu | grep -w "$vm1_uuid" | grep -v grep | awk '{print $1}')
    VM2_PID=$(ps -ax | grep qemu | grep -w "$vm2_uuid" | grep -v grep | awk '{print $1}')

    if [ -z "$VM1_PID" ] || [ -z "$VM2_PID" ]; then
        echo "Failed to retrieve QEMU PIDs for VM1 or VM2"
        return 1
    fi

    echo "VM1 PID: $VM1_PID"
    echo "VM2 PID: $VM2_PID"

    # Probe for vCPU and vhost threads for VM1
    VM1_VCPU_THREADS=($(ps -eL -o ppid,pid,lwp,psr,comm | grep "$VM1_PID" | grep -E "CPU [0-9]+/KVM" | awk '{print $3}'))
    VM1_VHOST_THREADS=($(ps -eL -o ppid,pid,lwp,psr,comm | grep "$VM1_PID" | grep -E "vhost" | awk '{print $3}'))

    # Probe for vCPU and vhost threads for VM2
    VM2_VCPU_THREADS=($(ps -eL -o ppid,pid,lwp,psr,comm | grep "$VM2_PID" | grep -E "CPU [0-9]+/KVM" | awk '{print $3}'))
    VM2_VHOST_THREADS=($(ps -eL -o ppid,pid,lwp,psr,comm | grep "$VM2_PID" | grep -E "vhost" | awk '{print $3}'))

    echo "VM1 vCPU Threads: ${VM1_VCPU_THREADS[@]}"
    echo "VM1 vHost Threads: ${VM1_VHOST_THREADS[@]}"
    echo "VM2 vCPU Threads: ${VM2_VCPU_THREADS[@]}"
    echo "VM2 vHost Threads: ${VM2_VHOST_THREADS[@]}"
}

# Function to pin vCPU and vhost threads for VM1 and VM2
pin_vm_threads() {
    get_qemu_pids
    local vm1_core_start=$1
    local vm1_vhost_core=$2
    local vm2_core_start=$3
    local vm2_vhost_core=$4

    # Check if vm1_core_start is a range
    if [[ "$vm1_core_start" == *-* ]]; then
        for tid in "${VM1_VCPU_THREADS[@]}"; do
            pin_threads_to_core "$vm1_core_start" "$tid"
        done
    else
        # Pin VM1 vCPU threads serially starting from vm1_core_start
        local core=$vm1_core_start
        for tid in "${VM1_VCPU_THREADS[@]}"; do
            pin_threads_to_core "$core" "$tid"
            core=$((core + 1))
        done
    fi

    # Pin VM1 vhost threads to vm1_vhost_core
    for tid in "${VM1_VHOST_THREADS[@]}"; do
        pin_threads_to_core "$vm1_vhost_core" "$tid"
    done

    # Check if vm2_core_start is a range
    if [[ "$vm2_core_start" == *-* ]]; then
        for tid in "${VM2_VCPU_THREADS[@]}"; do
            pin_threads_to_core "$vm2_core_start" "$tid"
        done
    else
        # Pin VM2 vCPU threads serially starting from vm2_core_start
        local core=$vm2_core_start
        for tid in "${VM2_VCPU_THREADS[@]}"; do
            pin_threads_to_core "$core" "$tid"
            core=$((core + 1))
        done
    fi

    # Pin VM2 vhost threads to vm2_vhost_core
    for tid in "${VM2_VHOST_THREADS[@]}"; do
        pin_threads_to_core "$vm2_vhost_core" "$tid"
    done
}
# Example usage:

# pin_vm_threads 0 0 4 4
# pin_threads_to_core 2 1234 5678

