#!/bin/bash

source "$(dirname "$0")/config.sh"

log_step() {
    echo "========== $1 =========="
}

# Function to check if all host dependencies are installed
check_host_dependencies() {
    log_step "Checking host dependencies"
    for dep in "${HOST_DEPENDENCIES[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo "Error: $dep is not installed on the host. Please install it manually."
            exit 1
        fi
    done
}

# Function to check if all VM dependencies are installed
check_vm_dependencies() {
    log_step "Checking VM dependencies"
    local vm_ip=$1
    local vm_user=$2
    local vm_password=$3

    for dep in "${VM_DEPENDENCIES[@]}"; do
        version=$(sshpass -p "$vm_password" ssh -o StrictHostKeyChecking=no "$vm_user@$vm_ip" "$dep --version" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        if [[ -z "$version" ]]; then
            echo "Error: $dep is not installed on the VM ($vm_ip). Please install it manually."
            exit 1
        fi

        # Check for version > 3.16
        if [[ "$dep" == "iperf3" && "$(printf '%s\n' "$version" "3.16" | sort -V | head -n1)" == "3.16" ]]; then
            echo "Error: $dep version on VM ($vm_ip) is $version. Version > 3.16 is required."
            exit 1
        fi
    done
}

setup_passwordless_ssh() {
    log_step "Setting up passwordless SSH"
    local host_ip=$1
    local username=$2
    local password=$3

    # Check if passwordless SSH is already set up
    if ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no "$username@$host_ip" "exit" &>/dev/null; then
        return
    fi

    # Generate SSH key if not already present
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa &>/dev/null
    fi

    # Copy SSH key to the remote host
    if ! sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no "$username@$host_ip" &>/dev/null; then
        echo "Error: Failed to set up passwordless SSH for $username@$host_ip"
        exit 1
    fi
}

get_vm_info() {
    local vm=$1
    local attribute=$2
    local vminfo_file="/tmp/vminfo"

    # Check if vminfo file exists
    if [ ! -f "$vminfo_file" ]; then
        echo "Error: vminfo file not found at $vminfo_file"
        exit 1
    fi

    case $attribute in
        name)
            grep "^${vm}_name=" "$vminfo_file" | cut -d'=' -f2
            ;;
        uuid)
            grep "^${vm}_uuid=" "$vminfo_file" | cut -d'=' -f2
            ;;
        ip)
            grep "^${vm}_ip=" "$vminfo_file" | cut -d'=' -f2
            ;;
        host_ip)
            grep "^${vm}_host_ip=" "$vminfo_file" | cut -d'=' -f2
            ;;
        pid)
            local uuid
            uuid=$(get_vm_info "$vm" "uuid")
            if [ -z "$uuid" ]; then
                echo "Error: UUID not found for $vm"
                exit 1
            fi
            # Get the VM PID using the UUID
            ps -ax | grep qemu | grep -w "$uuid" | grep -v grep | awk '{print $1}'
            ;;
        vcpu_pid)
            local pid
            pid=$(get_vm_info "$vm" "pid")
            if [ -z "$pid" ]; then
                echo "Error: PID not found for $vm"
                exit 1
            fi
            # Get the VCPU thread IDs
            ps -eL -o ppid,pid,lwp,psr,comm | grep "$pid" | grep -E "CPU [0-9]+/KVM" | awk '{print $3}'
            ;;
        vhost_pid)
            local pid
            pid=$(get_vm_info "$vm" "pid")
            if [ -z "$pid" ]; then
                echo "Error: PID not found for $vm"
                exit 1
            fi
            # Get the vhost process ID
            ps -eL -o ppid,pid,lwp,psr,comm | grep "$pid" | grep -E "vhost" | awk '{print $3}'
            ;;
        num_vcpus)
            local vcpu_pids
            vcpu_pids=$(get_vm_info "$vm" "vcpu_pid")
            if [ -z "$vcpu_pids" ]; then
                echo "Error: No VCPU PIDs found for $vm"
                exit 1
            fi
            # Count the number of VCPU PIDs
            echo "$vcpu_pids" | wc -l
            ;;
        *)
            echo "Error: Invalid attribute '$attribute'"
            exit 1
            ;;
    esac
}

# Function to log in to CVM and start VMs
vm_on() {
    ssh "$cvm_username@$cvm_ip" "source /etc/profile && acli vm.on vm1 && acli vm.on vm2"
}

# Function to log in to CVM and power off VMs
vm_off() {
    ssh "$cvm_username@$cvm_ip" "source /etc/profile && acli vm.on vm1 && acli vm.off vm2"
}

# Function to update the number of vCPUs for a VM
vm_update() {
    local num_vcpus=$1
    if [[ -z "$num_vcpus" ]]; then
        echo "Error: num_vcpus argument is required."
        return 1
    fi

    vm_off
    ssh "$cvm_username@$cvm_ip" "source /etc/profile && acli vm.update vm1 num_vcpus=$num_vcpus"
    vm_on
}