export type TrickType =
  | 'Ollie'
  | 'Tailwhip'
  | 'Double Tailwhip'
  | 'Barspin'
  | 'Double Barspin'
  | 'Bri Flip'
  | 'Invert'
  | 'Decade'
  | 'Heelwhip'
  | 'Manual'
  | 'Nose Manual'
  | '50-50 Grind'
  | 'Feeble Grind'
  | 'Smith Grind'
  | 'Board Slide';

export interface TrickInfo {
  name: string;
  points: number;
  rotation?: number; // e.g., 180, 360, 540
  duration?: number;
}

export type CameraMode = 'chase_low' | 'chase_high' | 'free_orbit';

export interface SessionMarker {
  position: [number, number, number];
  rotation: [number, number, number, number]; // quaternion [x, y, z, w]
  yaw: number;
}

export interface InputState {
  forward: boolean;
  backward: boolean;
  left: boolean;
  right: boolean;
  jump: boolean;
  jumpJustPressed: boolean;
  jumpJustReleased: boolean;
  jumpCharge: number; // 0 to 1
  whip: boolean;
  barspin: boolean;
  briflip: boolean;
  heelwhip: boolean;
  manual: boolean;
  noseManual: boolean;
  reset: boolean;
  setMarker: boolean;
  toggleCam: boolean;
  toggleHelp: boolean;
  mute: boolean;
}
