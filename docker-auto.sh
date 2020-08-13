#!/usr/bin/env bash

set -e

SCRIPT_BASE_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "$SCRIPT_BASE_PATH"

###############################################
# Extract Environment Variables from .env file
# Ex. REGISTRY_URL="$(getenv REGISTRY_URL)"
###############################################
getenv(){
    local _env="$(printenv $1)"
    echo "${_env:-$(cat .env | awk 'BEGIN { FS="="; } /^'$1'/ {sub(/\r/,"",$2); print $2;}')}"
}

DOCKER_COMPOSE_VERSION="1.14.0"
CONF_ARG="-f docker-compose-prod-full.yml"
PATH=$PATH:/usr/local/bin/
PROJECT_NAME="$(getenv PROJECT_NAME)"
REGISTRY_URL="$(getenv REGISTRY_URL)"

########################################
# Install docker-compose
# DOCKER_COMPOSE_VERSION need to be set
########################################
install_docker_compose() {
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    return 0
}

if ! command -v docker-compose >/dev/null 2>&1; then
    install_docker_compose
elif [[ "$(docker-compose version --short)" != "$DOCKER_COMPOSE_VERSION" ]]; then
    install_docker_compose
fi

usage() {
echo "Usage:  $(basename "$0") [MODE] [OPTIONS] [COMMAND]"
echo 
echo "Mode:"
echo "  --prod          Production mode with all services running"
echo "  --prod-was      Production mode with only was (tomcat) running"
echo "  --dev           Development mode with all services running"
echo "  --dev-was       Development mode with only was (tomcat) running"
echo "  --with-hub      Production mode - have to run under the hub web server"
echo "  --dev-with-hub  Development mode - have to run under the hub web server"
echo
echo "Options:"
echo "  --jmx           Add JMX support"
echo "  --jpda          Add JPDA remote debugging"
echo "  --certgen       Run the certbot instance for generating SSL certificate"
echo "  --rabbitmq      Add RabbitMQ Server"
echo "  --noimage       Use a war file located in 'was' folder, use the ant task 'docker-build' to create the war file"
echo "  --help          Show this help message"
echo "  --ssl           Enable SSL connection, set HTTPS_PORT and certificate correctly"
echo "  --hoops         Load PMIS with Hoops BIM Viewer path: /hoops"
echo
echo "Commands:"
echo "  up              Start the services"
echo "  down            Stop the services"
echo "  ps              Show the status of the services"
echo "  logs            Follow the logs on console"
echo "  login           Log in to a Docker registry"
echo "  force-remove    Service is stopped and removed with force!"
echo "  remove-all      Remove all containers"
echo "  stop-all        Stop all containers running"
echo "  build           Build the image"
echo "  publish         Publish the image to the registry"
echo "  arthas          Start arthas diagnostic tool"
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

for i in "$@"
do
case $i in
    --prod)
        CONF_ARG="-f docker-compose-prod-full.yml -f docker-compose-rabbitmq.yml"
        shift
        ;;
    --prod-was)
        CONF_ARG="-f docker-compose-prod-was.yml"
        shift
        ;;
    --with-hub)
        CONF_ARG="-f docker-compose-prod-with-hub.yml -f docker-compose-rabbitmq.yml"
        shift
        ;;
    --dev)
        CONF_ARG="-f docker-compose-dev-full.yml"
        shift
        ;;
    --dev-was)
        CONF_ARG="-f docker-compose-dev-was.yml"
        shift
        ;;
    --dev-with-hub)
        CONF_ARG="-f docker-compose-dev-with-hub.yml"
        shift
        ;;
    --jmx)
        CONF_ARG="$CONF_ARG -f docker-compose-jmx.yml"
        shift
        ;;
    --certgen)
        CONF_ARG="$CONF_ARG -f docker-compose-certgen.yml"
        shift
        ;;
    --rabbitmq)
        CONF_ARG="$CONF_ARG -f docker-compose-rabbitmq.yml"
        shift
        ;;
    --jpda)
        CONF_ARG="$CONF_ARG -f docker-compose-jpda.yml"
        shift
        ;;
    --noimage)
        CONF_ARG="$CONF_ARG -f docker-compose-prod-noimage.yml"
        shift
        ;;
    --ssl)
        CONF_ARG="$CONF_ARG -f docker-compose-ssl.yml"
        shift
        ;;
    --hoops)
        CONF_ARG="$CONF_ARG -f docker-compose-hoops.yml"
        shift
        ;;
    --help|-h)
        usage
        exit 1
        ;;
    *)
        CONF_ARG="$CONF_ARG -f docker-compose-rabbitmq.yml -f docker-compose-livechat.yml"
        ;;
esac
done

echo "Arguments: $CONF_ARG"
echo "Command: $@"

if [ "$1" == "login" ]; then
    docker login $REGISTRY_URL
    exit 0

elif [ "$1" == "up" ]; then
    docker-compose $CONF_ARG pull
    docker-compose $CONF_ARG build --pull
    docker-compose $CONF_ARG up -d --remove-orphans
    exit 0

elif [ "$1" == "force-remove" ]; then
    shift
    docker-compose $CONF_ARG rm --stop --force "$@"
    exit 0

elif [ "$1" == "stop-all" ]; then
    if [ -n "$(docker ps --format {{.ID}})" ]
    then docker stop $(docker ps --format {{.ID}}); fi
    exit 0

elif [ "$1" == "remove-all" ]; then
    if [ -n "$(docker ps -a --format {{.ID}})" ]
    then docker rm $(docker ps -a --format {{.ID}}); fi
    exit 0

elif [ "$1" == "logs" ]; then
    shift
    docker-compose $CONF_ARG logs -f --tail 200 "$@"
    exit 0

elif [ "$1" == "build" ]; then
    if [ -z "$REGISTRY_URL" ]; then echo "REGISTRY_URL not defined."; exit 1; fi
    if [ -z "$PROJECT_NAME" ]; then echo "PROJECT_NAME not defined."; exit 1; fi
    
    docker build -t $REGISTRY_URL/$PROJECT_NAME was
    exit 0

elif [ "$1" == "publish" ]; then
    if [ -z "$REGISTRY_URL" ]; then echo "REGISTRY_URL not defined."; exit 1; fi
    if [ -z "$PROJECT_NAME" ]; then echo "PROJECT_NAME not defined."; exit 1; fi
    
    docker login $REGISTRY_URL
    docker push $REGISTRY_URL/$PROJECT_NAME
    exit 0

elif [ "$1" == "arthas" ]; then
    shift
    docker-compose $CONF_ARG exec was /bin/bash -c "wget https://alibaba.github.io/arthas/arthas-boot.jar && java -jar arthas-boot.jar $@"
    exit 0

fi

docker-compose $CONF_ARG "$@"
