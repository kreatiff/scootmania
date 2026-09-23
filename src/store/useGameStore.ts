import { create } from 'zustand';
import confetti from 'canvas-confetti';
import { CameraMode, SessionMarker } from '../types/game';
import { sound } from '../systems/audio';

interface GameState {
  score: number;
  comboScore: number;
  multiplier: number;
  comboTricks: string[];
  lastLandedTrick: string | null;
  lastTrickPoints: number | null;
  isGrounded: boolean;
  isGrinding: boolean;
  currentGrindType: string | null;
  speed: number;
  jumpCharge: number;
  isBailing: boolean;
  cameraMode: CameraMode;
  sessionMarker: SessionMarker | null;
  respawnCount: number;
  isMuted: boolean;
  showHelp: boolean;

  // Actions
  addTrickToCombo: (name: string, points: number) => void;
  bankCombo: () => void;
  bailCombo: () => void;
  setGrounded: (grounded: boolean) => void;
  setGrinding: (grinding: boolean, type?: string | null) => void;
  setSpeed: (speed: number) => void;
  setJumpCharge: (charge: number) => void;
  setSessionMarker: (marker: SessionMarker) => void;
  triggerRespawn: () => void;
  cycleCameraMode: () => void;
  toggleMute: () => void;
  toggleHelp: () => void;
  resetScore: () => void;
}

export const useGameStore = create<GameState>((set, get) => ({
  score: 0,
  comboScore: 0,
  multiplier: 1,
  comboTricks: [],
  lastLandedTrick: null,
  lastTrickPoints: null,
  isGrounded: true,
  isGrinding: false,
  currentGrindType: null,
  speed: 0,
  jumpCharge: 0,
  isBailing: false,
  cameraMode: 'chase_low',
  sessionMarker: {
    position: [0, 1.0, 0],
    rotation: [0, 0, 0, 1],
    yaw: 0,
  },
  respawnCount: 0,
  isMuted: false,
  showHelp: false,

  addTrickToCombo: (name: string, points: number) => {
    const { comboTricks, comboScore, multiplier } = get();
    const newTricks = [...comboTricks, name];
    const newMultiplier = Math.min(10, Math.floor(newTricks.length * 1.2) + 1);

    sound.playTrickSuccessSound(newTricks.length);

    set({
      comboTricks: newTricks,
      comboScore: comboScore + points,
      multiplier: newMultiplier,
      lastLandedTrick: name,
      lastTrickPoints: points * newMultiplier,
    });
  },

  bankCombo: () => {
    const { comboScore, multiplier, comboTricks, score } = get();
    if (comboTricks.length === 0) return;

    const earned = comboScore * multiplier;
    const newTotal = score + earned;

    if (earned >= 5000) {
      try {
        confetti({
          particleCount: 50,
          spread: 60,
          origin: { y: 0.8 },
        });
      } catch {
        // no-op if confetti fails
      }
    }

    set({
      score: newTotal,
      comboScore: 0,
      multiplier: 1,
      comboTricks: [],
    });
  },

  bailCombo: () => {
    const { comboTricks } = get();
    sound.playBailSound();
    set({
      comboScore: 0,
      multiplier: 1,
      comboTricks: [],
      lastLandedTrick: comboTricks.length > 0 ? 'BAIL!' : null,
      lastTrickPoints: null,
      isBailing: true,
    });

    setTimeout(() => {
      set({ isBailing: false });
    }, 1200);
  },

  setGrounded: (isGrounded: boolean) => set({ isGrounded }),

  setGrinding: (isGrinding: boolean, currentGrindType: string | null = null) => {
    set({ isGrinding, currentGrindType });
  },

  setSpeed: (speed: number) => set({ speed }),

  setJumpCharge: (jumpCharge: number) => set({ jumpCharge }),

  setSessionMarker: (marker: SessionMarker) => {
    set({ sessionMarker: marker });
  },

  triggerRespawn: () => {
    set((state) => ({ respawnCount: state.respawnCount + 1, isBailing: false }));
  },

  cycleCameraMode: () => {
    const modes: CameraMode[] = ['chase_low', 'chase_high', 'free_orbit'];
    const current = get().cameraMode;
    const nextIdx = (modes.indexOf(current) + 1) % modes.length;
    set({ cameraMode: modes[nextIdx] });
  },

  toggleMute: () => {
    const next = !get().isMuted;
    sound.setMuted(next);
    set({ isMuted: next });
  },

  toggleHelp: () => {
    set((state) => ({ showHelp: !state.showHelp }));
  },

  resetScore: () => set({ score: 0, comboScore: 0, multiplier: 1, comboTricks: [] }),
}));
