#!/bin/bash
# Automated Security Group Update Script

function update_sgs {
        
    # Get data from AWS.
    aws ec2 describe-security-groups > ./ec2_sg.text

    # Append SG IDs to ARR (you just said arr in your head like a pirate, didnt you?)
    mapfile -t SG_ARR < <(grep -o '"GroupId": "[^\"]*' ./ec2_sg.text | awk -F ":" '{print $2}' | awk -F "\"" '{print $2}' | sort | uniq)

    # LOOP ALL THE ARRs
    for ((i=0; i<${#SG_ARR[@]}; i++)); do

        if aws ec2 describe-security-groups --group-ids "${SG_ARR[$i]}" | grep "$1" > /dev/null; then

            mapfile -t FP_ARR < <(aws ec2 describe-security-groups \
            --group-ids "${SG_ARR[$i]}" --profile prod \
            | jq '.SecurityGroups[].IpPermissions[] | select(.IpRanges[].CidrIp | startswith("$1"))' \
            | grep 'FromPort' | awk '{print $2}' | tr -d ,)

            # Dear god, this is one pile of shit.
            mapfile -t TP_ARR < <(aws ec2 describe-security-groups \
            --group-ids "${SG_ARR[$i]}" --profile prod \
            | jq '.SecurityGroups[].IpPermissions[] | select(.IpRanges[].CidrIp | startswith("$1"))' \
            | grep 'ToPort' | awk '{print $2}' | tr -d ,)

            mapfile -t PRO_ARR < <(aws ec2 describe-security-groups \
            --group-ids "${SG_ARR[$i]}" --profile prod \
            | jq '.SecurityGroups[].IpPermissions[] | select(.IpRanges[].CidrIp | startswith("$1"))' \
            | grep 'IpProtocol' | awk '{print $2}' | tr -d , | tr -d \")

            # Its a UNIX SYSTEM.
            for ((k=0; k<${#FP_ARR[@]}; k++)); do
                aws ec2 authorize-security-group-ingress \
                --group-id "${SG_ARR[$i]}" \
                --protocol "${PRO_ARR[$k]}" \
                --port "${FP_ARR[$k]}-${TP_ARR[$k]}" \
                --cidr "$2"
            done

            # (╯°□°）╯︵ ┻━┻
            FP_ARR=() && TP_ARR=() && PRO_ARR=()

        fi
    done
}

function show-usage {
    echo "Usage:"
    echo "  sg_update.sh [ -u ]"
    echo "  -u [old ip] [new ip]"
    echo "    This option is for updating existing SGs with new IP information"
    echo "    EX: ./sg_update.sh -u 192.168.1.1 192.168.1.2"
}


# Shell detection for CLI arguments. Script will not run without an argument
((!$#)) && echo "No arguements supplied!" && show-usage && exit 1

# Getopts that defines CLI Behavior
while getopts ":u:" opt; do
    case $opt in
        u)
            update-sgs "$2" "$3"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            show-usage
            exit 1
            ;;
        :) 
            echo "Invalid option: -$OPTARG reqiuires an arguement"
            show-usage
            exit 1
            ;;
    esac
done

shift $((OPTIND -1))
