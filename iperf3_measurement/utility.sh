#!/bin/bash

# Global variables to list all dependencies
HOST_DEPENDENCIES=("sshpass" "ssh" "ssh-keygen" "ssh-copy-id" "ping" "grep" "awk")
VM_DEPENDENCIES=("iperf3")

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
        echo "Passwordless SSH is already set up for $username@$host_ip"
        return
    fi

    # Generate SSH key if not already present
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa >> /dev/null
    fi

    # Copy SSH key to the remote host
    sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no "$username@$host_ip" >> /dev/null
}
