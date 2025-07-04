'use client';

import { useState, useEffect } from 'react';
import { useAPYData } from '../blockchain/hooks/useAPYData';
import { TrendingUp, TrendingDown, ExternalLink, RefreshCw } from 'lucide-react';
import { LoadingState } from './LoadingSpinner';
import Alert from './Alert';

interface APYTableProps {
  onAssetSelect?: (asset: string) => void;
}

export function APYComparisonTable({ onAssetSelect }: APYTableProps) {
  const { apyData, loading, error, refresh } = useAPYData();
  const [sortBy, setSortBy] = useState<'asset' | 'aaveSupply' | 'morphoSupply' | 'aaveBorrow' | 'morphoBorrow'>('asset');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');

  const sortedData = [...apyData].sort((a, b) => {
    let valueA: number | string;
    let valueB: number | string;

    switch (sortBy) {
      case 'asset':
        valueA = a.symbol;
        valueB = b.symbol;
        break;
      case 'aaveSupply':
        valueA = a.aaveSupplyAPY;
        valueB = b.aaveSupplyAPY;
        break;
      case 'morphoSupply':
        valueA = a.morphoSupplyAPY;
        valueB = b.morphoSupplyAPY;
        break;
      case 'aaveBorrow':
        valueA = a.aaveBorrowAPY;
        valueB = b.aaveBorrowAPY;
        break;
      case 'morphoBorrow':
        valueA = a.morphoBorrowAPY;
        valueB = b.morphoBorrowAPY;
        break;
      default:
        valueA = a.symbol;
        valueB = b.symbol;
    }

    if (typeof valueA === 'string' && typeof valueB === 'string') {
      return sortOrder === 'asc' ? valueA.localeCompare(valueB) : valueB.localeCompare(valueA);
    }

    const numA = Number(valueA);
    const numB = Number(valueB);
    return sortOrder === 'asc' ? numA - numB : numB - numA;
  });

  const handleSort = (column: typeof sortBy) => {
    if (sortBy === column) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(column);
      setSortOrder('desc'); // Default to desc for APY columns
    }
  };

  const getBestRate = (aaveRate: number, morphoRate: number, type: 'supply' | 'borrow') => {
    if (type === 'supply') {
      return aaveRate > morphoRate ? { protocol: 'aave', rate: aaveRate } : { protocol: 'morpho', rate: morphoRate };
    } else {
      return aaveRate < morphoRate ? { protocol: 'aave', rate: aaveRate } : { protocol: 'morpho', rate: morphoRate };
    }
  };

  // Loading state
  if (loading && apyData.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow-lg">
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">APY Comparison</h2>
        </div>
        <LoadingState message="Loading APY data..." />
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="text-center text-red-600">
          <p className="text-lg font-medium">Error loading APY data</p>
          <p className="text-sm">{error}</p>
          <button
            onClick={refresh}
            className="mt-4 bg-red-100 hover:bg-red-200 text-red-700 px-4 py-2 rounded-md transition-colors"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg shadow-lg overflow-hidden">
      {/* Show error alert if there's an error */}
      {error && (
        <div className="p-4 border-b border-gray-200">
          <Alert 
            type="warning" 
            message={error}
            dismissible={true}
          />
        </div>
      )}
      
      <div className="px-6 py-4 border-b border-gray-200">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-bold text-gray-900">APY Comparison</h2>
          <button
            onClick={refresh}
            className="flex items-center space-x-2 text-gray-600 hover:text-gray-900 transition-colors"
            disabled={loading}
          >
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
            <span className="text-sm">Refresh</span>
          </button>
        </div>
        <p className="text-gray-600 mt-1">Compare lending and borrowing rates across protocols</p>
      </div>

      <div className="overflow-x-auto">
        <table className="min-w-full">
          <thead className="bg-gray-50">
            <tr>
              <th
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                onClick={() => handleSort('asset')}
              >
                Asset
              </th>
              <th
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                onClick={() => handleSort('aaveSupply')}
              >
                Aave Supply APY
              </th>
              <th
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                onClick={() => handleSort('morphoSupply')}
              >
                Morpho Supply APY
              </th>
              <th
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                onClick={() => handleSort('aaveBorrow')}
              >
                Aave Borrow APY
              </th>
              <th
                className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                onClick={() => handleSort('morphoBorrow')}
              >
                Morpho Borrow APY
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Best Protocol
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {sortedData.map((asset) => {
              const bestSupply = getBestRate(asset.aaveSupplyAPY, asset.morphoSupplyAPY, 'supply');
              const bestBorrow = getBestRate(asset.aaveBorrowAPY, asset.morphoBorrowAPY, 'borrow');

              return (
                <tr key={asset.symbol} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="text-sm font-medium text-gray-900">{asset.symbol}</div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className={`text-sm font-medium flex items-center space-x-1 ${
                      bestSupply.protocol === 'aave' ? 'text-green-600' : 'text-gray-900'
                    }`}>
                      <span>{asset.aaveSupplyAPY.toFixed(2)}%</span>
                      {bestSupply.protocol === 'aave' && <TrendingUp size={14} className="text-green-500" />}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className={`text-sm font-medium flex items-center space-x-1 ${
                      bestSupply.protocol === 'morpho' ? 'text-green-600' : 'text-gray-900'
                    }`}>
                      <span>{asset.morphoSupplyAPY.toFixed(2)}%</span>
                      {bestSupply.protocol === 'morpho' && <TrendingUp size={14} className="text-green-500" />}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className={`text-sm font-medium flex items-center space-x-1 ${
                      bestBorrow.protocol === 'aave' ? 'text-green-600' : 'text-gray-900'
                    }`}>
                      <span>{asset.aaveBorrowAPY.toFixed(2)}%</span>
                      {bestBorrow.protocol === 'aave' && <TrendingDown size={14} className="text-green-500" />}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className={`text-sm font-medium flex items-center space-x-1 ${
                      bestBorrow.protocol === 'morpho' ? 'text-green-600' : 'text-gray-900'
                    }`}>
                      <span>{asset.morphoBorrowAPY.toFixed(2)}%</span>
                      {bestBorrow.protocol === 'morpho' && <TrendingDown size={14} className="text-green-500" />}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="space-y-1">
                      <div className="text-xs text-gray-500">Supply:</div>
                      <div className={`text-sm font-medium ${
                        bestSupply.protocol === 'aave' ? 'text-blue-600' : 'text-purple-600'
                      }`}>
                        {bestSupply.protocol === 'aave' ? 'Aave' : 'Morpho'}
                      </div>
                      <div className="text-xs text-gray-500">Borrow:</div>
                      <div className={`text-sm font-medium ${
                        bestBorrow.protocol === 'aave' ? 'text-blue-600' : 'text-purple-600'
                      }`}>
                        {bestBorrow.protocol === 'aave' ? 'Aave' : 'Morpho'}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <button
                      onClick={() => onAssetSelect?.(asset.symbol)}
                      className="text-green-600 hover:text-green-900 flex items-center space-x-1"
                    >
                      <span>Trade</span>
                      <ExternalLink size={14} />
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
