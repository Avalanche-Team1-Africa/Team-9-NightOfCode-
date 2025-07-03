import { createConfig, http } from 'wagmi';
import { avalanche, base } from 'wagmi/chains';
import { metaMask, walletConnect } from 'wagmi/connectors';

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'your-project-id';

export const config = createConfig({
  chains: [avalanche, base],
  connectors: [
    metaMask(),
    walletConnect({ projectId })
  ],
  transports: {
    [avalanche.id]: http(process.env.NEXT_PUBLIC_AVALANCHE_RPC || 'https://api.avax.network/ext/bc/C/rpc'),
    [base.id]: http(process.env.NEXT_PUBLIC_BASE_RPC || 'https://mainnet.base.org'),
  },
});

export const LENDING_APY_AGGREGATOR_ADDRESS = process.env.NEXT_PUBLIC_LENDING_APY_AGGREGATOR_ADDRESS || '0x...';

export const SUPPORTED_TOKENS = {
  avalanche: {
    USDC: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
    USDT: '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7',
    WETH: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB',
    WBTC: '0x50b7545627a5162F82A992c33b87aDc75187B218',
  },
  base: {
    USDC: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
    WETH: '0x4200000000000000000000000000000000000006',
  }
};