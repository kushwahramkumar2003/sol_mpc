use std::str::FromStr;

use clap::{command, Parser};
use solana_sdk::hash::Hash;
use solana_sdk::pubkey::Pubkey;

use crate::error::Error;
use crate::serialization::{AggMessage1, PartialSignature, SecretAggStepOne, Serialize};

// Wrapper functions to fix lifetime issues with clap's value_parser
fn parse_agg_message1(s: &str) -> Result<AggMessage1, crate::serialization::Error> {
    AggMessage1::deserialize_bs58(s)
}

fn parse_secret_agg_step_one(s: &str) -> Result<SecretAggStepOne, crate::serialization::Error> {
    SecretAggStepOne::deserialize_bs58(s)
}

fn parse_partial_signature(s: &str) -> Result<PartialSignature, crate::serialization::Error> {
    PartialSignature::deserialize_bs58(s)
}

#[derive(Parser, Debug)]
#[command(about, version, author)]
pub enum Options {
    /// Generate a pair of keys.
    Generate,
    /// Check the balance of an address.
    Balance {
        /// The address to check the balance of
        address: Pubkey,
        /// Choose the desired network: Mainnet/Testnet/Devnet/Local
        #[arg(default_value = "testnet", long)]
        net: Network,
    },
    /// Request an airdrop from a faucet.
    Airdrop {
        /// Address of the recipient
        #[arg(long)]
        to: Pubkey,
        /// The amount of SOL you want to send.
        #[arg(long)]
        amount: f64,
        /// Choose the desired network: Mainnet/Testnet/Devnet/Local
        #[arg(default_value = "testnet", long)]
        net: Network,
    },
    /// Send a transaction using a single private key.
    SendSingle {
        /// A Base58 secret key
        #[arg(long)]
        keypair: String,
        /// The amount of SOL you want to send.
        #[arg(long)]
        amount: f64,
        /// Address of the recipient
        #[arg(long)]
        to: Pubkey,
        /// Choose the desired network: Mainnet/Testnet/Devnet/Local
        #[arg(default_value = "testnet", long)]
        net: Network,
        /// Add a memo to the transaction
        #[arg(long)]
        memo: Option<String>,
    },
    /// Print the hash of a recent block, can be used to pass to the `agg-send` steps
    RecentBlockHash {
        /// Choose the desired network: Mainnet/Testnet/Devnet/Local
        #[arg(default_value = "testnet", long)]
        net: Network,
    },
    /// Aggregate a list of addresses into a single address that they can all sign on together
    AggregateKeys {
        /// List of addresses
        #[arg(num_args = 2.., required = true)]
        keys: Vec<Pubkey>,
    },
    /// Start aggregate signing
    AggSendStepOne {
        /// A Base58 secret key of the party signing
        #[arg(long)]
        keypair: String,
    },
    /// Step 2 of aggregate signing, you should pass in the secret data from step 1.
    /// It's important that all parties pass in exactly the same transaction details (amount,to,net,memo,recent_block_hash)
    AggSendStepTwo {
        /// A Base58 secret key of the party signing
        #[arg(long)]
        keypair: String,
        /// The amount of SOL you want to send.
        #[arg(long)]
        amount: f64,
        /// Address of the recipient
        #[arg(long)]
        to: Pubkey,
        /// Add a memo to the transaction
        #[arg(long)]
        memo: Option<String>,
        /// A hash of a recent block, can be obtained by calling `recent-block-hash`, all parties *must* pass in the same hash.
        #[arg(long)]
        recent_block_hash: Hash,
        /// List of addresses that are part of this
        #[arg(long, required = true, num_args = 2..)]
        keys: Vec<Pubkey>,
        /// A list of all the first messages received in step 1
        #[arg(long, required = true, num_args = 1.., value_parser = parse_agg_message1)]
        first_messages: Vec<AggMessage1>,
        /// The secret state received in step 2.
        #[arg(long, value_parser = parse_secret_agg_step_one)]
        secret_state: SecretAggStepOne,
    },
    /// Aggregate all the partial signatures together into a full signature, and send the transaction to Solana
    AggregateSignaturesAndBroadcast {
        // A list of all partial signatures produced in step three.
        #[arg(long, required = true, num_args = 2.., value_parser = parse_partial_signature)]
        signatures: Vec<PartialSignature>,
        /// The amount of SOL you want to send.
        #[arg(long)]
        amount: f64,
        /// Address of the recipient
        #[arg(long)]
        to: Pubkey,
        /// Add a memo to the transaction
        #[arg(long)]
        memo: Option<String>,
        /// A hash of a recent block, can be obtained by calling `recent-block-hash`, all parties *must* pass in the same hash.
        #[arg(long)]
        recent_block_hash: Hash,
        /// Choose the desired network: Mainnet/Testnet/Devnet/Local
        #[arg(default_value = "testnet", long)]
        net: Network,
        /// List of addresses
        #[arg(long, required = true, num_args = 2..)]
        keys: Vec<Pubkey>,
    },
}

#[derive(Debug, Clone)]
pub enum Network {
    Mainnet,
    Testnet,
    Devnet,
    Local,
}

impl Network {
    pub fn get_cluster_url(&self) -> &'static str {
        match self {
            Self::Mainnet => "https://api.mainnet-beta.solana.com",
            Self::Testnet => "https://api.testnet.solana.com",
            Self::Devnet => "https://api.devnet.solana.com",
            Self::Local => "http://127.0.0.1:8899",
        }
    }
}

impl FromStr for Network {
    type Err = Error;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "mainnet" => Ok(Self::Mainnet),
            "testnet" => Ok(Self::Testnet),
            "devnet" => Ok(Self::Devnet),
            "local" => Ok(Self::Local),
            _ => Err(Error::WrongNetwork(s.to_string())),
        }
    }
}