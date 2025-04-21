#!/bin/bash

# Load utility functions
if ! grep -q "source \"$(dirname \"$0\")/utility.sh\"" "$0"; then
    source "$(dirname "$0")/utility.sh"
fi

if ! grep -q "source \"$(dirname \"$0\")/prechecks.sh\"" "$0"; then
    source "$(dirname "$0")/prechecks.sh"
fi

if ! grep -q "source \"$(dirname \"$0\")/vminfo.sh\"" "$0"; then
    source "$(dirname "$0")/vminfo.sh"
fi

if ! grep -q "source \"$(dirname \"$0\")/pinning.sh\"" "$0"; then
    source "$(dirname "$0")/pinning.sh"
fi

if ! grep -q "source \"$(dirname \"$0\")/run_iperf3.sh\"" "$0"; then
    source "$(dirname "$0")/run_iperf3.sh"
fi

if ! grep -q "source \"$(dirname \"$0\")/config.sh\"" "$0"; then
    source "$(dirname "$0")/config.sh"
fi

RESULT_FILE="/tmp/iperf3_client_results.txt"  # File to save iperf3 results
# Function to run all steps for a given configuration
run_for_configuration() {
    local vm1_vcpus=$1
    local vm1_vhost=$2
    local vm2_vcpus=$3
    local vm2_vhost=$4
    local num_vcpus=$5
    local iteration=$6

    # Create the base directory if it does not exist
    local base_dir="/tmp/iperf_report"
    if [ ! -d "$base_dir" ]; then
        mkdir -p "$base_dir"
    fi

    # Create the configuration directory if it does not exist
    local config_dir="${base_dir}/vm1_${vm1_vcpus}_${vm1_vhost}_vm2_${vm1_vcpus}_${vm2_vhost}"
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
    fi

    # Create the num_vcpus directory if it does not exist
    local vcpu_dir="${config_dir}/${num_vcpus}"
    if [ ! -d "$vcpu_dir" ]; then
        mkdir -p "$vcpu_dir"
    fi

    # File to save results
    local result_file_name="${vcpu_dir}/${iteration}.txt"

    log_step "Pinning threads for configuration: VM1 vCPUs=$vm1_vcpus, VM1 vHost=$vm1_vhost, VM2 vCPUs=$vm2_vcpus, VM2 vHost=$vm2_vhost"
    pin_vm_threads "$vm1_vcpus" "$vm1_vhost" "$vm2_vcpus" "$vm2_vhost"

    log_step "Running iperf3 test"
    run_iperf3_test

    # Save results to the file
    cp "$RESULT_FILE" "$result_file_name"
    echo "Results for configuration $vm1_vcpus $vm1_vhost $vm2_vcpus $vm2_vhost with $num_vcpus vCPUs and iteration $iteration saved to $result_file_name"
}

# Function to run all steps for a given configuration
run_with_perf_for_configuration() {
    local vm1_vcpus=$1
    local vm1_vhost=$2
    local vm2_vcpus=$3
    local vm2_vhost=$4
    local ENABLE_SIBLING_PINNING=$5
    local num_vcpus=$6
    log_step "Pinning threads for configuration: VM1 vCPUs=$vm1_vcpus, VM1 vHost=$vm1_vhost, VM2 vCPUs=$vm2_vcpus, VM2 vHost=$vm2_vhost"
    pin_vm_threads "$vm1_vcpus" "$vm1_vhost" "$vm2_vcpus" "$vm2_vhost" "$ENABLE_SIBLING_PINNING"

    log_step "Running iperf3 test"
    run_iperf3_test

    # Save iperf3 results to a file named after the configuration
    local result_file_name="/tmp/iperf3_results_${vm1_vcpus}_${vm1_vhost}_${vm2_vcpus}_${vm2_vhost}_${num_vcpus}_${ENABLE_SIBLING_PINNING}.txt"
    cp "$RESULT_FILE" "$result_file_name"
    echo "Results for configuration $vm1_vcpus $vm1_vhost $vm2_vcpus $vm2_vhost with $num_vcpus vCPUs saved to $result_file_name"

    log_step "Running perf stat recording"
    local perf_result_file_name="/tmp/iperf3_results_${vm1_vcpus}_${vm1_vhost}_${vm2_vcpus}_${vm2_vhost}_${num_vcpus}_{ENABLE_SIBLING_PINNING}_perf.txt"
       
    local vm2_pid
    vm2_pid=$(get_vm_info "vm2" "pid")

    if [ -z "$vm2_pid" ]; then
        echo "Failed to retrieve QEMU PID for VM2"
        return 1
    fi
    # Run perf stat for PERF_RECORD_TIME seconds 
    sudo perf stat -e cache-references,cache-misses,L1-dcache-loads,L1-dcache-load-misses,L1-icache-load-misses,LLC-loads,LLC-load-misses,dTLB-loads,dTLB-load-misses -p $vm2_pid -- sleep $PERF_RECORD_TIME > "$perf_result_file_name" 2>&1
    echo "Perf results for configuration $vm1_vcpus $vm1_vhost $vm2_vcpus $vm2_vhost with $num_vcpus vCPUs saved to $perf_result_file_name"
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
        read -r vm1_vcpus vm1_vhost vm2_vcpus vm2_vhost enable_sibling_pinning <<< "$config"
        local new_config=()
        for core in "$vm1_vcpus" "$vm1_vhost" "$vm2_vcpus" "$vm2_vhost"; do
            if [ "$core" -lt 0 ]; then
                local online_cpus
                online_cpus=$(cat /sys/devices/system/cpu/online)
                new_config+=("$online_cpus")
                echo "Core $core is negative, using all online CPUs: $online_cpus"
            else
                if (( base_core < 0 )); then
                    echo "Error: base_core ($base_core) is negative."
                    exit 1
                fi
                local adjusted_core=$((base_core + core))
                new_config+=("$adjusted_core")
            fi
        done
        generated_configs+=("${new_config[*]} $enable_sibling_pinning")
        echo "Generated configuration: ${new_config[*]}"
    done
    CONFIGURATIONS=("${generated_configs[@]}")
}



# Function to execute the main logic
run_iperf3_measurements() {
    log_step "Running prechecks"
    check_smt_and_isolated_cores
    check_host_dependencies
    rm -rf /tmp/iperf_report*
    log_step "Generating configurations based on isolated cores"
    generate_configurations
    # Setup passwordless SSH to CVM
    setup_passwordless_ssh "$cvm_ip" "$cvm_username" "$cvm_password" 
    # Main execution loop
    populate_vminfo
    for num_vcpus in "${NUM_VCPU[@]}"; do
        log_step "Updating VM with $num_vcpus vCPUs"
        vm_update "$num_vcpus"

        for config in "${CONFIGURATIONS[@]}"; do
            log_step "Processing configuration: $config"
            #populate_vminfo
            for iteration in {1..5}; do
                vm_off
                vm_on
                run_for_configuration $config "$num_vcpus" "$iteration" "on"
                vm_off
                vm_on
                run_for_configuration $config "$num_vcpus" "$iteration" "off"
            done
            run_with_perf_for_configuration $config "$num_vcpus" 
        done
    done

    log_step "All configurations processed successfully."
}
run_iperf3_measurements
log_step "All configurations processed successfully."