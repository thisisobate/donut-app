#!/bin/bash

# global vars
CONTAINER_ID=''
OS=''
ARCH=''
MOUNT_VOLUME_LOCAL=''
TOTAL_STEPS='5'
SEGMENT=$1
SYSTEMA_ENV=$2


display_step() {
    echo -n "*** Step $1/$TOTAL_STEPS: "
}

has_cli() {
    display_step 1
    meet_requirements=true
    echo 'Checking required tools ... '
    _=$(which curl)
    if [ "$?" = "1" ]; then
        echo "You need curl to use this script."
        meet_requirements=false
    fi
    _=$(which kubectl)
    if [ "$?" = "1" ]; then
        echo "You need kubectl to use this script. https://kubernetes.io/docs/tasks/tools/#kubectl"
        meet_requirements=false
    fi
    _=$(which docker)
    if [ "$?" = "1" ]; then
        echo "You need docker to use this script. https://docs.docker.com/engine/install/"
        meet_requirements=false
    fi

    if (! docker stats --no-stream &> /dev/null); then
        echo "Docker daemon is not running"
        meet_requirements=false
    fi
    if [ $meet_requirements = false ]; then
        exit 1
    fi
    echo 'Complete.'
}

install_upgrade_telepresence() {
    display_step 2
    install_telepresence=false
    echo -n 'Checking for Telepresence ... '
    _=$(which telepresence)
    if [ "$?" = "1" ]; then
        install_telepresence=true
        echo "Installing Telepresence"
    else
        # Ensure that running telepresence daemons are stopped. A running daemon
        # has its current working directory set to the directory where it was first
        # started, and since the KUBECONFIG is set to a relative directory in this
        # script, a previously started daemon might resolve it incorrectly.
        _=$(telepresence quit -s)
        if telepresence version|grep upgrade >/dev/null 2>&1; then
            install_telepresence=true
            echo "Upgrading Telepresence"
        else
            echo "Telepresence already installed"
        fi
    fi    
    if [ $install_telepresence = true ]; then
        sudo curl -fL https://app.getambassador.io/download/tel2/${OS}/${ARCH}/2.8.2/telepresence -o /usr/local/bin/telepresence
        sudo chmod a+x /usr/local/bin/telepresence
    fi
}

set_os_arch() {
    uname=$(uname)

    case $uname in
        "Darwin")
            OS="darwin"
            MOUNT_VOLUME_LOCAL=~/Library/Application\ Support
            OPEN_EDITOR=open
            ;;
        "Linux")
            OS="linux"
            MOUNT_VOLUME_LOCAL=$(if [[ "$XDG_CONFIG_HOME" ]]; then echo "$XDG_CONFIG_HOME"; else echo "$HOME/.config"; fi)
            OPEN_EDITOR=xdg-open
            ;;
        *)
            fatal "Unsupported os $uname"
    esac

    if [ -z "$ARCH" ]; then
        ARCH=$(uname -m)
    fi
    case $ARCH in
        amd64)
            ARCH=amd64
            ;;
        x86_64)
            ARCH=amd64
            ;;
        arm64)
            ARCH=arm64
            ;;
        aarch64)
            ARCH=arm64
            ;;
        *)
            fatal "Unsupported architecture $ARCH"
    esac
}

run_dev_container() {
    display_step 3
    echo 'Configuring development container. This container encapsulates all the dependencies needed to run the emojivoto-web-app locally.'
    echo 'This may take a few moments to download and start.'

    # build docker image
    docker build -t donut-app-container .

    # run the dev container
    docker run -dp 3009:3009 donut-app-container 

    # upload image to dockerhub 
    docker tag donut-app-container thisisobate/donut-app-container
    docker push thisisobate/donut-app-container
}

connect_to_k8s() {
    display_step 4

    # use config for docker desktop
    export KUBECONFIG=~/.kube/config    

    # create k8s cluster
    kubectl apply -f deployment_local.yaml

    # List services in k8s cluster
    echo "Listing services in cluster"
    listSVC=$(kubectl get svc)
    echo "$listSVC"  
}

connect_local_dev_env_to_remote() {
    display_step 5
    echo 'Connecting local development environment to remote K8s cluster'

    telepresence helm install
    telepresence connect
    telepresence list
    kubectl get svc donut-app-local --output yaml
    
    telepresence intercept donut-app-local --port 3009:82 

    telOut=$?
    if [ $telOut != 0 ]; then
        echo "interceptFailed"
        exit $telOut
    fi
    echo "interceptCreated"
}

display_instructions_to_user () {
    echo ''
    echo 'INSTRUCTIONS FOR DEVELOPMENT'
    echo '============================'
    echo 'To set the correct Kubernetes context on this shell, please execute:'
    echo 'export KUBECONFIG=~/.kube/config'
}


has_cli
set_os_arch
install_upgrade_telepresence
run_dev_container
connect_to_k8s
connect_local_dev_env_to_remote
display_instructions_to_user

# happy coding!