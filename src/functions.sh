#!/bin/bash
source "$SCRIPT_DIRECTORY/help.sh"

#Color for Outputs
OK='\033[0;32m'
INF='\033[0;33m'
ERR='\033[0;31m'
NC='\033[0m'

# Defaults
OVERRIDE=false

function hr(){
    for i in {1..100}; do echo -n -; done
    echo ""
}

function install_terraform ()
{
    echo "- Terraform check:"
    if ! command -v terraform &> /dev/null || [ "$OVERRIDE" == "true" ];  then
        echo -e "  * ${INF}Terraform${NC}: terraform could not be found, installing."
        unzip -u $SCRIPT_DIRECTORY/install/terraform_1.3.0_linux_amd64.zip -d /tmp/ &> /dev/null
        dest="${INSTALL_PATH:-/usr/local/bin}/"
        echo -e "  * ${INF}Terraform${NC}: Installing terraform to ${OK}${dest}${NC}"
        if [[ -w "$dest" ]]; then SUDO=""; else
            # current user does not have write access to install directory
            SUDO="sudo";
        fi
        $SUDO mkdir -p "$dest"
        $SUDO install -c -v /tmp/terraform "$dest" &> /dev/null
        retVal=$?
        if [ $retVal -ne 0 ]; then
            echo "Failed to install terraform"
            exit $retVal
        fi
        rm -f /tmp/tflint
    fi
    terraform --version &> /dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "  * ${ERR}Terraform  not found:${OK} terraform not found or not in path!${NC}"
        exit 1
    else
        echo -e "  * ${OK}Terraform:${NC} `which terraform` - `terraform --version -json | jq -r '.terraform_version'`"
    fi
}

function get_opts(){
    #Input Of Optional Parameters
    while getopts c:p:r:h flag

    do
        case "${flag}" in
            c) CFG_FILE=${OPTARG} ;;
            p) PRQ_FILE=${OPTARG} ;;
            r) CLOUD_REGION=${OPTARG} ;; #location -> only needed for Azure
            h) help
                exit 0 ;;
            *) ;;
        esac
    done


    # DEFINE Variables
    REPO=${GITHUB_REPOSITORY#*/}

    hr
    echo -e "Repository: ${INF}$REPO${NC}"
    echo -e "Running script: ${INF}'`basename $0`'${NC}"
    echo -e "CFG_FILE: ${INF}$CFG_FILE${NC}"
    echo -e "PRQ_FILE: ${INF}$PRQ_FILE${NC}"
    echo -e "CLOUD_REGION: ${INF}$CLOUD_REGION${NC}"
    hr

    install_terraform
    # Fullfill prequisites
    if [[ -z "$CFG_FILE" ]]; then
        echo -e "  * ${ERR}Error${NC}: No terraform backend config file provided. Abort"
        exit 1
    fi

    eval $(sed -r '/[^=]+=[^=]+/!d;s/\s+=\s/=/g' "$CFG_FILE")
    if [ -z "$region" ]; then echo -n ; else provider=aws; fi
    if [ -z "$resource_group_name" ]; then echo -n ; else provider=azure; fi
    echo -e "  * ${OK}Provider${NC}: Found provider ${INF}$provider${NC}"
}

function check_aws_credentials() {
    if [[ ! -z "$AWS_ACCESS_KEY_ID" ]] && [[ ! -z "$AWS_SECRET_ACCESS_KEY" ]]; then
        echo -e "  * ${OK}AWS Credentials${NC}: AWS Credentials ok."
    else
        echo -e "  * ${ERR}AWS Credentials${NC}: AWS Credentials not set."
        exit 1
    fi
}

function check_azure_credentials() {
    if [[ ! -z "$ARM_SUBSCRIPTION_ID" ]] && [[ ! -z "$ARM_CLIENT_ID" ]] &&  [[ ! -z "$ARM_CLIENT_SECRET" ]] && [[ ! -z "$ARM_TENANT_ID" ]]; then
        echo -e "  * ${OK}Azure Credentials${NC}: Azure Credentials ok."
    else
        echo -e "  * ${ERR}Azure Credentials${NC}: Azure Credentials not set."
        exit 1
    fi
}

