#!/usr/bin/env node
/**
 * Get staking data for daily summary
 * Outputs JSON with unclaimed rewards and operational balances
 */

import { Contract, RpcProvider } from 'starknet';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const RPC_URL = process.env.STARKNET_RPC_URL || 'https://starknet-mainnet.g.alchemy.com/starknet/version/rpc/v0_7/demo';
const STAKING_CONTRACT = '0x00ca1702e64c81d9a07b86bd2c540188d92a2c73cf5cc0e508d949015e7e84a7';
const STRK_TOKEN = '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d';
const ETH_TOKEN = '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7';

const VALIDATORS = [
  {
    name: 'Suffix',
    staker: '0x02dc260794e4c2eeae87b1403a88385a72c18a5844d220b88117b2965a8cf3a5',
    operational: '0x073c1316211c70bb44f6976515d0db7b408d99f4adcfd14ca3a0a044a48e1a21'
  },
  {
    name: 'Ethchi',
    staker: '0x0223d82a4ea1c98b163a4c7b9921202613f2b335292216e215a9a03d20fea2b2',
    operational: '0x07912a3ee4a22c70fc7e0a093e885545872741f64b9992bbb2530321ef5fcad6'
  }
];

const ERC20_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    inputs: [{ name: 'account', type: 'core::starknet::contract_address::ContractAddress' }],
    outputs: [{ type: 'core::integer::u256' }],
    state_mutability: 'view'
  }
];

async function main() {
  const provider = new RpcProvider({ nodeUrl: RPC_URL });

  // Load staking ABI from local file (baked into Docker image)
  const stakingAbi = JSON.parse(readFileSync(join(__dirname, 'staking-abi.json'), 'utf-8'));

  const stakingContract = new Contract(stakingAbi, STAKING_CONTRACT, provider);
  const strkContract = new Contract(ERC20_ABI, STRK_TOKEN, provider);
  const ethContract = new Contract(ERC20_ABI, ETH_TOKEN, provider);

  const toStrk = (v) => (Number(BigInt(v)) / 1e18).toFixed(2);
  const results = {};

  for (const v of VALIDATORS) {
    try {
      const info = await stakingContract.staker_info_v1(v.staker);
      const strkBal = await strkContract.balanceOf(v.operational);
      const ethBal = await ethContract.balanceOf(v.operational);

      results[v.name] = {
        unclaimed: toStrk(info.unclaimed_rewards_own),
        staked: toStrk(info.amount_own),
        strk: toStrk(strkBal),
        eth: toStrk(ethBal)
      };
    } catch (e) {
      results[v.name] = { error: e.message };
    }
  }

  const output = JSON.stringify(results);

  // Write to file if OUTPUT_FILE is set, otherwise stdout
  if (process.env.OUTPUT_FILE) {
    const { writeFileSync } = await import('fs');
    writeFileSync(process.env.OUTPUT_FILE, output);
    console.log(`Wrote staking data to ${process.env.OUTPUT_FILE}`);
  } else {
    console.log(output);
  }
}

main().catch(e => {
  console.error(JSON.stringify({ error: e.message }));
  process.exit(1);
});
