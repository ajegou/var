#!/usr/bin/env bash
# This script takes 1 or 2 parameters, the first being the keyspace to repair, and the second the table. If no table is specified, the whole keyspace will be repaired.

# Simple util function redirecting both stdout and stderr into the both stdout and $output
function log_info() {
  echo -e $@ |& tee -a $output
}
# Util function redirecting both stdout and stderr into $output
function log_debug() {
  echo -e $@ 2>&1 >> $output
}

function pretty_time() {
  local current=$(date +%s)
  local elapsed=$(($current - $1))
  local pretty_time=$(printf '%02dh:%02dm:%02ds\n' $(($elapsed/3600)) $(($elapsed%3600/60)) $(($elapsed%60)))
  echo "$pretty_time"
}

# Counts, from the logs, the number of individial entries that were repaired. I am not sure what we count exactly, I would guess the number of values that were not synchronized (including deletions). This does not matter much, it is simply a measure of how bad the inconsistencies are (so the lower the better)
function count_oos_ranges() {
  # Don't ask, it does the job
  # INFO [RepairJobTask:6] 2016-09-05 19:34:44,209 Differencer.java (line 74) [repair #fd1dfcd0-738e-11e6-9629-d73a97f36a2a] Endpoints /37.187.75.226 and /37.187.76.11 have 12279 range(s) out of sync for url_id_mapping_v2
  cat /var/log/cassandra/system.log* | grep 'RepairJobTask' | grep 'Differencer' | grep 'out of sync' | sed 's/.*RepairJobTask:[0-9]*\] \(.*\) Differencer.*have \([0-9]*\).*/\1\t\2/' | while read line; do line_date=$(echo "$line" | cut -f 1); line_date=$(date -d"$line_date" +%s); if [[ $line_date -ge $launch_time ]]; then oos_ranges=$(($oos_ranges + $(echo "$line" | cut -f 2))); echo $oos_ranges; fi; done | tail -1
}

keyspace=$1
table=$2 # This can be empty, all tables of the keyspace will be repaired

if [[ -z $keyspace ]]; then
    echo "Usage: $0 <keyspace> (<table>)"
    exit 1
fi

# For readable display, we use the hostname contained in '/root/.pshostname' if it exists, otherwise the one in /etc/hostname
[[ -f /root/.pshostname ]] && host=$(cat /root/.pshostname | tail -1) || host=$(hostname)
launch_time=$(date +%s)

# This file will store the output of the 'nodetool repair' command. We use it to find token ranges that weren't properly repaired, and try to repair them a second time
# directory=$(dirname $0)
directory="/var/log/mediego/repair/"
mkdir -p $directory
output=${directory}/repair-${keyspace}.${table}_$(date +%Y-%m-%d_%H:%M).log

com="nodetool repair -pr -- \"$keyspace\" $table"
log_info "Launching repair of $keyspace $table on server $host"
log_debug "Executing command: $com"

begin=$(date +%s)
eval "$com" 2>&1 >> $output

# The log file will have our header line, "Starting repair" line, a report line per range, and a "finished" line
# It can happen that some ranges cannot be synchronised, typically because one node is unable to make a snapshot of its data, in that case we manually repair these ranges
# Example of a successful repaired range:
#[2016-02-16 17:03:51,940] Repair session 0b275860-d4c2-11e5-b871-e3f473ea3350 for range (2209830215986591819,2216072538797147030] finished
# Example of a failed repair:
#[2016-02-16 17:03:51,940] Repair session 1f7abeb0-d4c2-11e5-b871-e3f473ea3350 for range (8159655905029810525,8163644596446133190] failed with error java.io.IOException: Failed during snapshot creation.

successful_repairs=$(grep 'Repair session.*finished' $output | wc -l)
failed_repairs=$(grep 'Repair session.*failed with error' $output | wc -l)
repair_attempts=$(($successful_repairs + $failed_repairs))
oos_ranges=$(count_oos_ranges)
[[ -z $oos_ranges ]] && oos_ranges=0
log_info "Successfully repaired $successful_repairs/$repair_attempts ranges after $(pretty_time $begin), $oos_ranges entries were found out of sync"

if [[ $failed_repairs -gt 0 ]]; then
  begin_extra=$(date +%s)
  successful_extra_repair=0
  # grep found at least one line with errors, we display it and try to repair it
  log_info "$failed_repairs ranges were not properly repaired, re-trying now."
  while read line; do
    begin=$(date +%s)
    start=$(echo $line | sed 's/.*for range (\([0-9-]*\),\([0-9-]*\)\] failed.*/\1/') # We extract the token range that failed
    end=$(echo $line | sed 's/.*for range (\([0-9-]*\),\([0-9-]*\)\] failed.*/\2/')
    if [ "$start" -ne "$start" ] 2> /dev/null || [ "$end" -ne "$end" ] 2> /dev/null ; then # If the range is not numerical, we skip it
      log_info "**WARNING**: could not extract range from the following line, you should check what happened:"
      log_info $line
      continue
    fi
    com="nodetool repair -st $start -et $end -- \"$keyspace\" $table"
    log_debug "Re-trying to repair range with command: $com"
    eval "$com" 2>&1 >> $output
    if grep -q "Repair session.*for range (${start},${end}\] finished" $output; then # We check if the repair succeeded, by searching for the success line in the log
      successful_extra_repair=$(($successful_extra_repair + 1))
      log_debug "Success after $(pretty_time $begin)"
    else
      log_info "**WARNING**: failed to repair range $start:$end after $(pretty_time $begin)"
    fi
  done < <(grep 'Repair session.*failed with error' $output)
  log_info "Successfully repaired $successful_extra_repair/$failed_repairs originaly failed ranges after $(pretty_time $begin_extra)"
  log_info "In total, $(($successful_repairs + $successful_extra_repair))/$repair_attempts were successfully repaired"
fi

log_info "Total repair time for server $host: $(pretty_time $launch_time)"
