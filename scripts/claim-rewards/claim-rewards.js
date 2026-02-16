#!/usr/bin/env node
/**
 * StarkNet Validator Reward Claimer
 *
 * Automates claiming staking rewards for StarkNet validators.
 * Uses the official StarkNet staking contract.
 */

import { RpcProvider, Account, Contract, cairo } from 'starknet';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load .env from project root
dotenv.config({ path: join(__dirname, '../../.env') });

// StarkNet Mainnet Staking Contract
const STAKING_CONTRACT_ADDRESS = '0x00ca1702e64c81d9a07b86bd2c540188d92a2c73cf5cc0e508d949015e7e84a7';

// Minimal ABI for the staking contract
const STAKING_ABI = [
  {
    name: 'claim_rewards',
    type: 'function',
    inputs: [{ name: 'staker_address', type: 'core::starknet::contract_address::ContractAddress' }],
    outputs: [{ type: 'core::integer::u128' }],
    state_mutability: 'external'
  },
  {
    name: 'internal_staker_info',
    type: 'function',
    inputs: [{ name: 'staker_address', type: 'core::starknet::contract_address::ContractAddress' }],
    outputs: [
      { name: 'reward_address', type: 'core::starknet::contract_address::ContractAddress' },
      { name: 'operational_address', type: 'core::starknet::contract_address::ContractAddress' },
      { name: 'unstake_time', type: 'core::option::Option::<core::integer::u64>' },
      { name: 'amount_own', type: 'core::integer::u128' },
      { name: 'index', type: 'core::integer::u64' },
      { name: 'unclaimed_rewards_own', type: 'core::integer::u128' },
      { name: 'pool_info', type: 'core::option::Option::<core::starknet::contract_address::ContractAddress>' }
    ],
    state_mutability: 'view'
  }
];

// Validator configurations from environment
// Can use either dedicated reward account OR operational account to claim
const VALIDATORS = [
  {
    name: 'Suffix',
    stakerAddress: process.env.SUFFIX_STAKER_ADDRESS,
    // Prefer reward account if set, fall back to operational account
    accountAddress: process.env.SUFFIX_REWARD_ACCOUNT_ADDRESS || process.env.SUFFIX_VALIDATOR_STAKER_OPERATIONAL_ADDRESS,
    privateKey: process.env.SUFFIX_REWARD_ACCOUNT_PRIVATE_KEY || process.env.SUFFIX_VALIDATOR_OPERATIONAL_PRIVATE_KEY,
    enabled: process.env.SUFFIX_CLAIM_ENABLED !== 'false'
  },
  {
    name: 'Ethchi',
    stakerAddress: process.env.ETHCHI_STAKER_ADDRESS,
    accountAddress: process.env.ETHCHI_REWARD_ACCOUNT_ADDRESS || process.env.ETHCHI_VALIDATOR_STAKER_OPERATIONAL_ADDRESS,
    privateKey: process.env.ETHCHI_REWARD_ACCOUNT_PRIVATE_KEY || process.env.ETHCHI_VALIDATOR_OPERATIONAL_PRIVATE_KEY,
    enabled: process.env.ETHCHI_CLAIM_ENABLED !== 'false'
  }
];

const DRY_RUN = process.env.DRY_RUN === 'true';

async function getProvider() {
  const rpcUrl = process.env.STARKNET_RPC_URL || 'https://starknet-mainnet.g.alchemy.com/starknet/version/rpc/v0_7/demo';
  return new RpcProvider({ nodeUrl: rpcUrl });
}

async function checkUnclaimedRewards(provider, stakerAddress) {
  try {
    const contract = new Contract(STAKING_ABI, STAKING_CONTRACT_ADDRESS, provider);
    const result = await contract.internal_staker_info(stakerAddress);

    const formatAddress = (v) => '0x' + BigInt(v).toString(16).padStart(64, '0');
    const formatStrk = (v) => (Number(BigInt(v)) / 1e18).toFixed(4) + ' STRK';

    console.log(`  Reward Address: ${formatAddress(result.reward_address)}`);
    console.log(`  Operational Address: ${formatAddress(result.operational_address)}`);
    console.log(`  Staked Amount: ${formatStrk(result.amount_own)}`);

    return result;
  } catch (error) {
    console.log(`  Could not fetch staker info: ${error.message}`);
    return null;
  }
}

