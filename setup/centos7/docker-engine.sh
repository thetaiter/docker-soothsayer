#!/bin/bash

if [ "$(whoami)" != "root" ]
then
    printf "\nThis script must be run as root. Try again with 'sudo ${0}'\n\n"
    exit 1
fi

LOG_FILE="/tmp/docker-engine-setup.log"

printf "\nLogging to file ${LOG_FILE}\n\n"

printf "Running yum update...\n" | tee "${LOG_FILE}"

yum update -y 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'yum update -y'.\n\n" | tee -a "${LOG_FILE}"
    exit 2
fi

if ! hash curl 2> /dev/null
then
    printf "Curl is not installed on this system. Installing...\n" | tee -a "${LOG_FILE}"

    yum install -y curl 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
    ERR_CODE="${PIPESTATUS[0]}"
    if [ "${ERR_CODE}" -ne 0 ]
    then
        printf "\nThere was an error (${ERR_CODE}) running 'yum install -y curl'.\n\n" | tee -a "${LOG_FILE}"
        exit 3
    fi
fi

printf "Installing Docker Engine...\n" | tee -a "${LOG_FILE}"

curl -fsSL https://get.docker.com/ 2>&1 | sh 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE0="${PIPESTATUS[0]}" ERR_CODE1="${PIPESTATUS[1]}"
if [ "${ERR_CODE0}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE0}) running 'curl -fsSL https://get.docker.com/'.\n\n" | tee -a "${LOG_FILE}"
    exit 4
elif [ "${ERR_CODE1}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE1}) running the script located at https://get.docker.com/ with 'sh'.\n\n" | tee -a "${LOG_FILE}"
    exit 5
fi

printf "Starting Docker daemon...\n" | tee -a "${LOG_FILE}"

systemctl start docker.service 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'systemctl start docker.service'.\n\n" | tee -a "${LOG_FILE}"
    exit 6
fi

printf "Setting the Docker daemon to start on boot...\n" | tee -a "${LOG_FILE}"

systemctl enable docker.service 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'systemctl enable docker.service'.\n\n" | tee -a "${LOG_FILE}"
    exit 7
fi

if ! [ -z "${SUDO_USER}" ]
then
    if groups ${SUDO_USER} | grep 2>&1 > /dev/null '\bdocker\b'
    then
        printf "The user '${SUDO_USER}' is already a member of the 'docker' group.\n" | tee -a "${LOG_FILE}"
    else
        printf "Adding user '${SUDO_USER}' to the 'docker' group...\n" | tee -a "${LOG_FILE}"

        usermod -a -G docker ${SUDO_USER} 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
        ERR_CODE="${PIPESTATUS[0]}"
        if [ "${ERR_CODE}" -ne 0 ]
        then
            printf "\nThere was an error (${ERR_CODE}) running 'usermod -a -G docker ${SUDO_USER}'.\n\n" | tee -a "${LOG_FILE}"
            exit 8
        fi
    fi
fi

printf "\nDocker Version:\n" | tee -a "${LOG_FILE}"

docker version 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'docker version'.\n\n" | tee -a "${LOG_FILE}"
    exit 9
fi

printf "\nDocker Info:\n" | tee -a "${LOG_FILE}"

docker info 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'docker version'.\n\n" | tee -a "${LOG_FILE}"
    exit 10
fi

printf "\nDocker Engine setup is complete!\n" | tee -a "${LOG_FILE}"

echo
