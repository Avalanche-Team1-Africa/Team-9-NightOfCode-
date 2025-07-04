'use client';

import { WalletNavigation } from './WalletNavigation';

interface AppLayoutProps {
  children: React.ReactNode;
}

export function AppLayout({ children }: AppLayoutProps) {
  return (
    <div className="min-h-screen bg-gray-50">
      <WalletNavigation />
      {children}
    </div>
  );
}
