import { useReadContract, useWriteContract, useAccount } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { LENDING_APY_AGGREGATOR_ABI, ERC20_ABI } from '../abi/LendingAPYAggregator';
import { LENDING_APY_AGGREGATOR_ADDRESS, SUPPORTED_TOKENS } from '../config/wagmi';

export interface TokenInfo {
  symbol: string;
  address: string;
  decimals: number;
  balance?: string;
  allowance?: string;
}

export interface APYData {
  asset: string;
  symbol: string;
  aaveSupplyAPY: number;
  aaveBorrowAPY: number;
  morphoSupplyAPY: number;
  morphoBorrowAPY: number;
  bestSupplyProtocol: 'aave' | 'morpho';
  bestBorrowProtocol: 'aave' | 'morpho';
}

export interface UserPosition {
  aaveSupplied: string;
  aaveBorrowed: string;
  morphoSupplied: string;
  morphoBorrowed: string;
  lastUpdate: number;
}

// Hook to get supported assets
export function useSupportedAssets() {
  const { data: assets } = useReadContract({
    address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
    abi: LENDING_APY_AGGREGATOR_ABI,
    functionName: 'getSupportedAssets',
  });

  return assets || [];
}

// Hook to get user position for a specific asset
export function useUserPosition(asset: string) {
  const { address } = useAccount();
  
  const { data: position } = useReadContract({
    address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
    abi: LENDING_APY_AGGREGATOR_ABI,
    functionName: 'getAggregatorUserPosition',
    args: [address as `0x${string}`, asset as `0x${string}`],
    query: {
      enabled: !!address && !!asset,
    },
  });

  if (!position) return null;

  return {
    aaveSupplied: formatUnits(position[0], 18),
    aaveBorrowed: formatUnits(position[1], 18),
    morphoSupplied: formatUnits(position[2], 18),
    morphoBorrowed: formatUnits(position[3], 18),
    lastUpdate: Number(position[4]),
  } as UserPosition;
}

// Hook to get token balance
export function useTokenBalance(tokenAddress: string) {
  const { address } = useAccount();
  
  const { data: balance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    query: {
      enabled: !!address && !!tokenAddress,
    },
  });

  return balance ? formatUnits(balance, 18) : '0';
}

// Hook to get token allowance
export function useTokenAllowance(tokenAddress: string) {
  const { address } = useAccount();
  
  const { data: allowance } = useReadContract({
    address: tokenAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: [address as `0x${string}`, LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`],
    query: {
      enabled: !!address && !!tokenAddress,
    },
  });

  return allowance ? formatUnits(allowance, 18) : '0';
}

// Hook for contract write operations
export function useAggregatorOperations() {
  const { writeContract } = useWriteContract();

  const supplyToAave = async (asset: string, amount: string) => {
    return writeContract({
      address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
      abi: LENDING_APY_AGGREGATOR_ABI,
      functionName: 'supplyToAave',
      args: [asset as `0x${string}`, parseUnits(amount, 18)],
    });
  };

  const supplyToMorpho = async (asset: string, amount: string, bridgeFee: string = '0.001') => {
    return writeContract({
      address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
      abi: LENDING_APY_AGGREGATOR_ABI,
      functionName: 'supplyToMorpho',
      args: [asset as `0x${string}`, parseUnits(amount, 18)],
      value: parseUnits(bridgeFee, 18),
    });
  };

  const borrowFromAave = async (asset: string, amount: string) => {
    return writeContract({
      address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
      abi: LENDING_APY_AGGREGATOR_ABI,
      functionName: 'borrowFromAave',
      args: [asset as `0x${string}`, parseUnits(amount, 18)],
    });
  };

  const borrowFromMorpho = async (asset: string, amount: string, receiver: string, bridgeFee: string = '0.001') => {
    return writeContract({
      address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
      abi: LENDING_APY_AGGREGATOR_ABI,
      functionName: 'borrowFromMorpho',
      args: [asset as `0x${string}`, parseUnits(amount, 18), receiver as `0x${string}`],
      value: parseUnits(bridgeFee, 18),
    });
  };

  const withdrawFromAave = async (asset: string, amount: string) => {
    return writeContract({
      address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
      abi: LENDING_APY_AGGREGATOR_ABI,
      functionName: 'withdrawFromAave',
      args: [asset as `0x${string}`, parseUnits(amount, 18)],
    });
  };

  const withdrawFromMorpho = async (asset: string, amount: string, receiver: string, bridgeFee: string = '0.001') => {
    return writeContract({
      address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
      abi: LENDING_APY_AGGREGATOR_ABI,
      functionName: 'withdrawFromMorpho',
      args: [asset as `0x${string}`, parseUnits(amount, 18), receiver as `0x${string}`],
      value: parseUnits(bridgeFee, 18),
    });
  };

  const repayToAave = async (asset: string, amount: string) => {
    return writeContract({
      address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
      abi: LENDING_APY_AGGREGATOR_ABI,
      functionName: 'repayToAave',
      args: [asset as `0x${string}`, parseUnits(amount, 18)],
    });
  };

  const repayToMorpho = async (asset: string, amount: string, bridgeFee: string = '0.001') => {
    return writeContract({
      address: LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`,
      abi: LENDING_APY_AGGREGATOR_ABI,
      functionName: 'repayToMorpho',
      args: [asset as `0x${string}`, parseUnits(amount, 18)],
      value: parseUnits(bridgeFee, 18),
    });
  };

  const approveToken = async (tokenAddress: string, amount: string) => {
    return writeContract({
      address: tokenAddress as `0x${string}`,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [LENDING_APY_AGGREGATOR_ADDRESS as `0x${string}`, parseUnits(amount, 18)],
    });
  };

  return {
    supplyToAave,
    supplyToMorpho,
    borrowFromAave,
    borrowFromMorpho,
    withdrawFromAave,
    withdrawFromMorpho,
    repayToAave,
    repayToMorpho,
    approveToken,
  };
}
