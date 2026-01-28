import React, { useState } from 'react';
import { 
  Shield, 
  Landmark, 
  Mail, 
  Bell, 
  CheckCircle2, 
  ChevronRight, 
  Link2 
} from 'lucide-react';

const OnboardingPage = () => {
  const [step, setStep] = useState(0);
  const [bankConnected, setBankConnected] = useState(false);
  const [emailConnected, setEmailConnected] = useState(false);

  const totalSteps = 4;

  const handleNext = () => {
    if (step < totalSteps - 1) {
      setStep(step + 1);
    } else {
      console.log("Onboarding Complete - Navigate to Dashboard");
    }
  };

  const handleSkip = () => {
    console.log("Skipped Onboarding");
  };

  const slides = [
    {
      id: 'intro',
      icon: Shield,
      title: 'Stop Bleeding Money.',
      subtitle: 'The average person loses $300/year to forgotten subscriptions and hidden fees. We stop that.',
      isHero: true,
    },
    {
      id: 'bank',
      icon: Landmark,
      title: 'The Foundation',
      subtitle: 'Connect your primary bank account so we can scan for threats.',
      isAction: true,
      actionLabel: bankConnected ? 'Bank Connected' : 'Connect Bank',
      isConnected: bankConnected,
      onAction: () => setBankConnected(true),
    },
    {
      id: 'email',
      icon: Mail,
      title: 'The Deep Scan',
      subtitle: 'Link your email to find receipts for subscriptions your bank misses.',
      isAction: true,
      actionLabel: emailConnected ? 'Email Connected' : 'Connect Email',
      isConnected: emailConnected,
      onAction: () => setEmailConnected(true),
    },
    {
      id: 'finish',
      icon: Bell,
      title: 'Silent Mode Activated.',
      subtitle: 'We will only alert you when it matters. Your money is now guarded.',
      isLast: true,
    }
  ];

  const currentSlide = slides[step];

  return (
    <div className="min-h-screen bg-white flex justify-center items-start pt-0 sm:pt-10 font-sans antialiased text-[#1A1A1A]">
      <div className="w-full max-w-md bg-white sm:rounded-[40px] sm:shadow-2xl min-h-screen sm:min-h-[844px] flex flex-col relative overflow-hidden">
        
        {/* --- Top Bar --- */}
        <div className="px-6 pt-14 pb-4 flex items-center justify-between">
          {/* Progress Indicator */}
          <div className="flex gap-1.5 h-1">
            {[...Array(totalSteps)].map((_, i) => (
              <div 
                key={i}
                className={`w-8 h-full rounded-full transition-colors duration-300 ${
                  i <= step ? 'bg-[#CEA734]' : 'bg-[#F5F5F7]'
                }`}
              />
            ))}
          </div>

          <button 
            onClick={handleSkip}
            className="text-[#999999] text-[13px] font-semibold hover:text-[#666666] transition-colors"
          >
            Skip
          </button>
        </div>

        {/* --- Main Content Area --- */}
        <div className="flex-1 flex flex-col items-center justify-center px-8 pb-20 text-center animate-fadeIn">
          
          {/* Icon Circle */}
          <div className={`
            w-[120px] h-[120px] rounded-full flex items-center justify-center mb-10 transition-all duration-500
            ${currentSlide.isHero ? 'bg-[#CEA734]/10 border border-[#CEA734]/20' : 'bg-[#F5F5F7]'}
            ${currentSlide.isLast ? 'bg-[#00E676]/10' : ''}
          `}>
            <currentSlide.icon 
              className={`w-14 h-14 transition-colors duration-300 ${
                currentSlide.isHero ? 'text-[#CEA734]' : 
                currentSlide.isLast ? 'text-[#00E676]' : 'text-[#1A1A1A]'
              }`} 
              strokeWidth={1.5}
            />
          </div>

          {/* Typography */}
          <h1 className="text-[32px] font-bold leading-[1.1] mb-4 tracking-tight">
            {currentSlide.title}
          </h1>
          <p className="text-[#666666] text-base leading-relaxed max-w-[280px] mx-auto">
            {currentSlide.subtitle}
          </p>

          {/* Action Card (For Connection Steps) */}
          {currentSlide.isAction && (
            <div className="mt-10 w-full max-w-[280px]">
              <button
                onClick={currentSlide.onAction}
                className={`
                  w-full p-5 rounded-2xl border-2 flex items-center justify-center gap-3 transition-all duration-300
                  ${currentSlide.isConnected 
                    ? 'bg-[#00E676]/5 border-[#00E676] text-[#00E676]' 
                    : 'bg-white border-[#CEA734]/30 hover:border-[#CEA734] text-[#CEA734] hover:bg-[#CEA734]/5'
                  }
                `}
              >
                {currentSlide.isConnected ? (
                  <CheckCircle2 className="w-5 h-5" />
                ) : (
                  <Link2 className="w-5 h-5" />
                )}
                <span className="font-bold text-[15px]">
                  {currentSlide.actionLabel}
                </span>
              </button>
            </div>
          )}

        </div>

        {/* --- Bottom Controls --- */}
        <div className="px-8 pb-12 w-full">
          <button
            onClick={handleNext}
            className="w-full h-14 rounded-2xl bg-[#CEA734] text-white text-[16px] font-bold shadow-[0_8px_20px_-4px_rgba(206,167,52,0.4)] hover:bg-[#B8941F] hover:shadow-lg active:scale-[0.98] transition-all flex items-center justify-center gap-2 group"
          >
            {step === totalSteps - 1 ? 'Enter Dashboard' : 'Continue'}
            {step < totalSteps - 1 && (
              <ChevronRight className="w-5 h-5 opacity-80 group-hover:translate-x-1 transition-transform" />
            )}
          </button>
        </div>

      </div>
    </div>
  );
};

export default OnboardingPage;
