#!/bin/bash
# Automated ASG Scale up for Elastic Beanstalk
# Brendan Swigart - 5/15/2018

# This script was written in response to the fact that
# AWS EB is really slow at scaling events. 
# The idea of this script is that it runs when an 
# EC2 phones home to a conductor server and initiates a
# Scale up event well before AWS would even think to. 

# Get Environment from CLI Argument
BEANSTALK_ENVIRONMENT="$1" 

# Get Application Name
BEANSTALK_APPLICATION=$(aws elasticbeanstalk describe-environments \
  --environment-name "$BEANSTALK_ENVIRONMENT" \
  | grep -Po '(?<=ApplicationName\"\: \").*' \
  | awk -F '"' '{print $1}')

# Get min instance count
MIN_INSTANCES=$(aws elasticbeanstalk describe-configuration-settings \
  --application-name "$BEANSTALK_APPLICATION" \
  --environment-name "$BEANSTALK_ENVIRONMENT" \
  | grep -A3 "MinSize" \
  | grep -Eo '[0-9]+')

# Get max instance count
MAX_INSTANCES=$(aws elasticbeanstalk describe-configuration-settings \
  --application-name "$BEANSTALK_APPLICATION" \
  --environment-name "$BEANSTALK_ENVIRONMENT" \
  | grep -A3 "MaxSize" \
  | grep -Eo '[0-9]+')

# Double instance counts for scale up
let MAX_INSTANCES=$((MAX_INSTANCES*2))
let MIN_INSTANCES=$((MIN_INSTANCES*2))

# Set max limit so that we don't owe AWS the bank. 
if [[ $MAX_INSTANCES -gt 120 ]]; then
  let MAX_INSTANCES=120
fi

# Set min limit for same reasons as well. 
if [[ $MIN_INSTANCES -gt 100 ]]; then
  let MIN_INSTANCES=100
fi

# Construct JSON Blob
{
  echo "[";
  echo "  {";
  echo "    \"Namespace\":\"aws:autoscaling:asg\",";
  echo "    \"OptionName\":\"MinSize\",";
  echo "    \"Value\":\"$MIN_INSTANCES\"";
  echo "  },";
  echo "  {";
  echo "    \"Namespace\":\"aws:autoscaling:asg\",";
  echo "    \"OptionName\":\"MaxSize\",";
  echo "    \"Value\":\"$MAX_INSTANCES\"";
  echo "  }";
  echo "]";
} > "$BEANSTALK_ENVIRONMENT".json;

# Deliver payload
# Naming the json by the env name prevents 
# potential file locks if this is run by different environments
aws elasticbeanstalk update-environment \
  --environment-name $BEANSTALK_ENVIRONMENT \
  --option-settings file://"$BEANSTALK_ENVIRONMENT".json

# Cleanup
rm "$BEANSTALK_ENVIRONMENT".json

