'use client';

import { useState, useEffect } from 'react';
import { useAccount, useBalance } from 'wagmi';
import { useAPYData } from '../blockchain/hooks/useAPYData';
import { CustomConnectButton } from './CustomConnectButton';
import { X, ArrowUpCircle, ArrowDownCircle, RotateCcw, DollarSign, AlertCircle } from 'lucide-react';

interface TradingModalProps {
  isOpen: boolean;
  onClose: () => void;
  selectedAsset: string;
  defaultAction?: 'supply' | 'borrow' | 'withdraw' | 'repay';
}

export function TradingModal({ isOpen, onClose, selectedAsset, defaultAction = 'supply' }: TradingModalProps) {
  const { address, isConnected } = useAccount();
  const { getAPYForAsset } = useAPYData();
  
  const [action, setAction] = useState<'supply' | 'borrow' | 'withdraw' | 'repay'>(defaultAction);
  const [protocol, setProtocol] = useState<'aave' | 'morpho'>('aave');
  const [amount, setAmount] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  // Get user's ETH balance as an example
  const { data: balance } = useBalance({
    address: address,
  });

  // Mock token address for the selected asset
  const tokenAddress = `0x${selectedAsset.toLowerCase().padEnd(40, '0')}`;
  
  // Mock token balance and allowance for now
  const tokenBalance = { formatted: '1000.0', symbol: selectedAsset };
  const allowance = { formatted: '0' };
  
  // Mock operations
  const operations = {
    approveToken: async (token: string, amount: string) => {
      console.log('Mock approve token:', token, amount);
    },
    supplyToAave: async (token: string, amount: string) => {
      console.log('Mock supply to Aave:', token, amount);
    },
    supplyToMorpho: async (token: string, amount: string) => {
      console.log('Mock supply to Morpho:', token, amount);
    },
    borrowFromAave: async (token: string, amount: string) => {
      console.log('Mock borrow from Aave:', token, amount);
    },
    borrowFromMorpho: async (token: string, amount: string, user: string) => {
      console.log('Mock borrow from Morpho:', token, amount, user);
    },
    withdrawFromAave: async (token: string, amount: string) => {
      console.log('Mock withdraw from Aave:', token, amount);
    },
    withdrawFromMorpho: async (token: string, amount: string, user: string) => {
      console.log('Mock withdraw from Morpho:', token, amount, user);
    },
    repayToAave: async (token: string, amount: string) => {
      console.log('Mock repay to Aave:', token, amount);
    },
    repayToMorpho: async (token: string, amount: string) => {
      console.log('Mock repay to Morpho:', token, amount);
    }
  };
  
  const assetData = getAPYForAsset(selectedAsset);
  
  useEffect(() => {
    setAction(defaultAction);
  }, [defaultAction]);

  useEffect(() => {
    if (assetData) {
      // Auto-select best protocol based on action
      if (action === 'supply') {
        setProtocol(assetData.bestSupplyProtocol);
      } else if (action === 'borrow') {
        setProtocol(assetData.bestBorrowProtocol);
      }
    }
  }, [action, assetData]);

  const needsApproval = () => {
    if (!amount || (action !== 'supply' && action !== 'repay')) return false;
    return parseFloat(allowance.formatted) < parseFloat(amount);
  };

  const handleApprove = async () => {
    if (!amount) return;
    
    setIsLoading(true);
    setError('');
    
    try {
      await operations.approveToken(tokenAddress, amount);
    } catch (err) {
      setError('Failed to approve token');
      console.error('Approval error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleTransaction = async () => {
    if (!amount || !isConnected) return;
    
    setIsLoading(true);
    setError('');
    
    try {
      switch (action) {
        case 'supply':
          if (protocol === 'aave') {
            await operations.supplyToAave(tokenAddress, amount);
          } else {
            await operations.supplyToMorpho(tokenAddress, amount);
          }
          break;
        case 'borrow':
          if (protocol === 'aave') {
            await operations.borrowFromAave(tokenAddress, amount);
          } else {
            await operations.borrowFromMorpho(tokenAddress, amount, address!);
          }
          break;
        case 'withdraw':
          if (protocol === 'aave') {
            await operations.withdrawFromAave(tokenAddress, amount);
          } else {
            await operations.withdrawFromMorpho(tokenAddress, amount, address!);
          }
          break;
        case 'repay':
          if (protocol === 'aave') {
            await operations.repayToAave(tokenAddress, amount);
          } else {
            await operations.repayToMorpho(tokenAddress, amount);
          }
          break;
      }
      
      // Reset form on success
      setAmount('');
      onClose();
    } catch (err) {
      setError(`Failed to ${action}`);
      console.error('Transaction error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const getAPYForCurrentSelection = () => {
    if (!assetData) return 0;
    
    if (action === 'supply' || action === 'withdraw') {
      return protocol === 'aave' ? assetData.aaveSupplyAPY : assetData.morphoSupplyAPY;
    } else {
      return protocol === 'aave' ? assetData.aaveBorrowAPY : assetData.morphoBorrowAPY;
    }
  };

  const getProtocolColor = (protocolName: 'aave' | 'morpho') => {
    return protocolName === 'aave' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800';
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-bold text-gray-900">
            {action.charAt(0).toUpperCase() + action.slice(1)} {selectedAsset}
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <X size={24} />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {!isConnected && (
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <div className="flex items-center space-x-2">
                <AlertCircle size={16} className="text-yellow-600" />
                <span className="text-yellow-800">Please connect your wallet to continue</span>
              </div>
            </div>
          )}

          {/* Action Selection */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Action</label>
            <div className="grid grid-cols-2 gap-2">
              {(['supply', 'borrow', 'withdraw', 'repay'] as const).map((actionType) => (
                <button
                  key={actionType}
                  onClick={() => setAction(actionType)}
                  className={`flex items-center justify-center space-x-2 py-3 px-4 rounded-lg border transition-colors ${
                    action === actionType
                      ? 'border-green-500 bg-green-50 text-green-700'
                      : 'border-gray-300 hover:border-gray-400'
                  }`}
                >
                  {actionType === 'supply' && <ArrowUpCircle size={16} />}
                  {actionType === 'borrow' && <ArrowDownCircle size={16} />}
                  {actionType === 'withdraw' && <RotateCcw size={16} />}
                  {actionType === 'repay' && <DollarSign size={16} />}
                  <span className="capitalize">{actionType}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Protocol Selection */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Protocol</label>
            <div className="grid grid-cols-2 gap-2">
              {(['aave', 'morpho'] as const).map((protocolType) => (
                <button
                  key={protocolType}
                  onClick={() => setProtocol(protocolType)}
                  className={`py-3 px-4 rounded-lg border transition-colors ${
                    protocol === protocolType
                      ? `border-${protocolType === 'aave' ? 'blue' : 'purple'}-500 ${getProtocolColor(protocolType)}`
                      : 'border-gray-300 hover:border-gray-400'
                  }`}
                >
                  <div className="text-center">
                    <div className="font-medium capitalize">{protocolType}</div>
                    {assetData && (
                      <div className="text-sm">
                        {action === 'supply' || action === 'withdraw'
                          ? `${(protocolType === 'aave' ? assetData.aaveSupplyAPY : assetData.morphoSupplyAPY).toFixed(2)}% APY`
                          : `${(protocolType === 'aave' ? assetData.aaveBorrowAPY : assetData.morphoBorrowAPY).toFixed(2)}% APY`
                        }
                      </div>
                    )}
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Amount Input */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Amount</label>
            <div className="relative">
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.00"
                className="w-full py-3 px-4 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-transparent"
                disabled={!isConnected}
              />
              <div className="absolute right-3 top-3 text-gray-500">
                {selectedAsset}
              </div>
            </div>
            {isConnected && (
              <div className="mt-2 text-sm text-gray-600">
                Balance: {tokenBalance.formatted} {selectedAsset}
                {balance && (
                  <span className="ml-2">• ETH: {parseFloat(balance.formatted).toFixed(4)}</span>
                )}
              </div>
            )}
          </div>

          {/* APY Information */}
          {assetData && (
            <div className="bg-gray-50 rounded-lg p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Current APY</span>
                <span className="text-lg font-bold text-green-600">
                  {getAPYForCurrentSelection().toFixed(2)}%
                </span>
              </div>
              {protocol === 'morpho' && (action === 'supply' || action === 'borrow') && (
                <div className="mt-2 text-xs text-gray-500">
                  * Bridge fee required for Morpho transactions (~$2-5)
                </div>
              )}
            </div>
          )}

          {/* Error Display */}
          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4">
              <div className="flex items-center space-x-2">
                <AlertCircle size={16} className="text-red-600" />
                <span className="text-red-800">{error}</span>
              </div>
            </div>
          )}

          {/* Action Buttons */}
          <div className="space-y-3">
            {!isConnected ? (
              <div className="text-center space-y-4">
                <p className="text-gray-600">Connect your wallet to start trading</p>
                <CustomConnectButton />
              </div>
            ) : (
              <>
                {needsApproval() && (
                  <button
                    onClick={handleApprove}
                    disabled={isLoading}
                    className="w-full bg-yellow-600 hover:bg-yellow-700 disabled:bg-gray-300 text-white py-3 rounded-lg font-medium transition-colors"
                  >
                    {isLoading ? 'Approving...' : `Approve ${selectedAsset}`}
                  </button>
                )}
                
                <button
                  onClick={handleTransaction}
                  disabled={isLoading || !amount || needsApproval()}
                  className="w-full bg-green-600 hover:bg-green-700 disabled:bg-gray-300 text-white py-3 rounded-lg font-medium transition-colors"
                >
                  {isLoading ? 'Processing...' : `${action.charAt(0).toUpperCase() + action.slice(1)} ${selectedAsset}`}
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
