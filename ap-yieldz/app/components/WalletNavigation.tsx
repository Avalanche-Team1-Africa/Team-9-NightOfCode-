'use client';

import { useState, useEffect } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { CustomConnectButton } from './CustomConnectButton';
import { Menu, X } from 'lucide-react';

export function WalletNavigation() {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return (
      <nav className="bg-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <span className="text-2xl font-bold text-green-700">Alligator</span>
            </div>
            <div className="hidden md:flex items-center space-x-4">
              <div className="bg-green-600 text-white px-4 py-2 rounded-md">
                Loading...
              </div>
            </div>
          </div>
        </div>
      </nav>
    );
  }

  return (
    <nav className="bg-white shadow-lg sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center">
            <span className="text-2xl font-bold text-green-700">🐊 Alligator</span>
            {/* <span className="ml-2 text-sm text-gray-500">Cross-Chain Yield Aggregator</span> */}
          </div>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center space-x-8">
            <nav className="flex space-x-6">
              <a href="#dashboard" className="text-gray-600 hover:text-green-700 px-3 py-2 rounded-md text-sm font-medium transition-colors">
                Dashboard
              </a>
              <a href="#markets" className="text-gray-600 hover:text-green-700 px-3 py-2 rounded-md text-sm font-medium transition-colors">
                Markets
              </a>
              <a href="#portfolio" className="text-gray-600 hover:text-green-700 px-3 py-2 rounded-md text-sm font-medium transition-colors">
                Portfolio
              </a>
            </nav>
            <CustomConnectButton />
          </div>

          {/* Mobile menu button */}
          <div className="md:hidden flex items-center space-x-4">
            <div className="scale-90">
              <CustomConnectButton />
            </div>
            <button
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              className="p-2 rounded-md text-gray-600 hover:text-green-600 hover:bg-gray-100 transition-colors"
            >
              {isMobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
          </div>
        </div>

        {/* Mobile Navigation */}
        {isMobileMenuOpen && (
          <div className="md:hidden">
            <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3 bg-gray-50 border-t">
              <a href="#dashboard" className="block text-gray-600 hover:text-green-700 px-3 py-2 rounded-md text-base font-medium transition-colors">
                Dashboard
              </a>
              <a href="#markets" className="block text-gray-600 hover:text-green-700 px-3 py-2 rounded-md text-base font-medium transition-colors">
                Markets
              </a>
              <a href="#portfolio" className="block text-gray-600 hover:text-green-700 px-3 py-2 rounded-md text-base font-medium transition-colors">
                Portfolio
              </a>
            </div>
          </div>
        )}
      </div>
    </nav>
  );
}
