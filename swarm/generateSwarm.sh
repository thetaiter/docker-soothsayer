#!/bin/bash

if [[ "${_}" == "${0}" ]]
then
    printf >&2 "\nThis script must be sourced in order to run properly. Try again with 'source ${0}'.\n\n"
    exit 1
fi

SOURCE_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
CURRENT_DIR="$(pwd)"

LOG_FILE="/tmp/generateSwarm.log"
NUM_MASTERS=1
NUM_NODES=1

if ! [ -z "${1}" ]
then
    NUM_MASTERS=${1}
fi

if ! [ -z ${2} ]
then
    NUM_NODES=${2}
fi

if [ "${NUM_MASTERS}" -lt 1 ]
then
    printf >&2 "\nError: Number of Swarm Masters must be at least 1.\n\n"
    return 2
fi

if [ "${NUM_NODES}" -lt 1 ]
then
    printf >&2 "\nError: Number of Swarm Nodes must be at least 1.\n\n"
    return 3
fi

printf "\nLogging to file ${LOG_FILE}\n\n"

printf "Creating Docker Swarm with ${NUM_MASTERS} Master nodes and ${NUM_NODES} slave nodes...\n" | tee "${LOG_FILE}"

printf "Changing to dir '${SOURCE_DIR}/'...\n" | tee -a "${LOG_FILE}"

cd "${SOURCE_DIR}"
ERR_CODE="${?}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf >&2 "\nThere was an error (${ERR_CODE}) running 'cd \"${SOURCE_DIR}\"'\n\n" | tee -a "${LOG_FILE}"
    return 4
fi

printf "Creating new VM called 'consul' to run Consul discovery service...\n" | tee -a "${LOG_FILE}"

docker-machine create --driver virtualbox consul 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf >&2 "\nThere was an error (${ERR_CODE}) running 'docker-machine create --driver virtualbox consul'\n\n" | tee -a "${LOG_FILE}"
    return 5
fi

export CONSUL_IP="$(docker-machine ip consul)"
printf "\t> CONSUL_IP = ${CONSUL_IP}\n" | tee -a "${LOG_FILE}"

printf "Switching Docker environment to 'consul'...\n" | tee -a "${LOG_FILE}"

eval $(docker-machine env consul)
ERR_CODE="${?}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf >&2 "\nThere was an error (${ERR_CODE}) running 'eval \$(docker-machine env consul)'\n\n" | tee -a "${LOG_FILE}"
    return 6
fi

printf "Running Consul Docker container...\n" | tee -a "${LOG_FILE}"

docker-compose up -d 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf >&2 "\nThere was an error (${ERR_CODE}) running 'docker-compose up -d'\n\n" | tee -a "${LOG_FILE}"
    return 7
fi

printf "Switching back to default (local host machine) Docker environment...\n" | tee -a "${LOG_FILE}"

eval $(docker-machine env -u)
ERR_CODE="${?}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf >&2 "\nThere was an error (${ERR_CODE}) running 'eval \$(docker-machine env -u)'\n\n" | tee -a "${LOG_FILE}"
    return 8
fi

__TITLE="Master"

for i in `seq 0 $((NUM_MASTERS-1))`
do
    printf "Creating new Docker Swarm ${__TITLE} VM called 'swarm-master${i}'...\n" | tee -a "${LOG_FILE}"

    docker-machine create \
	--driver virtualbox \
	--swarm --swarm-master --swarm-opt "replication" \
	--swarm-discovery="consul://${CONSUL_IP}:8500" \
	--engine-opt="cluster-store=consul://${CONSUL_IP}:8500" \
	--engine-opt="cluster-advertise=eth1:2376" \
	swarm-master${i} 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
    ERR_CODE="${PIPESTATUS[0]}"
    if [ "${ERR_CODE}" -ne 0 ]
    then
        cat << EOF | tee -a "${LOG_FILE}"
There was an error (${ERR_CODE}) running the following command:

docker-machine create \\
	--driver virtualbox \\
	--swarm --swarm-master --swarm-opt "replication" \\
        --swarm-discovery="consul://${CONSUL_IP}:8500" \\
        --engine-opt="cluster-store=consul://${CONSUL_IP}:8500" \\
        --engine-opt="cluster-advertise=eth1:2376" \\
        swarm-master${i}

EOF
        return 9
    fi

    export MASTER${i}_IP="$(docker-machine ip swarm-master${i})"
    printf "\t> MASTER${i}_IP = $(eval "echo \${MASTER${i}_IP}")\n" | tee -a "${LOG_FILE}"

    __TITLE="Replica"
done

for i in `seq 0 $((NUM_NODES-1))`
do
    printf "Creating new Docker Swarm node VM called 'swarm-node${i}'...\n" | tee -a "${LOG_FILE}"

    docker-machine create \
	--driver virtualbox \
	--swarm \
        --swarm-discovery="consul://${CONSUL_IP}:8500" \
        --engine-opt="cluster-store=consul://${CONSUL_IP}:8500" \
        --engine-opt="cluster-advertise=eth1:2376" \
        swarm-node${i} 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
    ERR_CODE="${PIPESTATUS[0]}"
    if [ "${ERR_CODE}" -ne 0 ]
    then
        cat << EOF | tee -a "${LOG_FILE}"
There was an error (${ERR_CODE}) running the following command:

docker-machine create \\
        --driver virtualbox \\
        --swarm \\
        --swarm-discovery="consul://${CONSUL_IP}:8500" \\
        --engine-opt="cluster-store=consul://${CONSUL_IP}:8500" \\
        --engine-opt="cluster-advertise=eth1:2376" \\
        swarm-node${i}

