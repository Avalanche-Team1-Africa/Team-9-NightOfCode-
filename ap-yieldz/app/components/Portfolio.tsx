'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { useUserPosition } from '../blockchain/hooks/useAggregator';
import { useAPYData } from '../blockchain/hooks/useAPYData';
import { SUPPORTED_TOKENS } from '../blockchain/config/wagmi';
import { PieChart, Pie, Cell, ResponsiveContainer, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend } from 'recharts';
import { Wallet, TrendingUp, TrendingDown, AlertTriangle } from 'lucide-react';

interface PortfolioProps {
  onActionClick?: (asset: string, action: 'supply' | 'borrow' | 'withdraw' | 'repay') => void;
}

export function Portfolio({ onActionClick }: PortfolioProps) {
  const { isConnected, address } = useAccount();
  const { apyData } = useAPYData();
  const [selectedChain, setSelectedChain] = useState<'avalanche' | 'base'>('avalanche');

  const tokens = SUPPORTED_TOKENS[selectedChain];
  
  // Get positions for all tokens
  const positions = Object.entries(tokens).map(([symbol, tokenAddress]) => {
    const position = useUserPosition(tokenAddress);
    const apyInfo = apyData.find(apy => apy.symbol === symbol);
    
    return {
      symbol,
      address: tokenAddress,
      position,
      apy: apyInfo,
    };
  }).filter(item => item.position);

  // Calculate total values
  const totalSupplied = positions.reduce((sum, item) => {
    const aaveSupplied = parseFloat(item.position?.aaveSupplied || '0');
    const morphoSupplied = parseFloat(item.position?.morphoSupplied || '0');
    return sum + aaveSupplied + morphoSupplied;
  }, 0);

  const totalBorrowed = positions.reduce((sum, item) => {
    const aaveBorrowed = parseFloat(item.position?.aaveBorrowed || '0');
    const morphoBorrowed = parseFloat(item.position?.morphoBorrowed || '0');
    return sum + aaveBorrowed + morphoBorrowed;
  }, 0);

  const netPosition = totalSupplied - totalBorrowed;

  // Prepare chart data
  const suppliedByProtocol = [
    {
      name: 'Aave',
      value: positions.reduce((sum, item) => sum + parseFloat(item.position?.aaveSupplied || '0'), 0),
      color: '#3B82F6',
    },
    {
      name: 'Morpho',
      value: positions.reduce((sum, item) => sum + parseFloat(item.position?.morphoSupplied || '0'), 0),
      color: '#8B5CF6',
    },
  ].filter(item => item.value > 0);

  const borrowedByProtocol = [
    {
      name: 'Aave',
      value: positions.reduce((sum, item) => sum + parseFloat(item.position?.aaveBorrowed || '0'), 0),
      color: '#3B82F6',
    },
    {
      name: 'Morpho',
      value: positions.reduce((sum, item) => sum + parseFloat(item.position?.morphoBorrowed || '0'), 0),
      color: '#8B5CF6',
    },
  ].filter(item => item.value > 0);

  const positionsByAsset = positions.map(item => ({
    asset: item.symbol,
    supplied: parseFloat(item.position?.aaveSupplied || '0') + parseFloat(item.position?.morphoSupplied || '0'),
    borrowed: parseFloat(item.position?.aaveBorrowed || '0') + parseFloat(item.position?.morphoBorrowed || '0'),
  })).filter(item => item.supplied > 0 || item.borrowed > 0);

  if (!isConnected) {
    return (
      <div className="bg-white rounded-lg shadow-lg p-8 text-center">
        <Wallet size={48} className="mx-auto text-gray-400 mb-4" />
        <h3 className="text-lg font-medium text-gray-900 mb-2">Connect Your Wallet</h3>
        <p className="text-gray-600">Connect your wallet to view your portfolio and positions</p>
      </div>
    );
  }

  if (positions.length === 0 || (totalSupplied === 0 && totalBorrowed === 0)) {
    return (
      <div className="bg-white rounded-lg shadow-lg p-8 text-center">
        <TrendingUp size={48} className="mx-auto text-gray-400 mb-4" />
        <h3 className="text-lg font-medium text-gray-900 mb-2">No Positions Found</h3>
        <p className="text-gray-600">Start by supplying or borrowing assets to see your portfolio here</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Chain Selector */}
      <div className="flex space-x-2">
        {(['avalanche', 'base'] as const).map((chain) => (
          <button
            key={chain}
            onClick={() => setSelectedChain(chain)}
            className={`px-4 py-2 rounded-lg font-medium transition-colors ${
              selectedChain === chain
                ? 'bg-green-100 text-green-800 border-2 border-green-500'
                : 'bg-gray-100 text-gray-700 border-2 border-transparent hover:bg-gray-200'
            }`}
          >
            {chain.charAt(0).toUpperCase() + chain.slice(1)}
          </button>
        ))}
      </div>

      {/* Portfolio Summary */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Total Supplied</p>
              <p className="text-2xl font-bold text-green-600">${totalSupplied.toFixed(2)}</p>
            </div>
            <TrendingUp className="h-8 w-8 text-green-500" />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Total Borrowed</p>
              <p className="text-2xl font-bold text-red-600">${totalBorrowed.toFixed(2)}</p>
            </div>
            <TrendingDown className="h-8 w-8 text-red-500" />
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Net Position</p>
              <p className={`text-2xl font-bold ${netPosition >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                ${netPosition.toFixed(2)}
              </p>
            </div>
            {netPosition < 0 && <AlertTriangle className="h-8 w-8 text-yellow-500" />}
          </div>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Supplied Assets by Protocol */}
        {suppliedByProtocol.length > 0 && (
          <div className="bg-white rounded-lg shadow-lg p-6">
            <h3 className="text-lg font-medium text-gray-900 mb-4">Supplied Assets by Protocol</h3>
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={suppliedByProtocol}
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  dataKey="value"
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                >
                  {suppliedByProtocol.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip formatter={(value) => [`$${Number(value).toFixed(2)}`, 'Value']} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        )}

        {/* Borrowed Assets by Protocol */}
        {borrowedByProtocol.length > 0 && (
          <div className="bg-white rounded-lg shadow-lg p-6">
            <h3 className="text-lg font-medium text-gray-900 mb-4">Borrowed Assets by Protocol</h3>
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={borrowedByProtocol}
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  dataKey="value"
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                >
                  {borrowedByProtocol.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip formatter={(value) => [`$${Number(value).toFixed(2)}`, 'Value']} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>

      {/* Position Details */}
      <div className="bg-white rounded-lg shadow-lg overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Position Details</h3>
        </div>
        
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Asset</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Aave Supplied</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Morpho Supplied</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Aave Borrowed</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Morpho Borrowed</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {positions.map((item) => (
                <tr key={item.symbol}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {item.symbol}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {parseFloat(item.position?.aaveSupplied || '0').toFixed(4)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {parseFloat(item.position?.morphoSupplied || '0').toFixed(4)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {parseFloat(item.position?.aaveBorrowed || '0').toFixed(4)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {parseFloat(item.position?.morphoBorrowed || '0').toFixed(4)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                    <button
                      onClick={() => onActionClick?.(item.symbol, 'supply')}
                      className="text-green-600 hover:text-green-900"
                    >
                      Supply
                    </button>
                    <button
                      onClick={() => onActionClick?.(item.symbol, 'withdraw')}
                      className="text-blue-600 hover:text-blue-900"
                    >
                      Withdraw
                    </button>
                    <button
                      onClick={() => onActionClick?.(item.symbol, 'borrow')}
                      className="text-orange-600 hover:text-orange-900"
                    >
                      Borrow
                    </button>
                    <button
                      onClick={() => onActionClick?.(item.symbol, 'repay')}
                      className="text-red-600 hover:text-red-900"
                    >
                      Repay
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
