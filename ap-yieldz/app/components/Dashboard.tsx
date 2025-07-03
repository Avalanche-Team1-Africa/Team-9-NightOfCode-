'use client';

import { useState } from 'react';
import { useHistoricalAPY } from '../blockchain/hooks/useAPYData';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { TrendingUp, TrendingDown, Activity, Info } from 'lucide-react';

export function Dashboard() {
  const [selectedAsset, setSelectedAsset] = useState('USDC');
  const [selectedPeriod, setSelectedPeriod] = useState(30);
  
  const aaveData = useHistoricalAPY(selectedAsset, 'aave', selectedPeriod);
  const morphoData = useHistoricalAPY(selectedAsset, 'morpho', selectedPeriod);

  // Combine data for chart
  const combinedData = aaveData.data.map((aavePoint, index) => ({
    date: aavePoint.date,
    aaveSupply: aavePoint.supplyAPY,
    aaveBorrow: aavePoint.borrowAPY,
    morphoSupply: morphoData.data[index]?.supplyAPY || 0,
    morphoBorrow: morphoData.data[index]?.borrowAPY || 0,
  }));

  const assets = ['USDC', 'USDT', 'WETH', 'WBTC'];
  const periods = [
    { label: '7D', value: 7 },
    { label: '30D', value: 30 },
    { label: '90D', value: 90 },
  ];

  // Calculate average APYs for the period
  const avgAaveSupply = combinedData.length > 0 
    ? combinedData.reduce((sum, point) => sum + point.aaveSupply, 0) / combinedData.length 
    : 0;
  const avgMorphoSupply = combinedData.length > 0 
    ? combinedData.reduce((sum, point) => sum + point.morphoSupply, 0) / combinedData.length 
    : 0;
  const avgAaveBorrow = combinedData.length > 0 
    ? combinedData.reduce((sum, point) => sum + point.aaveBorrow, 0) / combinedData.length 
    : 0;
  const avgMorphoBorrow = combinedData.length > 0 
    ? combinedData.reduce((sum, point) => sum + point.morphoBorrow, 0) / combinedData.length 
    : 0;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between space-y-4 sm:space-y-0">
          <div>
            <h2 className="text-2xl font-bold text-gray-900">APY Dashboard</h2>
            <p className="text-gray-600">Historical APY trends across protocols</p>
          </div>
          
          <div className="flex flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-4">
            {/* Asset Selector */}
            <select
              value={selectedAsset}
              onChange={(e) => setSelectedAsset(e.target.value)}
              className="px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-green-500 focus:border-transparent"
            >
              {assets.map(asset => (
                <option key={asset} value={asset}>{asset}</option>
              ))}
            </select>
            
            {/* Period Selector */}
            <div className="flex space-x-1 bg-gray-100 rounded-lg p-1">
              {periods.map(period => (
                <button
                  key={period.value}
                  onClick={() => setSelectedPeriod(period.value)}
                  className={`px-3 py-1 rounded-md text-sm font-medium transition-colors ${
                    selectedPeriod === period.value
                      ? 'bg-white text-gray-900 shadow-sm'
                      : 'text-gray-600 hover:text-gray-900'
                  }`}
                >
                  {period.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Avg Aave Supply</p>
              <p className="text-xl font-bold text-blue-600">{avgAaveSupply.toFixed(2)}%</p>
            </div>
            <div className="bg-blue-100 rounded-full p-3">
              <TrendingUp className="h-6 w-6 text-blue-600" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Avg Morpho Supply</p>
              <p className="text-xl font-bold text-purple-600">{avgMorphoSupply.toFixed(2)}%</p>
            </div>
            <div className="bg-purple-100 rounded-full p-3">
              <TrendingUp className="h-6 w-6 text-purple-600" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Avg Aave Borrow</p>
              <p className="text-xl font-bold text-blue-600">{avgAaveBorrow.toFixed(2)}%</p>
            </div>
            <div className="bg-blue-100 rounded-full p-3">
              <TrendingDown className="h-6 w-6 text-blue-600" />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Avg Morpho Borrow</p>
              <p className="text-xl font-bold text-purple-600">{avgMorphoBorrow.toFixed(2)}%</p>
            </div>
            <div className="bg-purple-100 rounded-full p-3">
              <TrendingDown className="h-6 w-6 text-purple-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Supply APY Chart */}
        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">Supply APY Trends</h3>
            <Activity className="h-5 w-5 text-gray-500" />
          </div>
          
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={combinedData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis 
                dataKey="date" 
                tickFormatter={(date) => new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
              />
              <YAxis tickFormatter={(value) => `${value.toFixed(1)}%`} />
              <Tooltip 
                labelFormatter={(date) => new Date(date).toLocaleDateString()}
                formatter={(value: number, name: string) => [`${value.toFixed(2)}%`, name]}
              />
              <Legend />
              <Line 
                type="monotone" 
                dataKey="aaveSupply" 
                stroke="#3B82F6" 
                strokeWidth={2}
                name="Aave"
                dot={{ r: 3 }}
              />
              <Line 
                type="monotone" 
                dataKey="morphoSupply" 
                stroke="#8B5CF6" 
                strokeWidth={2}
                name="Morpho"
                dot={{ r: 3 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Borrow APY Chart */}
        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">Borrow APY Trends</h3>
            <Activity className="h-5 w-5 text-gray-500" />
          </div>
          
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={combinedData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis 
                dataKey="date" 
                tickFormatter={(date) => new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
              />
              <YAxis tickFormatter={(value) => `${value.toFixed(1)}%`} />
              <Tooltip 
                labelFormatter={(date) => new Date(date).toLocaleDateString()}
                formatter={(value: number, name: string) => [`${value.toFixed(2)}%`, name]}
              />
              <Legend />
              <Line 
                type="monotone" 
                dataKey="aaveBorrow" 
                stroke="#3B82F6" 
                strokeWidth={2}
                name="Aave"
                dot={{ r: 3 }}
              />
              <Line 
                type="monotone" 
                dataKey="morphoBorrow" 
                stroke="#8B5CF6" 
                strokeWidth={2}
                name="Morpho"
                dot={{ r: 3 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Insights */}
      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="flex items-center space-x-2 mb-4">
          <Info className="h-5 w-5 text-blue-500" />
          <h3 className="text-lg font-medium text-gray-900">Market Insights</h3>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-3">
            <h4 className="font-medium text-gray-900">Supply Opportunities</h4>
            <div className="text-sm text-gray-600">
              {avgMorphoSupply > avgAaveSupply ? (
                <p>✅ Morpho is currently offering higher supply APY for {selectedAsset} ({(avgMorphoSupply - avgAaveSupply).toFixed(2)}% difference)</p>
              ) : (
                <p>✅ Aave is currently offering higher supply APY for {selectedAsset} ({(avgAaveSupply - avgMorphoSupply).toFixed(2)}% difference)</p>
              )}
            </div>
          </div>
          
          <div className="space-y-3">
            <h4 className="font-medium text-gray-900">Borrowing Opportunities</h4>
            <div className="text-sm text-gray-600">
              {avgAaveBorrow < avgMorphoBorrow ? (
                <p>✅ Aave offers lower borrowing rates for {selectedAsset} ({(avgMorphoBorrow - avgAaveBorrow).toFixed(2)}% difference)</p>
              ) : (
                <p>✅ Morpho offers lower borrowing rates for {selectedAsset} ({(avgAaveBorrow - avgMorphoBorrow).toFixed(2)}% difference)</p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
