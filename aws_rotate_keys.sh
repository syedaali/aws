#!/usr/bin/env bash

# this script will backup the aws credentials file in $HOME/.aws by appending the PID of the script
# edit the aws credentials file location if you are not using the default location
AWS_CREDENTIALS_FILE=$HOME/.aws/credentials

# checks for keys in the local configuration file
function get_aws_access_keys() {
    access_key=$(aws configure get profile.${profile}.aws_access_key_id)
}

function create_aws_keys() {
    read new_access_key new_secret_key <<<$(aws iam create-access-key --profile ${profile} --output=text | awk '{print $2 " " $4}')
    if [ -z ${new_access_key} ] || [ -z ${new_secret_key} ]; then
      return 1
    fi
}

# sets the new key in the local configuration file
function replace_aws_access_keys() {
     `aws configure set aws_access_key_id ${new_access_key} --profile ${profile}`
}

function replace_aws_secret_keys() {
    `aws configure set aws_secret_access_key ${new_secret_key} --profile ${profile}`
}

# deletes the old keys from AWS
function delete_aws_keys() {
    $(aws iam delete-access-key --access-key-id ${access_key} --profile ${profile})
}

# check if aws cli is present
function check_aws_cli() {
    printf 'checking for aws cli requirement...'
    if ! [ -x "$(command -v aws)" ]; then
      printf 'failed, exiting!\n' >&2
      exit 1
    else
      printf  'success!\n'
    fi

}

# backup the current config before doing anything
function backup_config() {
    `cp ${AWS_CREDENTIALS_FILE} ${AWS_CREDENTIALS_FILE}.$$`
}

# check if there are two keys in AWS for the given profile
function check_two_keys() {

    num_keys=$(aws iam list-access-keys --profile ${profile} --output=text | wc -l)
    if [ $num_keys -gt 1 ]; then
      printf "found more than one key for profile...\n";
      return 2
    else
      printf "found a single key, continuing...\n"
      return 0
    fi

}


function main() {
    check_aws_cli
    printf "trying to backup config file..."
    backup_config
    if [ $? -eq 0 ]; then
      printf "success\n"
    else
      printf "unable to backup config file, exiting!\n"
      exit 1
    fi

    while read line
    do
        if [[ ${line} == "["* ]]; then
          profile=$(echo "${line}" | tr -d '[]')

          printf "*******************************************************\n"
          printf "saving existing access and secret key for profile ${profile}..."
          get_aws_access_keys
          if [ $? -eq 0 ]; then
            printf "success!\n"
          else
            printf "unable to save existing access key for processing, skipping to next profile!\n"
            continue
          fi

          printf "attempting to create new access key for profile ${profile}..."
          create_aws_keys
          if [ $? -eq 0 ]; then
            printf  "success!\n"
            printf "attempting to replace access keys in credentials files..."
            replace_aws_access_keys
            if [ $? -eq 0 ]; then
              printf  "success!\n"
              printf "attempting to replace secret keys in credentials files..."
              replace_aws_secret_keys
              if [ $? -eq 0 ]; then
                printf  "success!\n"
                printf "waiting a few seconds for new keys to propagate across aws...\n"
                sleep 8
                printf "attempting to delete old access and secret keys..."
                delete_aws_keys
                if [ $? -eq 0 ]; then
                  printf "success!\n"
                else
                  printf "unable to delete keys, moving onto next!\n"
                fi
              fi
            fi


          else
             printf "failed to create new key\n"
          fi

        fi
    done < ${AWS_CREDENTIALS_FILE}

}

main



