    cvm_ip="192.168.5.254"
    cvm_username="nutanix"
    cvm_password="RDMCluster.123"
    vm_user="root"
    vm_password="nutanix/4u"

    HOST_DEPENDENCIES=(
        "sshpass"
        "ssh"
        "ssh-keygen"
        "ssh-copy-id"
        "ping"
        "grep"
        "awk"
    )

    VM_DEPENDENCIES=(
        "iperf3"
    )

    # Configurations for pinning
    CONFIGURATIONS=(
        "-1 -1 -1 -1" # all cores
        "0 3 4 7"     # same ccx
        "0 8 4 9"     # Both vm's vpcu same ccx, both vhost same ccx, but vhosts and vcpus on different ccx
        "0 4 8 12"    # vcpus and vhosts per vm on same ccx, but each vcpus and vhosts on different ccx
    )

    NUM_VCPU=(
        "1"
        "2"
        "3"
        "4"
    )

    IPERF_TIME=30  # Duration of the test in seconds
    PERF_RECORD_TIME= $IPERF_TIME - 10 # Duration of the perf record in seconds

