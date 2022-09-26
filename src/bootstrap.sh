#!/bin/bash

########################################################################################################################
# Getting script directory
# Source template functions
# Printing Inputs and Context
########################################################################################################################
SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "$SCRIPT_DIRECTORY/functions.sh"
source "$SCRIPT_DIRECTORY/help.sh"

get_opts "$@"

case $provider in
    aws)
        check_aws_credentials
        aws_config
        if [[ "$BACKEND_DESTROY" == "true" ]]; then
            echo "- AWS Destroy"
            aws_config_destroy
        fi
        ;;

    azure)
        # Double check location, if provider is azure
        if [ -z "$CLOUD_REGION" ]; then
            echo -e "  * ${ERR}Error${NC}: Selected provider is Azure. Cloud Region parameter have to be set. Abort"
            exit 1
        fi
        check_azure_credentials
        azure_config
        if [[ "$BACKEND_DESTROY" == "true" ]]; then
            echo "- Azure Destroy"
            azure_config_destroy
        fi
        ;;

    *)
        echo -e "  * ${ERR}Error${NC}:Unknown Provider From Config File: Exiting."
        exit 1
        ;;
esac