import { getDefaultConfig, getDefaultWallets } from '@rainbow-me/rainbowkit';
import { avalancheFuji } from 'wagmi/chains';
import {
  injectedWallet,
} from "@rainbow-me/rainbowkit/wallets";
import { http, createStorage, cookieStorage } from 'wagmi';

if (!process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID) {
  throw new Error('Missing NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID');
}

const { wallets } = getDefaultWallets();

export const config = getDefaultConfig({
  appName: 'Alligator',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID,
  wallets: [
    {
      groupName: "Core Wallet",
      wallets: [injectedWallet],
    },
  ],
  chains: [
    avalancheFuji,
  ],
  transports: {
    [avalancheFuji.id]: http(process.env.NEXT_PUBLIC_AVALANCHE_FUJI_RPC || 'https://api.avax-test.network/ext/bc/C/rpc'),
  },
  ssr: true,
  storage: createStorage({
    storage: cookieStorage,
  }),
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