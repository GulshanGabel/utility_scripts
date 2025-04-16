#!/bin/bash

# Load utility functions
source "$(dirname "$0")/utility.sh"

# Global variables for iperf3 parameters
IPERF_TIME=30  # Duration of the test in seconds
IPERF_PARALLEL=4  # Number of parallel streams
RESULT_FILE="/tmp/iperf3_client_results.txt"  # File to save iperf3 results

# Function to perform iperf3 test
run_iperf3_test() {
    # Parse VM UUIDs from vminfo file
    # Extract IP addresses of VMs directly from vminfo file
    vm1_ip=$(grep "^vm1_ip=" /tmp/vminfo | cut -d'=' -f2)
    vm2_ip=$(grep "^vm2_ip=" /tmp/vminfo | cut -d'=' -f2)

    # Check if passwordless SSH is set up for VM1
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 root@"$vm1_ip" "exit" 2>/dev/null; then
        echo "Passwordless SSH not set up for VM1. Setting it up..."
        setup_passwordless_ssh "$vm1_ip" "root" "nutanix/4u"
    fi

    # Check if passwordless SSH is set up for VM2
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 root@"$vm2_ip" "exit" 2>/dev/null; then
        echo "Passwordless SSH not set up for VM2. Setting it up..."
        setup_passwordless_ssh "$vm2_ip" "root" "nutanix/4u"
    fi

    # Start iperf3 server on VM1
    echo "Starting iperf3 server on VM1 ($vm1_ip)..."
    ssh root@"$vm1_ip" "service firewalld stop && iperf3 -s -D"

    # Run iperf3 client on VM2 and save results to a file
    echo "Running iperf3 client on VM2 ($vm2_ip) targeting server VM1 ($vm1_ip)..."
    ssh root@"$vm2_ip" "service firewalld stop && iperf3 -c $vm1_ip -t $IPERF_TIME -P $IPERF_PARALLEL" > "$RESULT_FILE"
    echo "iperf3 client results saved to $RESULT_FILE"

    # Stop iperf3 server on VM1
    echo "Stopping iperf3 server on VM1 ($vm1_ip)..."
    ssh root@"$vm1_ip" "pkill -f 'iperf3 -s'"
}

# Call the function
run_iperf3_test