#!/bin/bash

function padd() {
  to_padd="$1"
  padd_to="$2"
  padd_char=$3
  while [[ ${#to_padd} -lt ${#padd_to} ]]; do
    to_padd=${to_padd}${padd_char}
  done
  echo $to_padd
}

function xor() {
  string_1=$1
  string_2=$2
  xored_string=""
  for ((i=0; i < ${#string_1}; i++ )); do
    # convert to decimal
    first=$(printf "%d" "'${string_1:$i:1}")
    second=$(printf "%d" "'${string_2:$i:1}")
    xored_char=$(printf \\$(printf '%03o' $((first ^ second)) ))
    xored_string="${xored_string}${xored_char}"
  done
  echo $xored_string
}

function random_from_pass() {
  RANDOM=$(printf "%d" "'$1")
  length=$2
  random_key=""
  while [[ ${#random_key} -lt $length ]]; do
    random_key=${random_key}$RANDOM
  done
  echo $random_key
}

true_secret=$(cat $1)
false_secret=$(cat $2)
passphrase=$3

echo "True secret is $true_secret"
echo "False secret is $false_secret"
echo "Passphrase is $passphrase"

random_key=$(random_from_pass "$passphrase" ${#false_secret})

true_secret=$(padd "$true_secret" "$false_secret" "#")
true_secret=$(padd "$true_secret" "$random_key" "_")
false_secret=$(padd "$false_secret" "$random_key" "_")

public_key=$(xor "$true_secret" "$random_key")
false_key=$(xor "$public_key" "$false_secret")

echo "True secret is $true_secret"
echo "False secret is $false_secret"
echo "Passphrase is $passphrase"
echo "Random key is $random_key"
echo "Public key is $public_key"
echo "False key is $false_key"

read -p 'Decoding with passphrase: ' pass
decoding_key=$(random_from_pass "$pass" ${#public_key})
echo "Decoding key: $decoding_key"
echo $(xor "$public_key" "$decoding_key")
echo "False decoding: $(xor "$false_key" "$public_key")"
