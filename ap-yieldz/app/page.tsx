'use client';

import React, { useState } from 'react';
import { Dashboard } from './components/Dashboard';
import { APYComparisonTable } from './components/APYComparisonTable';
import { Portfolio } from './components/Portfolio';
import { TradingModal } from './components/TradingModal';
import { BarChart3, PieChart, Wallet, TrendingUp } from 'lucide-react';

export default function Home() {
  const [activeTab, setActiveTab] = useState<'dashboard' | 'markets' | 'portfolio'>('dashboard');
  const [tradingModal, setTradingModal] = useState<{
    isOpen: boolean;
    asset: string;
    action: 'supply' | 'borrow' | 'withdraw' | 'repay';
  }>({
    isOpen: false,
    asset: '',
    action: 'supply',
  });

  const handleAssetSelect = (asset: string) => {
    setTradingModal({
      isOpen: true,
      asset,
      action: 'supply',
    });
  };

  const handlePortfolioAction = (asset: string, action: 'supply' | 'borrow' | 'withdraw' | 'repay') => {
    setTradingModal({
      isOpen: true,
      asset,
      action,
    });
  };

  const closeTradingModal = () => {
    setTradingModal(prev => ({ ...prev, isOpen: false }));
  };

  return (
    <>
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-green-50 to-green-100 py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center">
            <h1 className="text-4xl md:text-5xl font-bold text-gray-900 mb-4">
              Find the Best <span className="text-green-700">APY Rates</span>
            </h1>
            <p className="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
              Compare lending rates across Aave and Morpho protocols. Optimize your DeFi strategy with real-time APY data and seamless cross-chain bridging.
            </p>
          </div>
        </div>
      </section>

      {/* Tab Navigation */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8" aria-label="Tabs">
            <button
              onClick={() => setActiveTab('dashboard')}
              className={`flex items-center space-x-2 py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'dashboard'
                  ? 'border-green-500 text-green-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <BarChart3 size={20} />
              <span>Dashboard</span>
            </button>
            <button
              onClick={() => setActiveTab('markets')}
              className={`flex items-center space-x-2 py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'markets'
                  ? 'border-green-500 text-green-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <TrendingUp size={20} />
              <span>Markets</span>
            </button>
            <button
              onClick={() => setActiveTab('portfolio')}
              className={`flex items-center space-x-2 py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'portfolio'
                  ? 'border-green-500 text-green-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              <Wallet size={20} />
              <span>Portfolio</span>
            </button>
          </nav>
        </div>
      </div>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-12">
        {activeTab === 'dashboard' && <Dashboard />}
        {activeTab === 'markets' && <APYComparisonTable onAssetSelect={handleAssetSelect} />}
        {activeTab === 'portfolio' && <Portfolio onActionClick={handlePortfolioAction} />}
      </main>

      {/* Features Section */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-4">Why Choose Alligator?</h2>
            <p className="text-xl text-gray-600">The most comprehensive DeFi APY aggregator</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="text-center">
              <div className="bg-green-100 rounded-full w-16 h-16 flex items-center justify-center mx-auto mb-4">
                <BarChart3 className="h-8 w-8 text-green-600" />
              </div>
              <h3 className="text-xl font-medium text-gray-900 mb-2">Real-time APY Comparison</h3>
              <p className="text-gray-600">
                Compare rates across Aave and Morpho protocols in real-time to maximize your yields.
              </p>
            </div>

            <div className="text-center">
              <div className="bg-green-100 rounded-full w-16 h-16 flex items-center justify-center mx-auto mb-4">
                <PieChart className="h-8 w-8 text-green-600" />
              </div>
              <h3 className="text-xl font-medium text-gray-900 mb-2">Cross-chain Bridging</h3>
              <p className="text-gray-600">
                Seamlessly bridge assets between Avalanche and Base networks for optimal positioning.
              </p>
            </div>

            <div className="text-center">
              <div className="bg-green-100 rounded-full w-16 h-16 flex items-center justify-center mx-auto mb-4">
                <Wallet className="h-8 w-8 text-green-600" />
              </div>
              <h3 className="text-xl font-medium text-gray-900 mb-2">Portfolio Management</h3>
              <p className="text-gray-600">
                Track your positions across protocols and optimize your DeFi portfolio in one place.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-white py-8">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center">
            <h3 className="text-lg font-medium mb-2">🐊 Alligator</h3>
            <p className="text-gray-400">Your DeFi yield optimization companion</p>
            <div className="mt-4 space-x-6">
              <a href="#" className="text-gray-400 hover:text-white">About</a>
              <a href="#" className="text-gray-400 hover:text-white">Docs</a>
              <a href="#" className="text-gray-400 hover:text-white">Support</a>
              <a href="#" className="text-gray-400 hover:text-white">GitHub</a>
            </div>
          </div>
        </div>
      </footer>

      {/* Trading Modal */}
      <TradingModal
        isOpen={tradingModal.isOpen}
        onClose={closeTradingModal}
        selectedAsset={tradingModal.asset}
        defaultAction={tradingModal.action}
      />
    </>
  );
}