EOF
        return 10
    fi

    export NODE${i}_IP="$(docker-machine ip swarm-node${i})"
    printf "\t> NODE${i}_IP = $(eval "echo \${NODE${i}_IP}")\n" | tee -a "${LOG_FILE}"
done

printf "Switching Docker environment to 'swarm-master0'...\n" | tee -a "${LOG_FILE}"

eval $(docker-machine env swarm-master0)
ERR_CODE="${?}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf >&2 "\nThere was an error (${ERR_CODE}) running 'eval \$(docker-machine env swarm-master0)'\n\n" | tee -a "${LOG_FILE}"
    return 11
fi

: << END_MODE

printf "Running the registrator on 'swarm-master0'...\n" | tee -a "${LOG_FILE}"

docker run -d \
	--name=registrator \
	-h "${MASTER_IP}" \
	-v /var/run/docker.sock:/tmp/docker.sock \
	gliderlabs/registrator:latest \
	consul://${CONSUL_IP}:8500 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    cat << EOF | tee -a "${LOG_FILE}"
There was an error (${ERR_CODE}) running the following command:

docker run -d \\
        --name=registrator \\
        -h "${MASTER_IP}" \\
        -v /var/run/docker.sock:/tmp/docker.sock \\
        gliderlabs/registrator:latest \\
        consul://${CONSUL_IP}:8500

EOF
    return 12
fi

printf "Switching Docker environment to 'swarm-master1'...\n" | tee -a "${LOG_FILE}"

eval $(docker-machine env swarm-master1)
ERR_CODE="${?}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'eval \$(docker-machine env swarm-master1)'\n\n" | tee -a "${LOG_FILE}"
    return 13
fi

printf "Running the registrator on 'swarm-master1'...\n" | tee -a "${LOG_FILE}"

docker run -d \
        --name=registrator \
        -h "${REPLICA_IP}" \
        -v /var/run/docker.sock:/tmp/docker.sock \
        gliderlabs/registrator:latest \
        consul://${CONSUL_IP}:8500 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    cat << EOF | tee -a "${LOG_FILE}"
There was an error (${ERR_CODE}) running the following command:

docker run -d \\
        --name=registrator \\
        -h "${REPLICA_IP}" \\
        -v /var/run/docker.sock:/tmp/docker.sock \\
        gliderlabs/registrator:latest \\
        consul://${CONSUL_IP}:8500

EOF
    return 14
fi

printf "Switching Docker environment to 'swarm-node0'...\n" | tee -a "${LOG_FILE}"

eval $(docker-machine env swarm-node0)
ERR_CODE="${?}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'eval \$(docker-machine env swarm-node0)'\n\n" | tee -a "${LOG_FILE}"
    return 15
fi

printf "Running the registrator on 'swarm-node0'...\n" | tee -a "${LOG_FILE}"

docker run -d \
        --name=registrator \
        -h "${NODE0_IP}" \
        -v /var/run/docker.sock:/tmp/docker.sock \
        gliderlabs/registrator:latest \
        consul://${CONSUL_IP}:8500 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    cat << EOF | tee -a "${LOG_FILE}"
There was an error (${ERR_CODE}) running the following command:

docker run -d \\
        --name=registrator \\
        -h "${NODE0_IP}" \\
        -v /var/run/docker.sock:/tmp/docker.sock \\
        gliderlabs/registrator:latest \\
        consul://${CONSUL_IP}:8500

EOF
    return 16
fi

printf "Switching Docker environment to 'swarm-node1'...\n" | tee -a "${LOG_FILE}"

eval $(docker-machine env swarm-node1)
ERR_CODE="${?}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'eval \$(docker-machine env swarm-node1)'\n\n" | tee -a "${LOG_FILE}"
    return 17
fi

printf "Running the registrator on 'swarm-node1'...\n" | tee -a "${LOG_FILE}"

docker run -d \
        --name=registrator \
        -h "${NODE1_IP}" \
        -v /var/run/docker.sock:/tmp/docker.sock \
        gliderlabs/registrator:latest \
        consul://${CONSUL_IP}:8500 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    cat << EOF | tee -a "${LOG_FILE}"
There was an error (${ERR_CODE}) running the following command:

docker run -d \\
        --name=registrator \\
        -h "${NODE1_IP}" \\
        -v /var/run/docker.sock:/tmp/docker.sock \\
        gliderlabs/registrator:latest \\
        consul://${CONSUL_IP}:8500

EOF
    return 18
fi

END_MODE

printf "Switching Docker environment to Swarm managed by 'swarm-master0'...\n" | tee -a "${LOG_FILE}"

eval $(docker-machine env --swarm swarm-master0)
ERR_CODE="${?}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf >&2 "\nThere was an error (${ERR_CODE}) running 'eval \$(docker-machine env --swarm swarm-master0)'\n\n" | tee -a "${LOG_FILE}"
    return 19
fi

printf "Changing back to original dir '${CURRENT_DIR}/'\n" | tee -a "${LOG_FILE}"

cd "${CURRENT_DIR}"
ERR_CODE="${?}"
if [ "${?}" -ne 0 ]
then
    printf >&2 "\nThere was an error (${ERR_CODE}) running 'cd \"${CURRENT_DIR}\"'\n\n" | tee -a "${LOG_FILE}"
    return 20
fi

printf "\nDocker Swarm generation complete! Run 'docker run hello-world' to test your new swarm.\n" | tee -a "${LOG_FILE}"

echo