async function claimRewards(validator) {
  const { name, stakerAddress, accountAddress, privateKey, enabled } = validator;

  console.log(`\n${'='.repeat(60)}`);
  console.log(`Processing ${name} Validator`);
  console.log(`${'='.repeat(60)}`);

  if (!enabled) {
    console.log(`  Skipped: Claiming disabled for ${name}`);
    return { validator: name, status: 'disabled' };
  }

  if (!stakerAddress) {
    console.log(`  Skipped: Missing STAKER_ADDRESS for ${name}`);
    return { validator: name, status: 'missing_staker_address' };
  }

  if (!accountAddress || !privateKey) {
    console.log(`  Skipped: Missing reward account credentials for ${name}`);
    return { validator: name, status: 'missing_credentials' };
  }

  console.log(`  Staker Address: ${stakerAddress}`);
  console.log(`  Reward Account: ${accountAddress}`);

  try {
    const provider = await getProvider();

    // Check unclaimed rewards first
    console.log(`  Checking unclaimed rewards...`);
    await checkUnclaimedRewards(provider, stakerAddress);

    if (DRY_RUN) {
      console.log(`  [DRY RUN] Would claim rewards for staker: ${stakerAddress}`);
      return { validator: name, status: 'dry_run' };
    }

    // Create account instance for the reward account (who will receive and can call claim)
    const account = new Account(provider, accountAddress, privateKey);

    // Create contract instance connected to the account
    const contract = new Contract(STAKING_ABI, STAKING_CONTRACT_ADDRESS, account);

    console.log(`  Submitting claim_rewards transaction...`);

    // Call claim_rewards with the staker address
    const call = contract.populate('claim_rewards', [stakerAddress]);
    const { transaction_hash } = await account.execute(call);

    console.log(`  Transaction submitted: ${transaction_hash}`);
    console.log(`  Waiting for confirmation...`);

    // Wait for transaction to be confirmed
    const receipt = await provider.waitForTransaction(transaction_hash);

    if (receipt.execution_status === 'SUCCEEDED') {
      console.log(`  SUCCESS: Rewards claimed!`);
      console.log(`  View on Starkscan: https://starkscan.co/tx/${transaction_hash}`);
      return { validator: name, status: 'success', txHash: transaction_hash };
    } else {
      console.log(`  FAILED: Transaction reverted`);
      console.log(`  Status: ${receipt.execution_status}`);
      return { validator: name, status: 'reverted', txHash: transaction_hash };
    }

  } catch (error) {
    console.error(`  ERROR: ${error.message}`);
    return { validator: name, status: 'error', error: error.message };
  }
}

async function main() {
  console.log('StarkNet Validator Reward Claimer');
  console.log('==================================');
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (no transactions will be sent)' : 'LIVE'}`);
  console.log(`Staking Contract: ${STAKING_CONTRACT_ADDRESS}`);
  console.log(`RPC: ${process.env.STARKNET_RPC_URL || 'https://starknet-mainnet.g.alchemy.com/starknet/version/rpc/v0_7/demo'}`);

  const results = [];

  for (const validator of VALIDATORS) {
    const result = await claimRewards(validator);
    results.push(result);
  }

  // Summary
  console.log(`\n${'='.repeat(60)}`);
  console.log('Summary');
  console.log(`${'='.repeat(60)}`);

  for (const result of results) {
    const statusEmoji = {
      success: '[OK]',
      dry_run: '[DRY]',
      disabled: '[SKIP]',
      missing_staker_address: '[SKIP]',
      missing_credentials: '[SKIP]',
      reverted: '[FAIL]',
      error: '[ERR]'
    }[result.status] || '[?]';

    console.log(`  ${statusEmoji} ${result.validator}: ${result.status}`);
    if (result.txHash) {
      console.log(`      TX: ${result.txHash}`);
    }
    if (result.error) {
      console.log(`      Error: ${result.error}`);
    }
  }

  const successCount = results.filter(r => r.status === 'success').length;
  const errorCount = results.filter(r => ['error', 'reverted'].includes(r.status)).length;

  console.log(`\nCompleted: ${successCount} successful, ${errorCount} errors`);

  // Exit with error code if any claims failed
  if (errorCount > 0) {
    process.exit(1);
  }
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
