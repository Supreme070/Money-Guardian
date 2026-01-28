import React, { useState } from 'react';
import { 
  Bell, 
  Plus, 
  Landmark, 
  Mail, 
  Settings, 
  Home, 
  ClipboardList, 
  Calendar, 
  ChevronRight,
  Info,
  CheckCircle2,
  AlertTriangle,
  AlertCircle,
  Clapperboard, // Movie icon replacement
  Music, 
  Dumbbell
} from 'lucide-react';

// --- Design Tokens ---
const colors = {
  background: '#FFFFFF',
  surface: '#F5F5F7',
  primary: '#CEA734', // Sovereign Gold
  primaryDark: '#B8941F',
  textPrimary: '#1A1A1A',
  textSecondary: '#666666',
  textTertiary: '#999999',
  safe: '#00E676',
  caution: '#FFB74D',
  freeze: '#CF6679',
};

const Dashboard = () => {
  const [activeTab, setActiveTab] = useState('Pulse');

  return (
    <div className="min-h-screen bg-gray-50 flex justify-center items-start pt-0 sm:pt-10 font-sans antialiased">
      {/* Mobile Container simulating phone viewport on desktop */}
      <div className="w-full max-w-md bg-white sm:rounded-[40px] sm:shadow-2xl min-h-screen sm:min-h-[844px] overflow-hidden relative pb-[100px]">
        
        {/* --- Header --- */}
        <header className="px-6 pt-14 pb-6 flex justify-between items-center">
          <div>
            <p className="text-[#666666] text-base font-normal">Good morning,</p>
            <h1 className="text-[#1A1A1A] text-[28px] font-semibold tracking-tight">Alex</h1>
          </div>
          <div className="flex items-center gap-3">
            <button className="relative p-2.5 rounded-full bg-[#F5F5F7] border border-[#E0E0E0]/50 hover:bg-gray-200 transition-colors">
              <Bell className="w-6 h-6 text-[#1A1A1A]" strokeWidth={1.5} />
              <span className="absolute top-0.5 right-0.5 w-2.5 h-2.5 bg-[#CF6679] rounded-full border-2 border-white"></span>
            </button>
            <div className="w-10 h-10 rounded-full bg-[#F5F5F7] overflow-hidden border border-[#E0E0E0]/50">
              <img 
                src="https://i.pravatar.cc/150?img=11" 
                alt="Profile" 
                className="w-full h-full object-cover"
              />
            </div>
          </div>
        </header>

        {/* --- Scrollable Content --- */}
        <div className="flex flex-col gap-8">
          
          {/* --- 1. Hero Card --- */}
          <div className="px-4">
            <HeroCard status="SAFE" />
          </div>

          {/* --- 2. Quick Actions --- */}
          <div className="px-6">
            <h2 className="text-[#1A1A1A] text-lg font-semibold mb-4">Quick Actions</h2>
            <div className="flex justify-between items-start">
              <ActionButton icon={Plus} label="Add" />
              <ActionButton icon={Landmark} label="Bank" />
              <ActionButton icon={Mail} label="Email" />
              <ActionButton icon={Settings} label="Settings" />
            </div>
          </div>

          {/* --- 3. Upcoming Charges --- */}
          <div className="px-6">
            <div className="flex justify-between items-end mb-4">
              <h2 className="text-[#1A1A1A] text-lg font-semibold">Upcoming This Week</h2>
              <button className="text-[#CEA734] text-sm font-semibold hover:text-[#B8941F] transition-colors">
                See All →
              </button>
            </div>
            <div className="flex flex-col gap-3">
              <ChargeItem 
                title="Netflix Premium"
                category="Subscription"
                amount="15.99"
                daysUntil={1}
                color="red"
                icon={Clapperboard}
              />
              <ChargeItem 
                title="Spotify Duo"
                category="Subscription"
                amount="12.99"
                daysUntil={3}
                color="green"
                icon={Music}
              />
              <ChargeItem 
                title="Gym Membership"
                category="Auto-Pay"
                amount="45.00"
                daysUntil={5}
                color="blue"
                icon={Dumbbell}
              />
            </div>
          </div>
          
          {/* Spacer for bottom nav */}
          <div className="h-8"></div>
        </div>

        {/* --- 4. Bottom Navigation --- */}
        <div className="absolute bottom-0 left-0 right-0 h-[90px] bg-white rounded-t-[24px] shadow-[0_-5px_20px_rgba(0,0,0,0.05)] flex justify-around items-start pt-4 px-2">
          <NavItem 
            icon={Home} 
            label="Pulse" 
            isActive={activeTab === 'Pulse'} 
            onClick={() => setActiveTab('Pulse')}
          />
          <NavItem 
            icon={ClipboardList} 
            label="Subs" 
            isActive={activeTab === 'Subs'} 
            onClick={() => setActiveTab('Subs')}
          />
          <NavItem 
            icon={Calendar} 
            label="Calendar" 
            isActive={activeTab === 'Calendar'} 
            onClick={() => setActiveTab('Calendar')}
          />
          <NavItem 
            icon={Bell} 
            label="Alerts" 
            isActive={activeTab === 'Alerts'} 
            onClick={() => setActiveTab('Alerts')}
            badgeCount={3}
          />
        </div>
      </div>
    </div>
  );
};

// --- Components ---

