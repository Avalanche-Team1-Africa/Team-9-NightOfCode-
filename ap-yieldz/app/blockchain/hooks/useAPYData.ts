import { useState, useEffect } from 'react';
import { APYData } from './useAggregator';

// Mock APY data - In production, this would fetch from Aave and Morpho APIs
const MOCK_APY_DATA: Record<string, Omit<APYData, 'asset'>> = {
  'USDC': {
    symbol: 'USDC',
    aaveSupplyAPY: 4.25,
    aaveBorrowAPY: 6.80,
    morphoSupplyAPY: 5.10,
    morphoBorrowAPY: 7.20,
    bestSupplyProtocol: 'morpho',
    bestBorrowProtocol: 'aave',
  },
  'USDT': {
    symbol: 'USDT',
    aaveSupplyAPY: 4.15,
    aaveBorrowAPY: 6.75,
    morphoSupplyAPY: 4.90,
    morphoBorrowAPY: 7.15,
    bestSupplyProtocol: 'morpho',
    bestBorrowProtocol: 'aave',
  },
  'WETH': {
    symbol: 'WETH',
    aaveSupplyAPY: 3.80,
    aaveBorrowAPY: 5.20,
    morphoSupplyAPY: 4.25,
    morphoBorrowAPY: 5.85,
    bestSupplyProtocol: 'morpho',
    bestBorrowProtocol: 'aave',
  },
  'WBTC': {
    symbol: 'WBTC',
    aaveSupplyAPY: 2.10,
    aaveBorrowAPY: 4.50,
    morphoSupplyAPY: 2.75,
    morphoBorrowAPY: 4.95,
    bestSupplyProtocol: 'morpho',
    bestBorrowProtocol: 'aave',
  },
};

export function useAPYData() {
  const [apyData, setApyData] = useState<APYData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchAPYData = async () => {
      try {
        setLoading(true);
        
        // Simulate API delay
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // In production, you would fetch from actual APIs:
        // - Aave: https://aave-api-v2.aave.com/data/rates-history
        // - Morpho: https://api.morpho.org/markets
        
        const data: APYData[] = Object.entries(MOCK_APY_DATA).map(([symbol, rates]) => ({
          asset: symbol.toLowerCase(),
          ...rates,
        }));
        
        setApyData(data);
        setError(null);
      } catch (err) {
        setError('Failed to fetch APY data');
        console.error('Error fetching APY data:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchAPYData();
    
    // Refresh data every 30 seconds
    const interval = setInterval(fetchAPYData, 30000);
    
    return () => clearInterval(interval);
  }, []);

  const getAPYForAsset = (asset: string): APYData | undefined => {
    return apyData.find(data => data.asset === asset.toLowerCase() || data.symbol === asset.toUpperCase());
  };

  return {
    apyData,
    loading,
    error,
    getAPYForAsset,
    refresh: () => {
      setLoading(true);
      // Trigger refresh
    },
  };
}

// Historical APY data for charts
export function useHistoricalAPY(asset: string, protocol: 'aave' | 'morpho', days: number = 30) {
  const [data, setData] = useState<Array<{ date: string; supplyAPY: number; borrowAPY: number }>>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const generateMockHistoricalData = () => {
      const baseSupplyAPY = MOCK_APY_DATA[asset.toUpperCase()]?.[`${protocol}SupplyAPY`] || 4;
      const baseBorrowAPY = MOCK_APY_DATA[asset.toUpperCase()]?.[`${protocol}BorrowAPY`] || 6;
      
      const historicalData = [];
      for (let i = days; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        
        // Add some random variation
        const supplyVariation = (Math.random() - 0.5) * 0.5;
        const borrowVariation = (Math.random() - 0.5) * 0.8;
        
        historicalData.push({
          date: date.toISOString().split('T')[0],
          supplyAPY: Math.max(0, baseSupplyAPY + supplyVariation),
          borrowAPY: Math.max(0, baseBorrowAPY + borrowVariation),
        });
      }
      
      setData(historicalData);
      setLoading(false);
    };

    if (asset) {
      generateMockHistoricalData();
    }
  }, [asset, protocol, days]);

  return { data, loading };
}
