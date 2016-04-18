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

printf "Adding CentOS7 Docker repo to yum repos...\n" | tee -a "${LOG_FILE}"

tee /etc/yum.repos.d/docker.repo <<-EOF 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) adding the docker yum repo to /etc/yum.repos.d/.\n\n" | tee -a "${LOG_FILE}"
    exit 3
fi

printf "Installing Docker Engine...\n" | tee -a "${LOG_FILE}"

yum install -y docker-engine 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'yum install -y docker-engine'.\n\n" | tee -a "${LOG_FILE}"
    exit 4
fi

printf "Starting Docker daemon...\n" | tee -a "${LOG_FILE}"

systemctl start docker.service 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'systemctl start docker.service'.\n\n" | tee -a "${LOG_FILE}"
    exit 5
fi

printf "Setting the Docker daemon to start on boot...\n" | tee -a "${LOG_FILE}"

systemctl enable docker.service 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'systemctl enable docker.service'.\n\n" | tee -a "${LOG_FILE}"
    exit 6
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
            exit 7
        fi
    fi
fi

printf "\nDocker Version:\n" | tee -a "${LOG_FILE}"

docker version 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'docker version'.\n\n" | tee -a "${LOG_FILE}"
    exit 8
fi

printf "\nDocker Info:\n" | tee -a "${LOG_FILE}"

docker info 2>&1 | tee -a "${LOG_FILE}" | sed 's/^/    /'
ERR_CODE="${PIPESTATUS[0]}"
if [ "${ERR_CODE}" -ne 0 ]
then
    printf "\nThere was an error (${ERR_CODE}) running 'docker version'.\n\n" | tee -a "${LOG_FILE}"
    exit 9
fi

printf "\nDocker Engine setup is complete!\n" | tee -a "${LOG_FILE}"

echo
