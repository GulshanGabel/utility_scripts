#!/bin/bash

# Load utility functions
source "$(dirname "$0")/utility.sh"
source "$(dirname "$0")/prechecks.sh"
source "$(dirname "$0")/vminfo.sh"
source "$(dirname "$0")/pinning.sh"
source "$(dirname "$0")/run_iperf3.sh"

RESULT_FILE="/tmp/iperf3_client_results.txt"  # File to save iperf3 results

# Configurations for pinning
CONFIGURATIONS=(
    "8 8 12 12"
    "8 16 12 17"
    "8 12 16 20"
)

# Function to run all steps for a given configuration
run_for_configuration() {
    local vm1_vcpus=$1
    local vm1_vhost=$2
    local vm2_vcpus=$3
    local vm2_vhost=$4



    log_step "Pinning threads for configuration: VM1 vCPUs=$vm1_vcpus, VM1 vHost=$vm1_vhost, VM2 vCPUs=$vm2_vcpus, VM2 vHost=$vm2_vhost"
    pin_vm_threads "$vm1_vcpus" "$vm1_vhost" "$vm2_vcpus" "$vm2_vhost"

    log_step "Running iperf3 test"
    run_iperf3_test

    # Save results to a file named after the configuration
    local result_file_name="/tmp/iperf3_results_${vm1_vcpus}_${vm1_vhost}_${vm2_vcpus}_${vm2_vhost}.txt"
    cp "$RESULT_FILE" "$result_file_name"
    echo "Results for configuration $vm1_vcpus $vm1_vhost $vm2_vcpus $vm2_vhost saved to $result_file_name"
}

    log_step "Running prechecks"
    check_smt_and_isolated_cores
    check_host_dependencies
    get_vm_info
# Main execution loop
for config in "${CONFIGURATIONS[@]}"; do
    log_step "Processing configuration: $config"
    run_for_configuration $config
done

log_step "All configurations processed successfully."