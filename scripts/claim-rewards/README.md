# StarkNet Validator Reward Claimer

Automated script to claim staking rewards from the StarkNet staking contract.

## Staking Contract

**Mainnet Address:** `0x00ca1702e64c81d9a07b86bd2c540188d92a2c73cf5cc0e508d949015e7e84a7`

Reference: [StarkNet Staking Documentation](https://docs.starknet.io/staking/overview)

## Finding Your Staker Address

If you don't know your staker address, run the lookup script (requires your operational address in `.env`):

```bash
node lookup-staker.js
```

This queries the staking contract using `get_attestation_info_by_operational_address()` and prints the staker address in hex format.

## Setup

1. Install dependencies:
   ```bash
   cd scripts/claim-rewards
   npm install
   ```

2. Configure your `.env` file in the project root with the reward claiming variables:
   ```bash
   # StarkNet RPC (public endpoint or your own)
   STARKNET_RPC_URL=https://starknet-mainnet.public.blastapi.io

   # Suffix Validator
   SUFFIX_STAKER_ADDRESS=0x...       # Your staker address on the staking contract
   SUFFIX_REWARD_ACCOUNT_ADDRESS=0x... # Account that receives rewards
   SUFFIX_REWARD_ACCOUNT_PRIVATE_KEY=0x... # Private key for reward account
   SUFFIX_CLAIM_ENABLED=true

   # Ethchi Validator (same structure)
   ETHCHI_STAKER_ADDRESS=0x...
   ETHCHI_REWARD_ACCOUNT_ADDRESS=0x...
   ETHCHI_REWARD_ACCOUNT_PRIVATE_KEY=0x...
   ETHCHI_CLAIM_ENABLED=true
   ```

## Usage

### Dry Run (recommended first)
```bash
npm run claim:dry-run
```

This checks your configuration and shows what would be claimed without sending transactions.

### Claim Rewards
```bash
npm run claim
```

This will:
1. Connect to StarkNet mainnet
2. For each enabled validator:
   - Check unclaimed rewards
   - Submit a `claim_rewards` transaction
   - Wait for confirmation
3. Print a summary of results

## Running on a Schedule (Cron)

To automate weekly claims:

```bash
# Edit crontab
crontab -e

# Add this line to claim every Monday at 9 AM
0 9 * * 1 cd /path/to/sn-vali-manager/scripts/claim-rewards && /usr/bin/npm run claim >> /var/log/starknet-claim.log 2>&1
```

## Security Notes

- The reward account private key is used to sign claim transactions
- The reward account can be different from your staker account (recommended for security)
- Use a dedicated "hot" account for claims, keeping your main staker key cold
- Never commit `.env` files with real private keys

## Troubleshooting

**"Missing STAKER_ADDRESS"**: Ensure `SUFFIX_STAKER_ADDRESS` or `ETHCHI_STAKER_ADDRESS` is set in `.env`

**"Transaction reverted"**: Common causes:
- No unclaimed rewards available
- Wrong reward account (must be the designated reward address for the staker)
- Staking contract paused

**RPC errors**: Try a different RPC endpoint:
- `https://starknet-mainnet.g.alchemy.com/starknet/version/rpc/v0_7/demo` (default)
- Your own Pathfinder node: `http://localhost:9545`