aws_config ()
{
    echo -e "  * ${OK}AWS${NC} - Region: ${INF}$region${NC}, Bucket: ${INF}$bucket${NC}, DynamoDB: ${INF}$dynamodb_table${NC}"
    cd $SCRIPT_DIRECTORY/terraform/aws
    cp $SCRIPT_DIRECTORY/terraform/templates/conf.aws.tf $SCRIPT_DIRECTORY/terraform/aws/config.tf
    terraform init -reconfigure \
        -backend-config="region=$region" \
        -backend-config="bucket=$bucket" \
        -backend-config="dynamodb_table=$dynamodb_table" \
        -backend-config="key=bootstrap.aws" \
        -backend-config="encrypt=$encrypt" &> /dev/null
    status=$?
    if [ $status -ne 0 ]; then
        echo -e "  * ${INF}Backend${NC}: not configured or accessible, deploying AWS backend."
        cp $SCRIPT_DIRECTORY/terraform/templates/conf.aws.tf.local $SCRIPT_DIRECTORY/terraform/aws/config.tf
        echo "  * Terraform init -reconfigure"
        terraform init -reconfigure &> /dev/null
        echo "  * Create Bootstrap Plan"
        terraform plan -out=bootstrap.plan \
            -var "cloud_region=$region" \
            -var "s3_bucket_name=$bucket" \
            -var "dynamodb_table_name=$dynamodb_table" &> /dev/null
        FILE=bootstrap.plan
        if [ -f "$FILE" ]; then
            echo -e "  * ${OK}Bootstrap${NC}: Planfile $FILE exists."
        else
            echo -e "  * ${ERR}Bootstrap{NC}: Planfile $FILE does NOT exists."
            exit 1
        fi
        echo "  * Apply Bootstrap Plan"
        terraform apply bootstrap.plan
        cp $SCRIPT_DIRECTORY/terraform/templates/conf.aws.tf $SCRIPT_DIRECTORY/terraform/$provider/config.tf
        echo "  * Migrating state to backend."

        terraform init -migrate-state -force-copy \
            -backend-config="region=$region" \
            -backend-config="bucket=$bucket" \
            -backend-config="dynamodb_table=$dynamodb_table" \
            -backend-config="key=bootstrap.aws" \
            -backend-config="encrypt=$encrypt" &> /dev/null
        echo "  * Refreshing backend state."

        echo yes|terraform apply -refresh-only \
            -var "cloud_region=$region" \
            -var "s3_bucket_name=$bucket" \
            -var "dynamodb_table_name=$dynamodb_table" &> /dev/null
        rm $SCRIPT_DIRECTORY/terraform/$provider/terraform.tfstate
    fi
    echo -e "  * ${OK}Backend${NC}: Configured, add prequisites file to deployment"
    if [ -z "$PRQ_FILE" ]; then echo "  * Skipping prequisites_file."
    else
        cp $PRQ_FILE $SCRIPT_DIRECTORY/terraform/$provider/prequisites.tf
        terraform init -upgrade \
            -backend-config="region=$region" \
            -backend-config="bucket=$bucket" \
            -backend-config="dynamodb_table=$dynamodb_table" \
            -backend-config="key=bootstrap.aws" \
            -backend-config="encrypt=$encrypt" &> /dev/null

        terraform apply --auto-approve \
            -var "cloud_region=$region" \
            -var "s3_bucket_name=$bucket" \
            -var "dynamodb_table_name=$dynamodb_table"
    fi
}

aws_config_destroy (){
    cd $SCRIPT_DIRECTORY/terraform/$provider
    cp $SCRIPT_DIRECTORY/terraform/templates/conf.aws.tf $SCRIPT_DIRECTORY/terraform/aws/config.tf
    terraform init -reconfigure \
        -backend-config="region=$region" \
        -backend-config="bucket=$bucket" \
        -backend-config="dynamodb_table=$dynamodb_table" \
        -backend-config="key=bootstrap.aws" \
        -backend-config="encrypt=$encrypt" &> /dev/null
    status=$?

    if [ $status -ne 0 ]; then
        echo "  * Backend not configured!"
        exit 1
    fi

    cp $SCRIPT_DIRECTORY/terraform/templates/conf.aws.tf.local config.tf
    echo "  * Migrating state from remote to local"
    terraform init -migrate-state -force-copy &> /dev/null
    echo "  * terraform destroy"
    terraform destroy --auto-approve \
        -var "cloud_region=$region" \
        -var "s3_bucket_name=$bucket" \
        -var "dynamodb_table_name=$dynamodb_table"
}

