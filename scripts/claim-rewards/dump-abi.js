#!/usr/bin/env node
import { RpcProvider } from 'starknet';

const STAKING_CONTRACT = '0x00ca1702e64c81d9a07b86bd2c540188d92a2c73cf5cc0e508d949015e7e84a7';
const RPC_URL = 'https://starknet-mainnet.g.alchemy.com/starknet/version/rpc/v0_7/demo';

async function main() {
  const provider = new RpcProvider({ nodeUrl: RPC_URL });

  const classHash = await provider.getClassHashAt(STAKING_CONTRACT);
  const contractClass = await provider.getClass(classHash);

  // Find internal_staker_info function definition
  console.log('=== Looking for internal_staker_info ===\n');

  for (const item of contractClass.abi) {
    if (item.type === 'interface' && item.items) {
      for (const fn of item.items) {
        if (fn.name === 'internal_staker_info') {
          console.log(JSON.stringify(fn, null, 2));
        }
      }
    }
  }

  // Also look for any struct definitions that might be relevant
  console.log('\n=== Struct definitions ===\n');
  for (const item of contractClass.abi) {
    if (item.type === 'struct' && item.name?.includes('Staker')) {
      console.log(JSON.stringify(item, null, 2));
    }
  }
}

main().catch(console.error);
