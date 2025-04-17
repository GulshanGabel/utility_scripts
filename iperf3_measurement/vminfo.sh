#!/bin/bash 

# Source the utility.sh file
source "$(dirname "$0")/utility.sh"

populate_vminfo() {
    log_step "Getting VM information"
    local cvm_ip="192.168.5.254"
    local cvm_username="nutanix"
    local cvm_password="RDMCluster.123"
    local vm_user="root"
    local vm_password="nutanix/4u"
    local output_file="/tmp/vminfo"

    # Setup passwordless SSH to CVM
    setup_passwordless_ssh "$cvm_ip" "$cvm_username" "$cvm_password" 

    # Get VM information directly
    vm1_info=$(ssh -o StrictHostKeyChecking=no "$cvm_username@$cvm_ip" "source /etc/profile && ncli vm ls name=vm1")
    vm2_info=$(ssh -o StrictHostKeyChecking=no "$cvm_username@$cvm_ip" "source /etc/profile && ncli vm ls name=vm2")

    # Extract IPs and UUIDs
    vm1_ips=$(echo "$vm1_info" | grep -i 'VM IP Addresses' | awk '{print $NF}')
    vm2_ips=$(echo "$vm2_info" | grep -i 'VM IP Addresses' | awk '{print $NF}')
    vm1_uuid=$(echo "$vm1_info" | grep -i 'UUID' | grep -iv 'Hypervisor Host Uuid' | awk '{print $NF}')
    vm2_uuid=$(echo "$vm2_info" | grep -i 'UUID' | grep -iv 'Hypervisor Host Uuid' | awk '{print $NF}')

    # Extract Hypervisor Host Id for VM
    vm2_host_id=$(echo "$vm2_info" | grep -i 'Hypervisor Host Id' | awk '{print $NF}')
    vm1_host_id=$(echo "$vm1_info" | grep -i 'Hypervisor Host Id' | awk '{print $NF}')

    # Get Hypervisor Address for VM's host
    vm1_host_info=$(ssh -o StrictHostKeyChecking=no "$cvm_username@$cvm_ip" "source /etc/profile && ncli host ls id=$vm2_host_id")
    vm2_host_info=$(ssh -o StrictHostKeyChecking=no "$cvm_username@$cvm_ip" "source /etc/profile && ncli host ls id=$vm2_host_id")
    vm1_host_ip=$(echo "$vm1_host_info" | grep -i 'Hypervisor Address' | awk '{print $NF}') 
    vm2_host_ip=$(echo "$vm2_host_info" | grep -i 'Hypervisor Address' | awk '{print $NF}')

    # Determine reachable IPs and setup passwordless SSH
    vm1_ip=""
    for ip in $vm1_ips; do
        if ping -c 1 "$ip" &>/dev/null; then
            setup_passwordless_ssh "$ip" "$vm_user" "$vm_password"
            vm1_ip="$ip"
            break
        fi
    done
    if [[ -z "$vm1_ip" ]]; then
        echo "Error: None of the IPs for VM1 are reachable via ping."
    fi

    vm2_ip=""
    for ip in $vm2_ips; do
        if ping -c 1 "$ip" &>/dev/null; then
            setup_passwordless_ssh "$ip" "$vm_user" "$vm_password"
            vm2_ip="$ip"
            break
        fi
    done
    if [[ -z "$vm2_ip" ]]; then
        echo "Error: None of the IPs for VM2 are reachable via ping."
    fi

    # Save VM information to the output file
    {
        echo "vm1_name=vm1"
        echo "vm1_ip=$vm1_ip"
        echo "vm1_uuid=$vm1_uuid"
        echo "vm1_host_ip=$vm1_host_ip"
        echo "vm2_name=vm2"
        echo "vm2_ip=$vm2_ip"
        echo "vm2_uuid=$vm2_uuid"
        echo "vm2_host_ip=$vm2_host_ip"
    } > "$output_file"

    # Check VM dependencies for vm1
    if [[ -n "$vm1_ip" ]]; then
        echo "Checking dependencies for VM1 ($vm1_ip)..."
        check_vm_dependencies "$vm1_ip" "$vm_user" "$vm_password"
    else
        echo "Error: Unable to determine the IP address for VM1."
        exit 1
    fi

    # Check VM dependencies for vm2
    if [[ -n "$vm2_ip" ]]; then
        echo "Checking dependencies for VM2 ($vm2_ip)..."
        check_vm_dependencies "$vm2_ip" "$vm_user" "$vm_password"
    else
        echo "Error: Unable to determine the IP address for VM2."
        exit 1
    fi
}

