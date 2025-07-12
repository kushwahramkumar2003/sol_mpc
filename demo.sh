#!/usr/bin/env bash
set -e

party_1() {
  printf "\e[1;4;31mParty 1: %s\e[0m\n" "$1"
}

party_2() {
  printf "\e[1;4;34mParty 2: %s\e[0m\n" "$1"
}

party_3() {
  printf "\e[1;4;35mParty 3: %s\e[0m\n" "$1"
}

all_parties() {
  printf "\e[1;4;33m%s\e[0m\n" "$1"
}

cargo build
cd ./target/debug/ || exit
PATH="$PATH:."

party_1 "Generate Shares"
keypair1=$(sol_mpc generate)
pubkey1=$(echo "$keypair1" | tail -1 | cut -d " " -f3)
secretkey1=$(echo "$keypair1" | head -1 | cut -d " " -f3)
printf "secret share: %s\npublic share: %s \n" "$secretkey1" "$pubkey1"

party_2 "Generate Shares"
keypair2=$(sol_mpc generate)
pubkey2=$(echo "$keypair2" | tail -1 | cut -d " " -f3)
secretkey2=$(echo "$keypair2" | head -1 | cut -d " " -f3)
printf "secret share: %s\npublic share: %s \n" "$secretkey2" "$pubkey2"

party_3 "Generate Shares"
keypair3=$(sol_mpc generate)
pubkey3=$(echo "$keypair3" | tail -1 | cut -d " " -f3)
secretkey3=$(echo "$keypair3" | head -1 | cut -d " " -f3)
printf "secret share: %s\npublic share: %s \n\n" "$secretkey3" "$pubkey3"

all_parties "Aggregate the Shares(either party can execute)"
aggkey_text=$( sol_mpc aggregate-keys "$pubkey1" "$pubkey2" "$pubkey3" )
aggkey=$(echo "$aggkey_text" | tail -1 | cut -d " " -f5)
printf "The Aggregated Public Key: %s\n\n" "$aggkey"

all_parties "Airdrop to aggregated key"
sol_mpc airdrop --net local --to "$aggkey" --amount 10
sleep 2

all_parties "Check balance of aggregated key"
balance=$(sol_mpc balance --net local $aggkey | cut -d " " -f6)
printf "The balance of %s is: %s\n\n" "$aggkey" "$balance"

all_parties "Receiver key and balance"
keypair_reciever=$( sol_mpc generate )
reciever_key=$(echo "$keypair_reciever" | tail -1 | cut -d " " -f3)
balance=$(sol_mpc balance --net local "$reciever_key" | cut -d " " -f6)
printf "The balance of %s is: %s\n\n" "$reciever_key" "$balance"

printf "\e[1;4;32mSending 5 SOL to %s\e[0m\n\n" "$reciever_key"

party_1 "Generate message 1"
party1_raw=$( sol_mpc agg-send-step-one --keypair "$secretkey1" )
party1msg1=$(echo "$party1_raw" | head -1 | cut -d " " -f3)
party1state=$(echo "$party1_raw" | tail -1 | cut -d " " -f3)
printf "Message 1: %s (send to all other parties)\nSecret state: %s (keep this a secret, and pass it back to \`agg-send-step-two\`)\n" "$party1msg1" "$party1state"

party_2 "Generate message 1"
party2_raw=$( sol_mpc agg-send-step-one --keypair "$secretkey2" )
party2msg1=$(echo "$party2_raw" | head -1 | cut -d " " -f3)
party2state=$(echo "$party2_raw" | tail -1 | cut -d " " -f3)
printf "Message 1: %s (send to all other parties)\nSecret state: %s (keep this a secret, and pass it back to \`agg-send-step-two\`)\n" "$party2msg1" "$party2state"

party_3 "Generate message 1"
party3_raw=$( sol_mpc agg-send-step-one --keypair "$secretkey3" )
party3msg1=$(echo "$party3_raw" | head -1 | cut -d " " -f3)
party3state=$(echo "$party3_raw" | tail -1 | cut -d " " -f3)
printf "Message 1: %s (send to all other parties)\nSecret state: %s (keep this a secret, and pass it back to \`agg-send-step-two\`)\n\n" "$party3msg1" "$party3state"

all_parties "Check recent block hash"
recent_block_hash=$( sol_mpc recent-block-hash --net local )
recent_block_hash=$(echo "$recent_block_hash" | cut -d " " -f4)
printf "Recent block hash: %s\n\n" "$recent_block_hash"

party_1 "Process message 1 and generate partial signature"
party1_raw=$( sol_mpc agg-send-step-two --keypair "$secretkey1" --to "$reciever_key" --amount 5 --memo "3 Party Signing" --recent-block-hash "$recent_block_hash" --keys "$pubkey1" "$pubkey2" "$pubkey3" --first-messages "$party2msg1" "$party3msg1" --secret-state "$party1state" )
partialsig1=$(echo "$party1_raw" | cut -d " " -f3)
printf "Partial signature: %s\n" "$partialsig1"

party_2 "Process message 1 and generate partial signature"
party2_raw=$( sol_mpc agg-send-step-two --keypair "$secretkey2" --to "$reciever_key" --amount 5 --memo "3 Party Signing" --recent-block-hash "$recent_block_hash" --keys "$pubkey1" "$pubkey2" "$pubkey3" --first-messages "$party1msg1" "$party3msg1" --secret-state "$party2state" )
partialsig2=$(echo "$party2_raw" | cut -d " " -f3)
printf "Partial signature: %s\n" "$partialsig2"

party_3 "Process message 1 and generate partial signature"
party3_raw=$( sol_mpc agg-send-step-two --keypair "$secretkey3" --to "$reciever_key" --amount 5 --memo "3 Party Signing" --recent-block-hash "$recent_block_hash" --keys "$pubkey1" "$pubkey2" "$pubkey3" --first-messages "$party1msg1" "$party2msg1" --secret-state "$party3state" )
partialsig3=$(echo "$party3_raw" | cut -d " " -f3)
printf "Partial signature: %s\n\n" "$partialsig3"

all_parties "Combine the signatures and send"
raw=$( sol_mpc aggregate-signatures-and-broadcast --net local --to "$reciever_key" --amount 5 --memo "3 Party Signing" --recent-block-hash "$recent_block_hash" --keys "$pubkey1" "$pubkey2" "$pubkey3" --signatures "$partialsig1" "$partialsig2" "$partialsig3")
printf "%s\n\n" "$raw"

all_parties "Receiver new balance"
balance=$(sol_mpc balance --net local "$reciever_key" | cut -d " " -f6)
printf "The balance of %s is: %s\n" "$reciever_key" "$balance"