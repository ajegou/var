alias rm='rm -I'
alias h='head -n 1'
alias t='tail -n 1'
alias ds='du -sh'
alias lsa='ls -a'
alias lrt='ls --color -lrtha --group-directories-first'
alias lsd='ls --color -lhad .*/ && ls --color -lhad */'

alias gdf='git difftool -y'
alias st='git status'
alias co='git checkout'

alias mkdit='mkdir'

function sss() {
  if [[ -z $1 ]]; then
    echo "Missing target host"
  else
    ssh -t "$1" "cd /var/log/$2/; bash;"
  fi
}

function o() {
	sleep_time=$(cat /dev/urandom | tr -dc '0-9' | fold -w 1 | head -n 1)
	echo "Sleep time is $sleep_time"
	sleep $sleep_time
	file=/tmp/ovh_roll
	touch $file
	target=$(tail -n 4 $file | sort | awk '{if($1 != NR && !target) {target=NR;}}END{if(!target) {target=5}; print target}')
	echo "Target server is o$target"
	echo $target >> $file
	sss root@o$target
}

function display_json_time() {
  local src_file=$1
  if [[ -z $1 ]]; then
    src_file=$(ls -rt timelogging-*.log | tail -n 1)
  fi
  echo "Extracting json from file <$src_file>"
  echo "[$(cat $src_file)]" | sed 's/}$/},/' | python -mjson.tool
}
