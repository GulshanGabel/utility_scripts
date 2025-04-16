#!/bin/bash

# Load utility functions
source "$(dirname "$0")/utility.sh"
source "$(dirname "$0")/prechecks.sh"
source "$(dirname "$0")/vminfo.sh"
source "$(dirname "$0")/pinning.sh"
source "$(dirname "$0")/run_iperf3.sh"

RESULT_FILE="/tmp/iperf3_client_results.txt"  # File to save iperf3 results
REQUIRED_ISOLATED_CORES=8
# Configurations for pinning
CONFIGURATIONS=(
    "0 3 4 7" #same ccx
    "0 8 4 9" #Both vm's vpcu same ccx, both vhost same ccx, but vhosts and vcpus on different ccx
    "0 4 8 4" #vcpus and vhosts per vm on same ccx, but each vcpus and vhosts on different ccx
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

# Function to determine configurations based on isolated cores
generate_configurations() {
    # Read the base core from the sys interface
    local base_core
    if [[ -f "/sys/devices/system/cpu/isolated" ]]; then
        base_core=$(cut -d',' -f1 < /sys/devices/system/cpu/isolated | cut -d'-' -f1)
        if [[ -z "$base_core" || ! "$base_core" =~ ^[0-9]+$ ]]; then
            echo "Error: Unable to determine base core from /sys/devices/system/cpu/isolated."
            exit 1
        fi
    else
        echo "Error: /sys/devices/system/cpu/isolated does not exist."
        exit 1
    fi

    echo "Base core: $base_core"
    local generated_configs=()
    for config in "${CONFIGURATIONS[@]}"; do
        # Split the configuration into four separate numbers
        read -r vm1_vcpus vm1_vhost vm2_vcpus vm2_vhost <<< "$config"
        local new_config=()
        for core in "$vm1_vcpus" "$vm1_vhost" "$vm2_vcpus" "$vm2_vhost"; do
            if (( base_core < 0 || core < 0 )); then
                echo "Error: base_core ($base_core) or core ($core) is negative."
                exit 1
            fi
            local adjusted_core=$((base_core + core))
            new_config+=("$adjusted_core")
        done
        generated_configs+=("${new_config[*]}")
    echo "Generated configuration: ${new_config[*]}"
    done
    CONFIGURATIONS=("${generated_configs[@]}")
}

# Function to execute the main logic
run_iperf3_measurements() {
    log_step "Running prechecks"
    check_smt_and_isolated_cores
    check_host_dependencies
#    get_vm_info

    log_step "Generating configurations based on isolated cores"
    generate_configurations

    # Main execution loop
    for config in "${CONFIGURATIONS[@]}"; do
        log_step "Processing configuration: $config"
#        run_for_configuration $config
    done

    log_step "All configurations processed successfully."
}
run_iperf3_measurements
log_step "All configurations processed successfully."