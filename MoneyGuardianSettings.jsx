import React, { useState } from 'react';
import { 
  ChevronLeft, 
  ChevronRight, 
  Landmark, 
  Mail, 
  Shield, 
  Bell, 
  CreditCard, 
  HelpCircle, 
  MessageSquare, 
  FileText, 
  LogOut,
  Edit2,
  Check
} from 'lucide-react';

// --- Design Tokens ---
const colors = {
  background: '#FFFFFF',
  surface: '#F5F5F7',
  primary: '#CEA734',
  primaryDark: '#B8941F',
  textPrimary: '#1A1A1A',
  textSecondary: '#666666',
  textTertiary: '#999999',
  safe: '#00E676',
  freeze: '#CF6679',
  navy: '#1A1A1A', // Using textPrimary as the dark navy/black base
};

const SettingsPage = () => {
  return (
    <div className="min-h-screen bg-gray-50 flex justify-center items-start pt-0 sm:pt-10 font-sans antialiased">
      {/* Mobile Container */}
      <div className="w-full max-w-md bg-white sm:rounded-[40px] sm:shadow-2xl min-h-screen sm:min-h-[844px] overflow-hidden relative pb-10">
        
        {/* --- Header --- */}
        <header className="px-6 pt-14 pb-4 flex items-center justify-between bg-white z-10 sticky top-0">
          <button className="p-2 -ml-2 rounded-full hover:bg-gray-100 transition-colors">
            <ChevronLeft className="w-6 h-6 text-[#1A1A1A]" />
          </button>
          <h1 className="text-[18px] font-bold text-[#1A1A1A]">Settings</h1>
          <div className="w-10" /> {/* Spacer for centering */}
        </header>

        {/* --- Scrollable Content --- */}
        <div className="px-5 pb-8 space-y-8">
          
          {/* 1. Profile Hero */}
          <ProfileCard />

          {/* 2. Connections */}
          <Section title="Connections">
            <div className="space-y-3">
              <ConnectionCard 
                icon={Landmark} 
                title="Bank Accounts" 
                subtitle="3 accounts linked" 
                color="gold"
              />
              <ConnectionCard 
                icon={Mail} 
                title="Email Scanning" 
                subtitle="Scanning gmail.com" 
                color="red"
              />
            </div>
          </Section>

          {/* 3. Account & Security */}
          <Section title="Account & Security">
            <SettingsGroup>
              <SettingsItem 
                icon={Shield} 
                label="Security" 
                value="Face ID enabled" 
              />
              <SettingsItem 
                icon={Bell} 
                label="Notifications" 
                value="Push, Email" 
              />
              <SettingsItem 
                icon={CreditCard} 
                label="Billing" 
                value="Manage Subscription" 
                isLast
              />
            </SettingsGroup>
          </Section>

          {/* 4. Support */}
          <Section title="Support">
            <SettingsGroup>
              <SettingsItem icon={HelpCircle} label="Help Center" />
              <SettingsItem icon={MessageSquare} label="Contact Support" />
              <SettingsItem icon={FileText} label="Privacy Policy" isLast />
            </SettingsGroup>
          </Section>

          {/* 5. Logout */}
          <button className="w-full h-14 rounded-2xl border border-[#CF6679] text-[#CF6679] font-semibold text-[15px] flex items-center justify-center gap-2 hover:bg-[#CF6679]/5 transition-colors">
            <LogOut className="w-5 h-5" />
            Sign Out
          </button>

          <p className="text-center text-[#999999] text-xs pt-2">
            Money Guardian v1.0.0
          </p>

        </div>
      </div>
    </div>
  );
};

// --- Sub-Components ---

const ProfileCard = () => {
  return (
    <div className="w-full p-6 rounded-[24px] bg-[#1A1A1A] shadow-lg flex items-center gap-5 relative overflow-hidden group cursor-pointer">
      {/* Subtle Gradient BG */}
      <div className="absolute inset-0 bg-gradient-to-br from-[#262626] to-[#000000]" />
      
      {/* Avatar */}
      <div className="relative w-16 h-16 rounded-full bg-[#CEA734]/20 border-2 border-[#CEA734]/30 flex items-center justify-center shrink-0">
        <span className="text-[#CEA734] text-2xl font-bold">A</span>
      </div>

      {/* Info */}
      <div className="relative flex-1">
        <h2 className="text-white text-lg font-semibold tracking-tight">Alex Morgan</h2>
        <p className="text-white/60 text-sm mb-3">alex.morgan@example.com</p>
        
        {/* Pro Badge */}
        <div className="inline-flex items-center px-2.5 py-1 rounded-lg bg-[#CEA734] shadow-[0_2px_8px_rgba(206,167,52,0.3)]">
          <span className="text-white text-[10px] font-extrabold tracking-wide uppercase">PRO MEMBER</span>
        </div>
      </div>

      {/* Edit Icon */}
      <div className="relative p-2 rounded-xl bg-white/10 opacity-0 group-hover:opacity-100 transition-opacity">
        <Edit2 className="w-4 h-4 text-white" />
      </div>
    </div>
  );
};

const Section = ({ title, children }) => (
  <div>
    <h3 className="text-[#1A1A1A] text-lg font-semibold mb-4 px-1">{title}</h3>
    {children}
  </div>
);

const ConnectionCard = ({ icon: Icon, title, subtitle, color }) => {
  const isGold = color === 'gold';
  const iconColor = isGold ? '#CEA734' : '#EA4335'; // Gold or Gmail Red
  const bgClass = isGold ? 'bg-[#CEA734]/10' : 'bg-[#EA4335]/10';

  return (
    <button className="w-full p-4 rounded-[20px] bg-[#F5F5F7] flex items-center gap-4 hover:bg-[#EBEBEB] transition-colors group">
      <div className={`w-11 h-11 rounded-xl ${bgClass} flex items-center justify-center`}>
        <Icon className="w-5 h-5" style={{ color: iconColor }} />
      </div>
      <div className="flex-1 text-left">
        <h4 className="text-[#1A1A1A] text-[15px] font-semibold">{title}</h4>
        <p className="text-[#999999] text-xs font-medium">{subtitle}</p>
      </div>
      <ChevronRight className="w-5 h-5 text-[#999999] group-hover:text-[#666666] transition-colors" />
    </button>
  );
};

const SettingsGroup = ({ children }) => (
  <div className="bg-[#F5F5F7] rounded-[24px] overflow-hidden">
    {children}
  </div>
);

const SettingsItem = ({ icon: Icon, label, value, isLast }) => {
  return (
    <button className={`w-full p-4 flex items-center gap-4 hover:bg-[#EBEBEB] transition-colors relative ${!isLast ? 'border-b border-black/5' : ''}`}>
      <div className="w-10 h-10 rounded-xl bg-white flex items-center justify-center shadow-sm">
        <Icon className="w-5 h-5 text-[#1A1A1A]" strokeWidth={1.8} />
      </div>
      
      <span className="text-[#1A1A1A] text-[15px] font-medium text-left flex-1">
        {label}
      </span>

      {value && (
        <span className="text-[#999999] text-[13px] font-medium mr-1">
          {value}
        </span>
      )}
      
      <ChevronRight className="w-5 h-5 text-[#999999]" />
    </button>
  );
};

export default SettingsPage;
