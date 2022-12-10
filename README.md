# Provably Fair minting Proof of Concept
The random_minting.sh script scans the wallet every 5 mins to retrieve all the valid tx.
If supposes only 1 NFT is minted at a time, no multiples supported in the script.
So for a 0.1 xch mint it will filter only the 0.1 xch tx in the wallet.

It's all written in bash, but could/should be written in Python.

## Requirements
You need to be logged in your wallet/fingerprint, and you need to have a full node running in order to make full node rpc calls when retrieving the sender xch address. Computing the sender xch address also requires the **chia-dev-tools** to encode from bech32m to xch address.

This tool is only available for linux OS.

## Proof of Concept
The Peacocks are meant to be a Proof of Concept of provably fair random minting.

TheChunksNFT rely on block header hashes but the Peacocks use the transaction hash id as input for randomness.
One could imagine using different source of randomness from the blockchain.
One could even implement WL mint, or max per wallet mints if you check the public key used for tx.