const HeroCard = ({ status }) => {
  const getStatusConfig = (s) => {
    switch (s) {
      case 'CAUTION': return { color: '#FFB74D', icon: AlertTriangle };
      case 'FREEZE': return { color: '#CF6679', icon: AlertCircle };
      default: return { color: '#00E676', icon: CheckCircle2 };
    }
  };

  const config = getStatusConfig(status);
  const StatusIcon = config.icon;

  return (
    <div className="relative w-full h-[220px] rounded-[28px] overflow-hidden shadow-[0_12px_40px_-5px_rgba(206,167,52,0.4)] transition-transform hover:scale-[1.02] duration-300 ease-out">
      {/* Background Gradient */}
      <div 
        className="absolute inset-0 bg-gradient-to-br from-[#CEA734] to-[#B8941F]" 
        style={{ background: `linear-gradient(135deg, ${colors.primary} 10%, ${colors.primaryDark} 100%)` }}
      />

      {/* Decorative Circles */}
      <div className="absolute -top-12 -right-12 w-[220px] h-[220px] rounded-full bg-white opacity-[0.12]" />
      <div className="absolute -bottom-8 -left-8 w-[140px] h-[140px] rounded-full bg-white opacity-[0.08]" />

      {/* Top Edge Highlight (Inner Shine) */}
      <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-white/0 via-white/50 to-white/0" />

      {/* Content */}
      <div className="relative h-full p-6 flex flex-col justify-between">
        {/* Header Row */}
        <div>
          <p className="text-white/65 text-xs font-extrabold tracking-[0.15em] uppercase mb-2">Today's Status</p>
          <div 
            className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full shadow-[0_3px_6px_rgba(0,0,0,0.15)] backdrop-blur-sm"
            style={{ backgroundColor: config.color }}
          >
            <StatusIcon className="w-4 h-4 text-white" strokeWidth={3} />
            <span className="text-white text-sm font-black tracking-wide">{status}</span>
          </div>
        </div>

        {/* Balance Row */}
        <div>
          <p className="text-white/85 text-sm font-semibold mb-0.5">Safe to Spend</p>
          <h2 className="text-white text-[52px] font-bold leading-none tracking-tight drop-shadow-sm">
            $1,240.50
          </h2>
        </div>

        {/* Footer Row */}
        <div className="flex items-center gap-2">
          <div className="p-1 rounded-full bg-black/5">
            <Info className="w-3.5 h-3.5 text-white/90" />
          </div>
          <p className="text-white/90 text-[13px] font-medium truncate">
            Netflix charge in 3 days (-$15.99)
          </p>
        </div>
      </div>
    </div>
  );
};

const ActionButton = ({ icon: Icon, label }) => {
  return (
    <button className="flex flex-col items-center gap-2 group">
      <div className="w-14 h-14 rounded-full bg-[#F5F5F7] flex items-center justify-center shadow-[0_2px_4px_rgba(0,0,0,0.03)] group-hover:shadow-md group-hover:scale-105 transition-all duration-200">
        <Icon className="w-6 h-6 text-[#1A1A1A]" strokeWidth={1.5} />
      </div>
      <span className="text-[#666666] text-xs font-medium">{label}</span>
    </button>
  );
};

const ChargeItem = ({ title, category, amount, daysUntil, color, icon: Icon }) => {
  const isUrgent = daysUntil <= 1;
  const isWarning = daysUntil <= 3 && daysUntil > 1;
  
  // Badge logic
  const badgeColor = isUrgent ? colors.freeze : (isWarning ? colors.caution : colors.safe);
  const badgeText = daysUntil === 0 ? 'Today' : (daysUntil === 1 ? 'Tomorrow' : `In ${daysUntil} days`);

  // Icon BG logic
  const iconBgMap = {
    red: 'bg-red-50 text-red-500',
    green: 'bg-green-50 text-green-500',
    blue: 'bg-blue-50 text-blue-500',
  };

  return (
    <div className="flex items-center p-4 bg-white rounded-xl shadow-[0_2px_8px_rgba(0,0,0,0.04)] border border-[#F5F5F7] hover:border-[#E0E0E0] transition-colors cursor-pointer">
      {/* Icon */}
      <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${iconBgMap[color]} mr-4`}>
        <Icon className="w-6 h-6" strokeWidth={2} />
      </div>

      {/* Text Info */}
      <div className="flex-1">
        <h3 className="text-[#1A1A1A] text-base font-semibold">{title}</h3>
        <p className="text-[#999999] text-[13px] font-medium">{category}</p>
      </div>

      {/* Right Side */}
      <div className="flex flex-col items-end">
        <span className="text-[#1A1A1A] text-[18px] font-bold">-${amount}</span>
        <div className="flex items-center gap-1.5 mt-1">
          <div className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: badgeColor }} />
          <span className="text-xs font-medium" style={{ color: badgeColor }}>{badgeText}</span>
        </div>
      </div>
    </div>
  );
};

const NavItem = ({ icon: Icon, label, isActive, onClick, badgeCount }) => {
  return (
    <button 
      onClick={onClick}
      className="flex flex-col items-center gap-1 min-w-[60px] relative group"
    >
      <div className="relative">
        <Icon 
          className={`w-[26px] h-[26px] transition-colors duration-200 ${isActive ? 'text-[#CEA734]' : 'text-[#999999] group-hover:text-[#666666]'}`} 
          strokeWidth={isActive ? 2.5 : 2}
        />
        {badgeCount > 0 && (
          <div className="absolute -top-1 -right-1.5 bg-[#CF6679] text-white text-[10px] font-bold px-1 min-w-[14px] h-[14px] rounded-full flex items-center justify-center border border-white">
            {badgeCount}
          </div>
        )}
      </div>
      <span 
        className={`text-[11px] transition-colors duration-200 ${isActive ? 'text-[#CEA734] font-semibold' : 'text-[#999999] font-medium group-hover:text-[#666666]'}`}
      >
        {label}
      </span>
    </button>
  );
};

export default Dashboard;
