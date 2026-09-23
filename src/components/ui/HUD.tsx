import React from 'react';
import { useGameStore } from '../../store/useGameStore';
import {
  Volume2,
  VolumeX,
  Camera,
  HelpCircle,
  RotateCcw,
  MapPin,
  Sparkles,
  Zap,
} from 'lucide-react';

export const HUD: React.FC = () => {
  const {
    score,
    comboScore,
    multiplier,
    comboTricks,
    lastLandedTrick,
    lastTrickPoints,
    isGrinding,
    currentGrindType,
    speed,
    jumpCharge,
    isBailing,
    cameraMode,
    isMuted,
    showHelp,
    cycleCameraMode,
    toggleMute,
    toggleHelp,
    triggerRespawn,
  } = useGameStore();

  const isComboActive = comboTricks.length > 0 || isGrinding;
  const currentTotalComboScore = comboScore * multiplier;

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        pointerEvents: 'none',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        padding: '24px',
        fontFamily: "'Chakra Petch', sans-serif",
      }}
    >
      {/* ================= TOP BAR ================= */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'flex-start',
        }}
      >
        {/* Game Title & Total Banked Score */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <div
            style={{
              fontSize: '28px',
              fontWeight: 800,
              fontStyle: 'italic',
              letterSpacing: '1px',
              background: 'linear-gradient(90deg, #00f0ff, #ff3366)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              textTransform: 'uppercase',
              textShadow: '0 0 20px rgba(0, 240, 255, 0.4)',
            }}
          >
            SCOOTMANIA
          </div>
          <div
            style={{
              display: 'flex',
              alignItems: 'baseline',
              gap: '8px',
              background: 'rgba(15, 23, 42, 0.75)',
              backdropFilter: 'blur(8px)',
              padding: '6px 14px',
              borderRadius: '8px',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              width: 'fit-content',
            }}
          >
            <span
              style={{
                color: '#94a3b8',
                fontSize: '12px',
                fontWeight: 700,
                letterSpacing: '1px',
              }}
            >
              BANKED PTS
            </span>
            <span
              style={{
                color: '#f8fafc',
                fontSize: '24px',
                fontWeight: 800,
                fontVariantNumeric: 'tabular-nums',
              }}
            >
              {score.toLocaleString()}
            </span>
          </div>
        </div>

        {/* Top Right Controls & Quick Actions */}
        <div
          style={{
            display: 'flex',
            gap: '10px',
            pointerEvents: 'auto',
          }}
        >
          {/* Respawn Button */}
          <button
            onClick={triggerRespawn}
            title="Respawn at marker (R)"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              background: 'rgba(15, 23, 42, 0.8)',
              border: '1px solid rgba(255, 255, 255, 0.15)',
              color: '#f8fafc',
              padding: '8px 12px',
              borderRadius: '8px',
              cursor: 'pointer',
              fontSize: '13px',
              fontWeight: 700,
              fontFamily: 'inherit',
              transition: 'all 0.15s ease',
            }}
          >
            <RotateCcw size={16} color="#38bdf8" />
            <span>RESPAWN [R]</span>
          </button>

          {/* Camera Cycle Button */}
          <button
            onClick={cycleCameraMode}
            title="Switch camera (C)"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              background: 'rgba(15, 23, 42, 0.8)',
              border: '1px solid rgba(255, 255, 255, 0.15)',
              color: '#f8fafc',
              padding: '8px 12px',
              borderRadius: '8px',
              cursor: 'pointer',
              fontSize: '13px',
              fontWeight: 700,
              fontFamily: 'inherit',
            }}
          >
            <Camera size={16} color="#a855f7" />
            <span style={{ textTransform: 'uppercase' }}>
              {cameraMode === 'chase_low'
                ? 'LOW CHASE'
                : cameraMode === 'chase_high'
                ? 'HIGH ARCADE'
                : 'FREE'}
            </span>
          </button>

          {/* Mute Toggle */}
          <button
            onClick={toggleMute}
            title="Toggle Mute (U)"
            style={{
              background: 'rgba(15, 23, 42, 0.8)',
              border: '1px solid rgba(255, 255, 255, 0.15)',
              color: '#f8fafc',
              padding: '8px 10px',
              borderRadius: '8px',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {isMuted ? <VolumeX size={16} color="#ef4444" /> : <Volume2 size={16} color="#22c55e" />}
          </button>

          {/* Help Button */}
          <button
            onClick={toggleHelp}
            title="Controls & Tricks (H)"
            style={{
              background: showHelp ? '#ff3366' : 'rgba(15, 23, 42, 0.8)',
              border: '1px solid rgba(255, 255, 255, 0.15)',
              color: '#f8fafc',
              padding: '8px 10px',
              borderRadius: '8px',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <HelpCircle size={16} />
          </button>
        </div>
      </div>

      {/* ================= CENTER: ACTIVE TRICK & COMBO DISPLAY ================= */}
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          transform: 'translateY(-20px)',
        }}
      >
        {/* Bail Banner */}
        {isBailing && (
          <div
            style={{
              background: '#ef4444',
              color: '#fff',
              fontSize: '44px',
              fontWeight: 900,
              fontStyle: 'italic',
              padding: '8px 36px',
              borderRadius: '12px',
              boxShadow: '0 0 35px rgba(239, 68, 68, 0.8)',
              letterSpacing: '3px',
              animation: 'shake 0.3s infinite',
            }}
          >
            BAIL!
          </div>
        )}

        {/* Active Grinding Banner */}
        {isGrinding && !isBailing && (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              background: 'linear-gradient(90deg, #f59e0b, #ef4444)',
              color: '#ffffff',
              padding: '6px 22px',
              borderRadius: '30px',
              fontSize: '22px',
              fontWeight: 800,
              fontStyle: 'italic',
              letterSpacing: '1.5px',
              boxShadow: '0 0 25px rgba(245, 158, 11, 0.7)',
              marginBottom: '12px',
            }}
          >
            <Sparkles size={20} />
            <span>{currentGrindType || 'RAIL GRIND'}</span>
          </div>
        )}

        {/* Active Combo Chain */}
        {isComboActive && !isBailing && (
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '6px',
            }}
          >
            {/* List of tricks chained */}
            <div
              style={{
                display: 'flex',
                flexWrap: 'wrap',
                justifyContent: 'center',
                gap: '8px',
                maxWidth: '650px',
              }}
            >
              {comboTricks.map((trick, idx) => (
                <span
                  key={idx}
                  style={{
                    background: 'rgba(15, 23, 42, 0.85)',
                    border: '1px solid rgba(0, 240, 255, 0.5)',
                    color: '#38bdf8',
                    padding: '4px 12px',
                    borderRadius: '6px',
                    fontSize: '16px',
                    fontWeight: 700,
                    textTransform: 'uppercase',
                    letterSpacing: '0.8px',
                    boxShadow: '0 0 10px rgba(0, 240, 255, 0.2)',
                  }}
                >
                  {trick}
                </span>
              ))}
            </div>

            {/* Score & Multiplier */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '12px',
                marginTop: '8px',
              }}
            >
              <span
                style={{
                  color: '#ffffff',
                  fontSize: '38px',
                  fontWeight: 900,
                  fontStyle: 'italic',
                  textShadow: '0 2px 10px rgba(0,0,0,0.8)',
                  fontVariantNumeric: 'tabular-nums',
                }}
              >
                {currentTotalComboScore.toLocaleString()}
              </span>
              <span
                style={{
                  background: '#ff3366',
                  color: '#ffffff',
                  fontSize: '20px',
                  fontWeight: 800,
                  padding: '2px 10px',
                  borderRadius: '6px',
                  boxShadow: '0 0 15px rgba(255, 51, 102, 0.6)',
                }}
              >
                {multiplier}X
              </span>
            </div>
          </div>
        )}

        {/* Recently Landed Trick Toast (when not actively in a combo) */}
        {!isComboActive && lastLandedTrick && !isBailing && (
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              animation: 'fadeInUp 0.3s ease',
            }}
          >
            <span
              style={{
                fontSize: '28px',
                fontWeight: 900,
                fontStyle: 'italic',
                color: '#38bdf8',
                letterSpacing: '1px',
                textShadow: '0 0 15px rgba(56, 189, 248, 0.6)',
              }}
            >
              {lastLandedTrick}
            </span>
            {lastTrickPoints && (
              <span
                style={{
                  color: '#facc15',
                  fontSize: '18px',
                  fontWeight: 700,
                }}
              >
                +{lastTrickPoints.toLocaleString()} PTS
              </span>
            )}
          </div>
        )}
      </div>

      {/* ================= BOTTOM BAR: SPEEDOMETER, CHARGE & HINTS ================= */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'flex-end',
        }}
      >
        {/* Speedometer & Bunnyhop Charge */}
        <div style={{ display: 'flex', gap: '16px', alignItems: 'flex-end' }}>
          {/* Speedometer Box */}
          <div
            style={{
              background: 'rgba(15, 23, 42, 0.85)',
              backdropFilter: 'blur(8px)',
              padding: '10px 16px',
              borderRadius: '10px',
              border: '1px solid rgba(255, 255, 255, 0.12)',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'flex-start',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px' }}>
              <span
                style={{
                  color: '#f8fafc',
                  fontSize: '32px',
                  fontWeight: 900,
                  fontVariantNumeric: 'tabular-nums',
                }}
              >
                {speed}
              </span>
              <span style={{ color: '#94a3b8', fontSize: '13px', fontWeight: 700 }}>
                KM/H
              </span>
            </div>
            {/* Speed Gauge Bar */}
            <div
              style={{
                width: '110px',
                height: '6px',
                background: 'rgba(255, 255, 255, 0.1)',
                borderRadius: '3px',
                overflow: 'hidden',
                marginTop: '4px',
              }}
            >
              <div
                style={{
                  width: `${Math.min(100, (speed / 48) * 100)}%`,
                  height: '100%',
                  background:
                    speed > 35
                      ? '#ef4444'
                      : speed > 20
                      ? '#f59e0b'
                      : '#38bdf8',
                  transition: 'width 0.05s ease',
                }}
              />
            </div>
          </div>

          {/* Bunnyhop Charge Bar (Visible when Space is held) */}
          <div
            style={{
              background: 'rgba(15, 23, 42, 0.85)',
              backdropFilter: 'blur(8px)',
              padding: '10px 16px',
              borderRadius: '10px',
              border: '1px solid rgba(255, 255, 255, 0.12)',
              display: 'flex',
              flexDirection: 'column',
              opacity: jumpCharge > 0 ? 1 : 0.4,
              transition: 'opacity 0.15s ease',
            }}
          >
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                color: jumpCharge > 0.8 ? '#ff3366' : '#38bdf8',
                fontSize: '11px',
                fontWeight: 700,
                letterSpacing: '1px',
              }}
            >
              <Zap size={13} />
              <span>HOP POWER</span>
            </div>
            <div
              style={{
                width: '90px',
                height: '8px',
                background: 'rgba(255, 255, 255, 0.1)',
                borderRadius: '4px',
                overflow: 'hidden',
                marginTop: '6px',
              }}
            >
              <div
                style={{
                  width: `${jumpCharge * 100}%`,
                  height: '100%',
                  background:
                    jumpCharge > 0.85
                      ? 'linear-gradient(90deg, #f59e0b, #ff3366)'
                      : '#00f0ff',
                }}
              />
            </div>
          </div>
        </div>

        {/* Quick Key Reminders Pill */}
        <div
          style={{
            background: 'rgba(15, 23, 42, 0.75)',
            backdropFilter: 'blur(8px)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            padding: '8px 16px',
            borderRadius: '20px',
            display: 'flex',
            alignItems: 'center',
            gap: '14px',
            fontSize: '12px',
            fontWeight: 600,
            color: '#cbd5e1',
          }}
        >
          <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <MapPin size={13} color="#38bdf8" />
            <kbd style={{ color: '#fff', background: '#334155', padding: '1px 5px', borderRadius: '4px' }}>M</kbd> Save Marker
          </span>
          <span>
            <kbd style={{ color: '#fff', background: '#334155', padding: '1px 5px', borderRadius: '4px' }}>R</kbd> Respawn
          </span>
          <span>
            <kbd style={{ color: '#fff', background: '#334155', padding: '1px 5px', borderRadius: '4px' }}>H</kbd> Tricks & Controls
          </span>
        </div>
      </div>

      {/* ================= CONTROLS & TRICK HELP OVERLAY MODAL ================= */}
      {showHelp && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: 'rgba(10, 14, 23, 0.88)',
            backdropFilter: 'blur(10px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            pointerEvents: 'auto',
            zIndex: 100,
          }}
        >
          <div
            style={{
              background: '#0f172a',
              border: '1px solid rgba(0, 240, 255, 0.3)',
              borderRadius: '16px',
              padding: '32px',
              maxWidth: '680px',
              width: '90%',
              boxShadow: '0 0 50px rgba(0, 240, 255, 0.2)',
              color: '#f8fafc',
            }}
          >
            {/* Modal Header */}
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '20px',
                borderBottom: '1px solid rgba(255, 255, 255, 0.1)',
                paddingBottom: '12px',
              }}
            >
              <div>
                <h2
                  style={{
                    fontSize: '24px',
                    fontWeight: 800,
                    letterSpacing: '1px',
                    color: '#00f0ff',
                    textTransform: 'uppercase',
                  }}
                >
                  Rider Guide & Trick Bible
                </h2>
                <p style={{ color: '#94a3b8', fontSize: '13px', marginTop: '2px' }}>
                  ScootMania hybrid controls - charge hops, trigger tricks, and snap to rails
                </p>
              </div>
              <button
                onClick={toggleHelp}
                style={{
                  background: '#1e293b',
                  border: '1px solid rgba(255, 255, 255, 0.2)',
                  color: '#fff',
                  padding: '6px 12px',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontWeight: 700,
                  fontFamily: 'inherit',
                }}
              >
                CLOSE [H]
              </button>
            </div>

            {/* Controls Grid */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: '1fr 1fr',
                gap: '20px',
              }}
            >
              {/* Movement & Physics */}
              <div>
                <h3
                  style={{
                    color: '#ff3366',
                    fontSize: '15px',
                    fontWeight: 700,
                    textTransform: 'uppercase',
                    marginBottom: '10px',
                    letterSpacing: '0.8px',
                  }}
                >
                  Movement & Physics
                </h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Push Forward:</span>
                    <span style={{ color: '#fff', fontWeight: 600 }}>W / Up Arrow</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Brake / Reverse:</span>
                    <span style={{ color: '#fff', fontWeight: 600 }}>S / Down Arrow</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Steer / Lean:</span>
                    <span style={{ color: '#fff', fontWeight: 600 }}>A / D / Left / Right</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Bunnyhop (Charge & Pop):</span>
                    <span style={{ color: '#facc15', fontWeight: 700 }}>SPACE (Hold & Release)</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Air Rotation (180/360):</span>
                    <span style={{ color: '#fff', fontWeight: 600 }}>A / D (In Air)</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Manual:</span>
                    <span style={{ color: '#fff', fontWeight: 600 }}>S (Hold on Flatground)</span>
                  </div>
                </div>
              </div>

              {/* Hybrid Trick Triggers */}
              <div>
                <h3
                  style={{
                    color: '#38bdf8',
                    fontSize: '15px',
                    fontWeight: 700,
                    textTransform: 'uppercase',
                    marginBottom: '10px',
                    letterSpacing: '0.8px',
                  }}
                >
                  Air Tricks & Grinds
                </h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Tailwhip:</span>
                    <span style={{ color: '#00f0ff', fontWeight: 700 }}>J (Tap again for Double)</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Barspin:</span>
                    <span style={{ color: '#00f0ff', fontWeight: 700 }}>K (Tap again for Double)</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Bri-Flip:</span>
                    <span style={{ color: '#ff3366', fontWeight: 700 }}>L (Inverted Flip)</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Heelwhip / Decade:</span>
                    <span style={{ color: '#f59e0b', fontWeight: 700 }}>I</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#94a3b8' }}>Rail Grinds:</span>
                    <span style={{ color: '#22c55e', fontWeight: 700 }}>Pop near Rails/Ledges</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Quick Tips */}
            <div
              style={{
                marginTop: '20px',
                padding: '12px 16px',
                background: 'rgba(56, 189, 248, 0.1)',
                border: '1px solid rgba(56, 189, 248, 0.25)',
                borderRadius: '8px',
                fontSize: '12px',
                color: '#cbd5e1',
                lineHeight: 1.5,
              }}
            >
              <strong style={{ color: '#38bdf8' }}>Skater Pro Tip:</strong> Drop your session marker with{' '}
              <kbd style={{ color: '#fff', background: '#1e293b', padding: '1px 5px', borderRadius: '3px' }}>M</kbd>{' '}
              at the top of the stair set or roll-in ramp. Whenever you bail or want to re-try a trick line, hit{' '}
              <kbd style={{ color: '#fff', background: '#1e293b', padding: '1px 5px', borderRadius: '3px' }}>R</kbd>{' '}
              to instantly teleport back with zero delay!
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
