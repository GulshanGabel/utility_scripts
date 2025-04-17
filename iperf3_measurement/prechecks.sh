#!/bin/bash
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/utility.sh"

log_step "Starting prechecks script"

check_isolated_cores() {
    log_step "Checking isolated cores"
    if [ -f /sys/devices/system/cpu/isolated ]; then
        isolated_cores=$(cat /sys/devices/system/cpu/isolated)
        if [ -n "$isolated_cores" ]; then
            echo "Isolated CPU cores: $isolated_cores"
            return 0
        else
            echo "No CPU cores are isolated."
            return 1
        fi
    else
        echo "The /sys/devices/system/cpu/isolated file does not exist. Unable to check isolated cores."
        return 2
    fi
}

check_smt_enabled() {
    log_step "Checking SMT status"
    if [ -f /sys/devices/system/cpu/smt/active ]; then
        smt_status=$(cat /sys/devices/system/cpu/smt/active)
        if [ "$smt_status" -eq 1 ]; then
            echo "SMT is enabled: Yes"
            return 0
        else
            echo "SMT is enabled: No"
            return 1
        fi
    else
        echo "The /sys/devices/system/cpu/smt/active file does not exist. Unable to check SMT status."
        return 2
    fi
}

check_smt_and_isolated_cores() {
    log_step "Checking SMT and isolated cores"
    check_smt_enabled
    smt_status=$?
    if [ "$smt_status" -eq 0 ]; then
        echo "SMT is enabled. Proceeding to check isolated cores."
        check_isolated_cores
        isolated_status=$?
        if [ "$isolated_status" -eq 0 ]; then
            IFS=',' read -ra isolated_ranges <<< "$isolated_cores"
            isolated_list=()
            for range in "${isolated_ranges[@]}"; do
                if [[ "$range" == *"-"* ]]; then
                    start=${range%-*}
                    end=${range#*-}
                    for ((i=start; i<=end; i++)); do
                        isolated_list+=("$i")
                    done
                else
                    isolated_list+=("$range")
                fi
            done

            for core in "${isolated_list[@]}"; do
                siblings=$(cat /sys/devices/system/cpu/cpu"$core"/topology/thread_siblings_list)
                IFS=',' read -ra sibling_list <<< "$siblings"
                for sibling in "${sibling_list[@]}"; do
                    if [[ ! " ${isolated_list[*]} " =~ " $sibling " ]]; then
                        echo "SMT is enabled, but siblings are not isolated for core $core."
                        return 1
                    fi
                done
            done
            echo "All isolated cores are properly isolated with their siblings. System is configured correctly."
            return 0
        else
            echo "Failed to verify isolated cores."
            return 1
        fi
    else
        echo "SMT is not enabled. No need to check isolated cores. System is configured correctly."
        return 0
    fi
}