'use client';

import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { Wallet, LogOut } from 'lucide-react';

export function Navigation() {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();

  const formatAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  return (
    <nav className="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex-shrink-0">
            <h1 className="text-2xl font-bold text-green-800">🐊 Alligator</h1>
          </div>
          <div className="hidden md:block">
            <div className="ml-10 flex items-baseline space-x-4">
              <a href="#dashboard" className="text-gray-600 hover:text-green-700 px-3 py-2 rounded-md text-sm font-medium">
                Dashboard
              </a>
              <a href="#markets" className="text-gray-600 hover:text-green-700 px-3 py-2 rounded-md text-sm font-medium">
                Markets
              </a>
              <a href="#portfolio" className="text-gray-600 hover:text-green-700 px-3 py-2 rounded-md text-sm font-medium">
                Portfolio
              </a>
              
              {isConnected ? (
                <div className="flex items-center space-x-3">
                  <span className="text-sm text-gray-600">
                    {formatAddress(address!)}
                  </span>
                  <button
                    onClick={() => disconnect()}
                    className="bg-red-100 hover:bg-red-200 text-red-700 px-3 py-2 rounded-md text-sm font-medium flex items-center space-x-1 transition-colors"
                  >
                    <LogOut size={16} />
                    <span>Disconnect</span>
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => connect({ connector: connectors[0] })}
                  className="bg-green-700 hover:bg-green-800 text-white px-4 py-2 rounded-md text-sm font-medium flex items-center space-x-1 transition-colors"
                >
                  <Wallet size={16} />
                  <span>Connect Wallet</span>
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
}
