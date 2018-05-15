#!/bin/bash
# cpu-mon.sh
# Brendan Swigart - 5/15/18
# A simple script for monitoring CPU usage
# This was written because the granularity on CloudWatch Metrics is too slow
# For my current autoscaling needs. 


CPU_MONITOR () {

    # Do this loop 30 times, once per second. 
    # Set this to whatever you want. 
    for ((ITER=0; ITER<30; ITER++)); do

        # Get CPU metrics from /proc/stat
        IFS=" " read -r -a CPU_METRICS <<< "$(grep -Po '(?<=cpu[^0-9]).*' /proc/stat)"
        
        # The third element in the array is always CPU IDLE
        CURRENT_CPU_IDLE="${CPU_METRICS[3]}"
        
        # Calculate total CPU time
        for STATS in "${CPU_METRICS[@]}"; do
            let BUFFER="$STATS"
            CURRENT_CPU_TOTAL=$((BUFFER + CURRENT_CPU_TOTAL))
        done
        
        # Arithmetic to make things a little bit simpler later
        let DELTA_CPU_IDLE=$((CURRENT_CPU_IDLE-PREVIOUS_CPU_IDLE))
        let DELTA_CPU_TOTAL=$((CURRENT_CPU_TOTAL-PREVIOUS_CPU_TOTAL))
        let NUMERATOR=$((DELTA_CPU_TOTAL-DELTA_CPU_IDLE))

        # Actually calculate the percentage of CPU utilization
        OUTPUT=$(bc <<< "scale=3; $NUMERATOR/$DELTA_CPU_TOTAL*100")

        # Record previous metrics for future use.
        let PREVIOUS_CPU_TOTAL=$CURRENT_CPU_TOTAL
        let PREVIOUS_CPU_IDLE=$CURRENT_CPU_IDLE 
        let CURRENT_CPU_TOTAL=0

        # Echo output for troubleshooting
        echo $OUTPUT

        # If CPU percentage is greater than whatever you want increment tipping point
        # Used native bash interpolation to strip out the decimal from OUTPUT
        if [[ "${OUTPUT//.}" -gt 50000 ]]; then 
            ((TIPPER++))
        fi

        # If tipping point has been breached too much, autoscale up. 
        if [[ $TIPPER -gt 15 ]]; then
            SCALE_UP
        fi

        # Sleeeeeeeeeeep
        sleep 1

    done

    # Reset tipping point count in case you want to reuse this function. 
    let TIPPER=0 

}

SCALE_UP () {
    echo "Scaling up"
    # Write your own methods for scaling up here. 
}

CPU_MONITOR