azure_config ()
{
    echo -e "  * ${OK}Azure${NC} - location: ${INF}$CLOUD_REGION${NC}, RG: ${INF}$resource_group_name${NC}, SA: ${INF}$storage_account_name${NC} - $container"
    cd $SCRIPT_DIRECTORY/terraform/azure
    cp $SCRIPT_DIRECTORY/terraform/templates/conf.azure.tf config.tf
    terraform init -reconfigure \
        -backend-config="resource_group_name=$resource_group_name" \
        -backend-config="storage_account_name=$storage_account_name" \
        -backend-config="container_name=$container_name" \
        -backend-config="key=bootstrap.azure" &> /dev/null
    status=$?
    if [ $status -ne 0 ]; then
        echo -e "  * ${INF}Backend${NC}: not configured or accessible, deploying Azure backend."
        cp $SCRIPT_DIRECTORY/terraform/templates/conf.azure.tf.local config.tf
        echo "  * Terraform init -reconfigure"
        terraform init -reconfigure &> /dev/null
        echo "  * Create Bootstrap Plan"
        terraform plan -out=bootstrap.plan \
            -var "cloud_region=$CLOUD_REGION" \
            -var "resource_group_name=$resource_group_name" \
            -var "storage_account_name=$storage_account_name" \
            -var "container_name=$container_name"  &> /dev/null

        FILE=bootstrap.plan
        if [ -f "$FILE" ]; then
            echo -e "  * ${OK}Bootstrap${NC}: Planfile $FILE exists."
        else
            echo -e "  * ${ERR}Bootstrap{NC}: Planfile $FILE does NOT exists."
            exit 1
        fi
        echo "  * Apply Bootstrap Plan"
        terraform apply bootstrap.plan
        cp $SCRIPT_DIRECTORY/terraform/templates/conf.azure.tf config.tf
        echo "  * Migrating state to backend."

        terraform init -migrate-state -force-copy \
            -backend-config="resource_group_name=$resource_group_name" \
            -backend-config="storage_account_name=$storage_account_name" \
            -backend-config="container_name=$container_name" \
            -backend-config="key=bootstrap.azure" &> /dev/null
        echo "  * Refreshing backend state."

        echo yes|terraform apply -refresh-only \
            -var "cloud_region=$CLOUD_REGION" \
            -var "resource_group_name=$resource_group_name" \
            -var "storage_account_name=$storage_account_name" \
            -var "container_name=$container_name" &> /dev/null
        rm $SCRIPT_DIRECTORY/terraform/$provider/terraform.tfstate
    fi
    echo -e "  * ${OK}Backend${NC}: Configured, add prequisites file to deployment"
    if [ -z "$PRQ_FILE" ]; then echo "  * Skipping prequisites_file."
    else
        cp $PRQ_FILE $SCRIPT_DIRECTORY/terraform/$provider/prequisites.tf
        terraform init -upgrade \
            -backend-config="resource_group_name=$resource_group_name" \
            -backend-config="storage_account_name=$storage_account_name" \
            -backend-config="container_name=$container_name" \
            -backend-config="key=bootstrap.azure" &> /dev/null

        terraform apply --auto-approve \
            -var "cloud_region=$CLOUD_REGION" \
            -var "resource_group_name=$resource_group_name" \
            -var "storage_account_name=$storage_account_name" \
            -var "container_name=$container_name"
    fi
}

azure_config_destroy (){
    cd $SCRIPT_DIRECTORY/terraform/$provider
    cp $SCRIPT_DIRECTORY/terraform/templates/conf.azure.tf config.tf
    terraform init -reconfigure \
        -backend-config="resource_group_name=$resource_group_name" \
        -backend-config="storage_account_name=$storage_account_name" \
        -backend-config="container_name=$container_name" \
        -backend-config="key=bootstrap.azure" &> /dev/null
    status=$?

    if [ $status -ne 0 ]; then
        echo "  * Backend not configured!"
        exit 1
    fi

    cp $SCRIPT_DIRECTORY/terraform/templates/conf.azure.tf.local config.tf
    echo "  * Migrating state from remote to local"
    terraform init -migrate-state -force-copy &> /dev/null
    echo "  * terraform destroy"
    terraform destroy --auto-approve \
        -var "cloud_region=$CLOUD_REGION" \
        -var "resource_group_name=$resource_group_name" \
        -var "storage_account_name=$storage_account_name" \
        -var "container_name=$container_name"
}