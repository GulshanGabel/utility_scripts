#!/bin/bash
source "$(dirname "$0")/config.sh"

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

# Function to pin vCPU and vhost threads for VM1 and VM2
pin_vm_threads() {
    local vm1_core_start=$1
    local vm1_vhost_core=$2
    local vm2_core_start=$3
    local vm2_vhost_core=$4
    local ENABLE_SIBLING_PINNING=${5:-"off"}
    # Probe for vCPU and vhost threads for VM1
    local VM1_VCPU_THREADS=($(get_vm_info vm1 vcpu_pid))
    local VM1_VHOST_THREADS=($(get_vm_info vm1 vhost_pid))

    # Probe for vCPU and vhost threads for VM2
    local VM2_VCPU_THREADS=($(get_vm_info vm2 vcpu_pid))
    local VM2_VHOST_THREADS=($(get_vm_info vm2 vhost_pid))
    
    # Check if vm1_core_start is a range
    if [[ "$vm1_core_start" == *-* ]]; then
        for tid in "${VM1_VCPU_THREADS[@]}"; do
            echo "Pinning VM1 vCPU thread $tid to core range $vm1_core_start"
            pin_threads_to_core "$vm1_core_start" "$tid"
        done
    else
        if [[ "$ENABLE_SIBLING_PINNING" == "on" ]]; then
            # Pin VM1 vCPU threads to cores and their hyperthreading siblings
            local core=$vm1_core_start
            for ((i = 0; i < ${#VM1_VCPU_THREADS[@]}; i += 2)); do
                local tid1=${VM1_VCPU_THREADS[$i]}
                local tid2=${VM1_VCPU_THREADS[$((i + 1))]}

                # Pin first thread to the core
                echo "Pinning VM1 vCPU thread $tid1 to core $core"
                pin_threads_to_core "$core" "$tid1"

                # Find the sibling core using sysfs
                local sibling_core
                sibling_core=$(cat /sys/devices/system/cpu/cpu"$core"/topology/thread_siblings_list | cut -d',' -f2)
                if [[ -n "$sibling_core" && -n "$tid2" ]]; then
                    # Pin second thread to the hyperthreading sibling of the core
                    echo "Pinning VM1 vCPU thread $tid2 to sibling core $sibling_core"
                    pin_threads_to_core "$sibling_core" "$tid2"
                fi

                # Move to the next core
                core=$((core + 1))
            done
        else
            # Pin VM1 vCPU threads serially starting from vm1_core_start
            local core=$vm1_core_start
            for tid in "${VM1_VCPU_THREADS[@]}"; do
                echo "Pinning VM1 vCPU thread $tid to core $core"
                pin_threads_to_core "$core" "$tid"
                core=$((core + 1))
            done
        fi
    fi

    # Pin VM1 vhost threads to vm1_vhost_core
    for tid in "${VM1_VHOST_THREADS[@]}"; do
        echo "Pinning VM1 vhost thread $tid to core $vm1_vhost_core"
        pin_threads_to_core "$vm1_vhost_core" "$tid"
    done

    # Check if vm2_core_start is a range
    if [[ "$vm2_core_start" == *-* ]]; then
        for tid in "${VM2_VCPU_THREADS[@]}"; do
            pin_threads_to_core "$vm2_core_start" "$tid"
        done
    else
        if [[ "$ENABLE_SIBLING_PINNING" == "on" ]]; then
            # Pin VM2 vCPU threads to cores and their hyperthreading siblings
            local core=$vm2_core_start
            for ((i = 0; i < ${#VM2_VCPU_THREADS[@]}; i += 2)); do
                local tid1=${VM2_VCPU_THREADS[$i]}
                local tid2=${VM2_VCPU_THREADS[$((i + 1))]}

                # Pin first thread to the core
                echo "Pinning VM2 vCPU thread $tid1 to core $core"
                pin_threads_to_core "$core" "$tid1"

                # Find the sibling core using sysfs
                local sibling_core
                sibling_core=$(cat /sys/devices/system/cpu/cpu"$core"/topology/thread_siblings_list | cut -d',' -f2)
                if [[ -n "$sibling_core" && -n "$tid2" ]]; then
                    # Pin second thread to the hyperthreading sibling of the core
                    echo "Pinning VM2 vCPU thread $tid2 to sibling core $sibling_core"
                    pin_threads_to_core "$sibling_core" "$tid2"
                fi

                # Move to the next core
                core=$((core + 1))
            done
        else
            # Pin VM2 vCPU threads serially starting from vm2_core_start
            local core=$vm2_core_start
            for tid in "${VM2_VCPU_THREADS[@]}"; do
                echo "Pinning VM2 vCPU thread $tid to core $core"
                pin_threads_to_core "$core" "$tid"
                core=$((core + 1))
            done
        fi
    fi

    # Pin VM2 vhost threads to vm2_vhost_core
    for tid in "${VM2_VHOST_THREADS[@]}"; do
        echo "Pinning VM2 vhost thread $tid to core $vm2_vhost_core"
        pin_threads_to_core "$vm2_vhost_core" "$tid"
    done
}
# Example usage:

# pin_vm_threads 0 0 4 4
# pin_threads_to_core 2 1234 5678

