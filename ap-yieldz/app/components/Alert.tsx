'use client';

import { AlertCircle, CheckCircle, Info, AlertTriangle, X } from 'lucide-react';
import { useState } from 'react';

interface AlertProps {
  type: 'error' | 'warning' | 'info' | 'success';
  message: string;
  dismissible?: boolean;
  onDismiss?: () => void;
  className?: string;
}

export function Alert({ 
  type, 
  message, 
  dismissible = false, 
  onDismiss, 
  className = '' 
}: AlertProps) {
  const [isVisible, setIsVisible] = useState(true);

  const handleDismiss = () => {
    setIsVisible(false);
    onDismiss?.();
  };

  if (!isVisible) return null;

  const icons = {
    error: AlertCircle,
    warning: AlertTriangle,
    info: Info,
    success: CheckCircle,
  };

  const colors = {
    error: 'bg-red-50 border-red-200 text-red-800',
    warning: 'bg-yellow-50 border-yellow-200 text-yellow-800',
    info: 'bg-blue-50 border-blue-200 text-blue-800',
    success: 'bg-green-50 border-green-200 text-green-800',
  };

  const iconColors = {
    error: 'text-red-500',
    warning: 'text-yellow-500',
    info: 'text-blue-500',
    success: 'text-green-500',
  };

  const Icon = icons[type];

  return (
    <div className={`border rounded-lg p-4 flex items-start gap-3 ${colors[type]} ${className}`}>
      <Icon className={`h-5 w-5 mt-0.5 flex-shrink-0 ${iconColors[type]}`} />
      <div className="flex-1">
        <p className="text-sm font-medium">{message}</p>
      </div>
      {dismissible && (
        <button
          onClick={handleDismiss}
          className="flex-shrink-0 text-gray-500 hover:text-gray-700 transition-colors"
        >
          <X className="h-4 w-4" />
        </button>
      )}
    </div>
  );
}

export default Alert;
