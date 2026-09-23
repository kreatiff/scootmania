import { useEffect, useRef } from 'react';
import { useGameStore } from '../store/useGameStore';

export interface KeyboardState {
  forward: boolean;
  backward: boolean;
  left: boolean;
  right: boolean;
  jump: boolean;
  jumpCharge: number;
  jumpTriggered: boolean;
  whip: boolean;
  whipTriggered: boolean;
  barspin: boolean;
  barspinTriggered: boolean;
  briflip: boolean;
  briflipTriggered: boolean;
  heelwhip: boolean;
  heelwhipTriggered: boolean;
  manual: boolean;
  noseManual: boolean;
}

export function useKeyboardControls() {
  const stateRef = useRef<KeyboardState>({
    forward: false,
    backward: false,
    left: false,
    right: false,
    jump: false,
    jumpCharge: 0,
    jumpTriggered: false,
    whip: false,
    whipTriggered: false,
    barspin: false,
    barspinTriggered: false,
    briflip: false,
    briflipTriggered: false,
    heelwhip: false,
    heelwhipTriggered: false,
    manual: false,
    noseManual: false,
  });

  const jumpStartTimeRef = useRef<number | null>(null);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Prevent browser scrolling on space and arrow keys
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) {
        e.preventDefault();
      }

      const s = stateRef.current;

      switch (e.code) {
        case 'KeyW':
        case 'ArrowUp':
          s.forward = true;
          break;
        case 'KeyS':
        case 'ArrowDown':
          s.backward = true;
          break;
        case 'KeyA':
        case 'ArrowLeft':
          s.left = true;
          break;
        case 'KeyD':
        case 'ArrowRight':
          s.right = true;
          break;
        case 'Space':
          if (!s.jump) {
            s.jump = true;
            jumpStartTimeRef.current = performance.now();
          }
          break;
        case 'KeyJ':
          s.whip = true;
          s.whipTriggered = true;
          break;
        case 'KeyK':
          s.barspin = true;
          s.barspinTriggered = true;
          break;
        case 'KeyL':
          s.briflip = true;
          s.briflipTriggered = true;
          break;
        case 'KeyI':
          s.heelwhip = true;
          s.heelwhipTriggered = true;
          break;
        case 'KeyR':
          useGameStore.getState().triggerRespawn();
          break;
        case 'KeyC':
          useGameStore.getState().cycleCameraMode();
          break;
        case 'KeyH':
          useGameStore.getState().toggleHelp();
          break;
        case 'KeyU':
          useGameStore.getState().toggleMute();
          break;
      }
    };

    const handleKeyUp = (e: KeyboardEvent) => {
      const s = stateRef.current;

      switch (e.code) {
        case 'KeyW':
        case 'ArrowUp':
          s.forward = false;
          break;
        case 'KeyS':
        case 'ArrowDown':
          s.backward = false;
          break;
        case 'KeyA':
        case 'ArrowLeft':
          s.left = false;
          break;
        case 'KeyD':
        case 'ArrowRight':
          s.right = false;
          break;
        case 'Space':
          if (s.jump) {
            s.jump = false;
            s.jumpTriggered = true;
            jumpStartTimeRef.current = null;
          }
          break;
        case 'KeyJ':
          s.whip = false;
          break;
        case 'KeyK':
          s.barspin = false;
          break;
        case 'KeyL':
          s.briflip = false;
          break;
        case 'KeyI':
          s.heelwhip = false;
          break;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
    };
  }, []);

  // Update jump charge in animation loop
  const updateCharge = () => {
    const s = stateRef.current;
    if (s.jump && jumpStartTimeRef.current !== null) {
      const elapsed = (performance.now() - jumpStartTimeRef.current) / 1000;
      // Charges to max in 0.55s
      s.jumpCharge = Math.min(1.0, elapsed / 0.55);
    } else {
      s.jumpCharge = 0;
    }
  };

  return { stateRef, updateCharge };
}
