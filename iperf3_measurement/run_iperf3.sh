#!/bin/bash

# Load utility functions
if ! grep -q "source \"$(dirname \"$0\")/utility.sh\"" "$0"; then
    source "$(dirname "$0")/utility.sh"
fi

if ! grep -q "source \"$(dirname \"$0\")/config.sh\"" "$0"; then
    source "$(dirname "$0")/config.sh"
fi

# Global variables for iperf3 parameters
RESULT_FILE="/tmp/iperf3_client_results.txt"  # File to save iperf3 results

# Function to perform iperf3 test
run_iperf3_test() {
    vm1_ip=$(get_vm_info vm1 ip)
    vm2_ip=$(get_vm_info vm2 ip)
    vm2_num_vcpu=$(get_vm_info vm2 num_vcpus)
    # Start iperf3 server on VM1
    echo "Starting iperf3 server on VM1 ($vm1_ip)..."
    ssh root@"$vm1_ip" "service firewalld stop &> /dev/null && iperf3 -s -D" 
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start iperf3 server on VM1 ($vm1_ip)."
        exit 1
    fi

    # Run iperf3 client on VM2 and save results to a file
    echo "Running iperf3 client on VM2 ($vm2_ip) targeting server VM1 ($vm1_ip)..."
    ssh root@"$vm2_ip" "service firewalld stop &> /dev/null && iperf3 -c $vm1_ip -t $IPERF_TIME -P $vm2_num_vcpu" > "$RESULT_FILE"
    echo "iperf3 client results saved to $RESULT_FILE"

    # Stop iperf3 server on VM1
    echo "Stopping iperf3 server on VM1 ($vm1_ip)..."
    ssh root@"$vm1_ip" "pkill -f 'iperf3 -s'" &> /dev/null
}
