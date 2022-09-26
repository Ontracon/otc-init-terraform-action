#!/bin/bash

# ---------------------------------------------------------------------------------------------------------------------
# Help for shell scripts
# ---------------------------------------------------------------------------------------------------------------------
help()
{
    for i in {1..100}; do echo -n -; done
    echo ""
    echo " Help for `basename $0` "
    for i in {1..100}; do echo -n -; done
    echo
    echo "bootstrap.sh : bootstrap you cloud environment"
    echo
    echo "The following parameters are supported. The specification of the 'c' parameter is mandatory. For Azure also 'r' is mandatory. All others are optional."
    echo
    echo "A minimal bootstrap call for Azure:"
    echo "./bootstrap.sh -c 'example/azure/config.azure.tfbackend' -r GermanyWestCentral"
    echo
    echo "A minimal bootstrap call for AWS:"
    echo "./bootstrap.sh -c 'example/aws/config.aws.tfbackend'"
    echo
    echo "-h Help"
    echo
    echo "-c Configuration File"
    echo "-p Prerequisite File - Optional, if you like to deploy infrastructure in addition."
    echo "-r Cloud Region to deploy infrastructure"
}