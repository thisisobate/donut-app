#!/bin/bash

# global vars
CONTAINER_ID=''
OS=''
ARCH=''
MOUNT_VOLUME_LOCAL=''
USE_TELEMETRY=
OPEN_EDITOR=
ACTIVITY_REPORT_TYPE='INTERMEDIATE_CLOUD_TOUR_SCRIPT'
EMOJIVOTO_NS='emojivoto'
TOTAL_STEPS='7'
SEGMENT=$1
SYSTEMA_ENV=$2


# use_telemetry() {
#     USE_TELEMETRY=true
# }

# send_telemetry() {
#     if [ $USE_TELEMETRY = true ]; then
#         action=$1
#         ambassador_cloud_url="https://auth.datawire.io"
#         application_activities_url="${ambassador_cloud_url}/api/applicationactivities"
#         curl -X POST \
#           -H "X-Ambassador-API-Key: $AMBASSADOR_API_KEY" \
#           -H "Content-Type: application/json" \
#           -d '{"type": "'$ACTIVITY_REPORT_TYPE'", "extraProperties": {"action":"'"$action"'","os":"'"$OS"'","arch":"'"$ARCH"'","segment":"'"$SEGMENT"'"}}' \
#           -s \
#           $application_activities_url > /dev/null 2>&1
#     fi
# }

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

# check_init_config() {
#     display_step 2
#     echo 'Checking for AMBASSADOR_API_KEY environment variable'
#     if [[ -z "${AMBASSADOR_API_KEY}" ]]; then
#         # you will need to set the AMBASSADOR_API_KEY via the command line
#         # export AMBASSADOR_API_KEY='NTIyOWExZDktYTc5...'
#         echo 'AMBASSADOR_API_KEY is not currently defined. Please set the environment variable in the shell e.g.'
#         echo 'export AMBASSADOR_API_KEY=NTIyOWExZDktYTc5...'
#         echo 'You can get an AMBASSADOR_API_KEY and free remote demo cluster by taking the tour of Ambassador Cloud at https://app.getambassador.io/cloud/welcome?tour=intermediate '
#         echo 'During the tour be sure to copy the AMBASSADOR_API_KEY from the "docker run" command'
#         exit
#     fi
# }

run_dev_container() {
    display_step 3
    echo 'Configuring development container. This container encapsulates all the dependencies needed to run the emojivoto-web-app locally.'
    echo 'This may take a few moments to download and start.'

    # build docker image
    docker build -t donut-app .

    # run the dev container
    docker run -dp 3000:3000 donut-app 

    # upload image to dockerhub 
    docker tag donut-app thisisobate/donut-app
    docker push thisisobate/donut-app
}

connect_to_k8s() {
    display_step 4
    # echo 'Getting KUBECONFIG from demo cluster'
    # demo_cluster_url="https://auth.datawire.io/api/democlusters/telepresence-demo/config"
    # if [[ "$SYSTEMA_ENV" == "staging" ]]; then
    #     demo_cluster_url="https://staging-auth.datawire.io/api/democlusters/telepresence-demo/config"
    # fi
    # demo_cluster_info=$(curl -H "X-Ambassador-API-Key:$AMBASSADOR_API_KEY" $demo_cluster_url -s)
    # echo "$demo_cluster_info" > ./emojivoto_k8s_context.yaml
    # export KUBECONFIG=./emojivoto_k8s_context.yaml
    # kubectl config set-context --current --namespace=emojivoto
    

    # create k8s cluster
    kubectl apply -f deployment.yaml

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
    kubectl get svc donut-app --output yaml
    
    telepresence intercept donut-app --service donut-app --port 3000:80 --env-file donut-app-intercept.env
    docker run --env-file donut-app-intercept.env

    telOut=$?
    if [ $telOut != 0 ]; then
        echo "interceptFailed"
        exit $telOut
    fi
    echo "interceptCreated"
}

open_editor() {
    display_step 6
    echo 'Opening editor'
    # let the user see the output before opening the editor
    sleep 2

    # replace this line with your editor of choice, e.g. VS code, Intelli J
    $OPEN_EDITOR src/app.js
}

display_instructions_to_user () {
    echo ''
    echo 'INSTRUCTIONS FOR DEVELOPMENT'
    echo '============================'
    echo 'To set the correct Kubernetes context on this shell, please execute:'
    echo 'export KUBECONFIG=./emojivoto_k8s_context.yaml'
}


has_cli
set_os_arch
check_init_config
install_upgrade_telepresence
run_dev_container
connect_to_k8s
connect_local_dev_env_to_remote
open_editor
display_instructions_to_user

# happy coding!