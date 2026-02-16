#!/usr/bin/env node
/**
 * Look up staker address from operational address
 */

import { RpcProvider, Contract } from 'starknet';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '../../.env') });

const STAKING_CONTRACT = '0x00ca1702e64c81d9a07b86bd2c540188d92a2c73cf5cc0e508d949015e7e84a7';
const RPC_URL = process.env.STARKNET_RPC_URL || 'https://starknet-mainnet.g.alchemy.com/starknet/version/rpc/v0_7/demo';

// Minimal ABI for lookup functions
const ABI = [
  {
    name: 'get_attestation_info_by_operational_address',
    type: 'function',
    inputs: [{ name: 'operational_address', type: 'core::starknet::contract_address::ContractAddress' }],
    outputs: [{ type: '(core::starknet::contract_address::ContractAddress, core::integer::u64)' }],
    state_mutability: 'view'
  },
  {
    name: 'staker_info_v1',
    type: 'function',
    inputs: [{ name: 'staker_address', type: 'core::starknet::contract_address::ContractAddress' }],
    outputs: [{ type: 'contracts::staking::objects::StakerInfoV1' }],
    state_mutability: 'view'
  }
];

async function lookupByOperational(provider, contract, name, operationalAddress) {
  console.log(`\n=== ${name} ===`);
  console.log(`Operational Address: ${operationalAddress}`);

  try {
    const result = await contract.get_attestation_info_by_operational_address(operationalAddress);
    console.log('Raw result:', result);

    // Result is tuple: (staker_address, epoch)
    const stakerAddressRaw = result[0] || result.staker_address;
    const stakerAddress = '0x' + BigInt(stakerAddressRaw).toString(16).padStart(64, '0');
    console.log(`\nStaker Address: ${stakerAddress}`);

    // Now get full staker info
    try {
      const stakerInfo = await contract.staker_info_v1(stakerAddress);
      console.log('\nStaker Info:');
      console.log(JSON.stringify(stakerInfo, (k, v) => typeof v === 'bigint' ? v.toString() : v, 2));
    } catch (e) {
      console.log(`Could not fetch staker info: ${e.message}`);
    }

    return stakerAddress;
  } catch (error) {
    console.log(`Error: ${error.message}`);
    return null;
  }
}

async function main() {
  const provider = new RpcProvider({ nodeUrl: RPC_URL });
  const contract = new Contract(ABI, STAKING_CONTRACT, provider);

  console.log('StarkNet Staker Address Lookup');
  console.log('==============================');
  console.log(`RPC: ${RPC_URL}`);

  const validators = [
    { name: 'Suffix', operational: process.env.SUFFIX_VALIDATOR_STAKER_OPERATIONAL_ADDRESS },
    { name: 'Ethchi', operational: process.env.ETHCHI_VALIDATOR_STAKER_OPERATIONAL_ADDRESS }
  ];

  const results = [];

  for (const v of validators) {
    if (v.operational && v.operational !== '0x1234567890123456789012345678901234567890') {
      const stakerHex = await lookupByOperational(provider, contract, v.name, v.operational);
      results.push({ name: v.name, staker: stakerHex });
    } else {
      console.log(`\n=== ${v.name} ===`);
      console.log('Skipped: No operational address configured in .env');
    }
  }

  console.log('\n==============================');
  console.log('Summary - Add these to your .env:');
  console.log('==============================');
  for (const r of results) {
    if (r.staker) {
      console.log(`${r.name.toUpperCase()}_STAKER_ADDRESS=${r.staker}`);
    }
  }
}

main().catch(console.error);
