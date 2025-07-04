import { useState, useEffect } from 'react';
import { APYData } from './useAggregator';

// TODO: Add more sophisticated caching if needed
// TODO: Add API key to .env.local if required in the future
const AAVE_API_URL = 'https://aave-api-v2.aave.com/data/rates-history';
const MORPHO_API_URL = 'https://api.morpho.org/markets';

// Mapping of asset symbols to their respective IDs on Aave
const AAVE_RESERVE_IDS: Record<string, string> = {
    'USDC': '0x27f8d03b3a2196956ed754badc28d73be8830a6e',
    'USDT': '0x83f798e925bcd4017eb265844f99ed486b5794da',
    'WETH': '0x028171bca77440897b824ca71d1c56cac55b68a3',
    'WBTC': '0x9ff58f4ffb29fa2266ab25e75e2a8b3503311656',
};

export function useAPYData() {
  const [apyData, setApyData] = useState<APYData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchAPYData = async () => {
      try {
        setLoading(true);

        // Fetch from Aave
        const aaveResponse = await fetch(AAVE_API_URL);
        if (!aaveResponse.ok) {
          throw new Error(`Failed to fetch Aave data: ${aaveResponse.statusText}`);
        }
        const aaveData = await aaveResponse.json();

        // Fetch from Morpho
        const morphoResponse = await fetch(MORPHO_API_URL);
        if (!morphoResponse.ok) {
            throw new Error(`Failed to fetch Morpho data: ${morphoResponse.statusText}`);
        }
        const morphoData = await morphoResponse.json();
        
        const combinedData: APYData[] = Object.keys(AAVE_RESERVE_IDS).map(symbol => {
            const aaveReserveId = AAVE_RESERVE_IDS[symbol];
            const aaveAssetData = aaveData.find((d: any) => d.reserve.id === aaveReserveId);
            
            const morphoAssetData = morphoData.find((d: any) => d.asset.symbol === symbol);

            const aaveSupplyAPY = aaveAssetData ? parseFloat(aaveAssetData.liquidityRate) * 100 : 0;
            const aaveBorrowAPY = aaveAssetData ? parseFloat(aaveAssetData.variableBorrowRate) * 100 : 0;
            const morphoSupplyAPY = morphoAssetData ? parseFloat(morphoAssetData.supplyApy) * 100 : 0;
            const morphoBorrowAPY = morphoAssetData ? parseFloat(morphoAssetData.borrowApy) * 100 : 0;

            return {
                asset: symbol.toLowerCase(),
                symbol: symbol,
                aaveSupplyAPY,
                aaveBorrowAPY,
                morphoSupplyAPY,
                morphoBorrowAPY,
                bestSupplyProtocol: aaveSupplyAPY > morphoSupplyAPY ? 'aave' : 'morpho',
                bestBorrowProtocol: aaveBorrowAPY < morphoBorrowAPY ? 'aave' : 'morpho',
            };
        });

        setApyData(combinedData);
        setError(null);
      } catch (err: any) {
        setError(err.message || 'Failed to fetch APY data');
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
      // TODO: Replace with actual historical data fetching
      const historicalData = Array.from({ length: days }).map((_, i) => {
        const date = new Date();
        date.setDate(date.getDate() - (days - i));
        return {
          date: date.toISOString().split('T')[0],
          supplyAPY: 0,
          borrowAPY: 0,
        };
      });
      setData(historicalData);
      setLoading(false);
    };

    if (asset) {
      generateMockHistoricalData();
    }
  }, [asset, protocol, days]);

  return { data, loading };
}
