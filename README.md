# ScootMania 🛴⚡

An arcade 3D freestyle scooter game built for the browser using **React**, **Three.js** / **React Three Fiber**, **Rapier Physics**, **Zustand**, and procedural **Web Audio API** sound synthesis.

![ScootMania](public/scooter.svg)

## 🎮 Features

- **Realistic Scooter Mechanics & Physics**: Responsive steering, carving, jump charge bunnyhops, and semi-arcade landing alignment assists powered by Rapier 3D.
- **Tricks & Combos**:
  - **J**: Tailwhip (and Double Tailwhip)
  - **K**: Barspin (and Double Barspin)
  - **L**: Bri-Flip
  - **I**: Heelwhip
  - **Air Rotations**: 180°, 360°, 540° spins using steer controls mid-air
  - **Grinds**: Magnetic rail snap-to-grind on round rails, copings, and square ledges (50-50, Smith, Feeble) with procedural spark particles!
- **Dynamic Camera**: Toggle between chase low, chase high, and free orbit views.
- **Session Marker**: Set your line respawn marker and teleport back anytime.
- **Procedural Sound Engine**: Zero audio asset loading — real-time physical wheel roll noise, deck slaps, bunnyhops, grinds, and trick chimes generated via the Web Audio API.

## ⌨️ Controls

| Key | Action |
| --- | --- |
| `W` / `↑` | Push / Accelerate |
| `S` / `↓` | Brake / Reverse |
| `A` / `D` or `←` / `→` | Steer & Carve / Air Spin |
| `Space` | Hold to charge bunnyhop, release to pop |
| `J` | Tailwhip |
| `K` | Barspin |
| `L` | Bri-Flip |
| `I` | Heelwhip |
| `R` | Respawn at Session Marker |
| `C` | Cycle Camera Mode |
| `H` | Toggle Controls Overlay |
| `U` | Toggle Audio Mute |

## 🛠️ Tech Stack

- **Framework**: [React 18](https://react.dev/) + [TypeScript](https://www.typescriptlang.org/)
- **Build Tool**: [Vite](https://vitejs.dev/)
- **3D Graphics**: [Three.js](https://threejs.org/) + [@react-three/fiber](https://docs.pmnd.rs/react-three-fiber/) + [@react-three/drei](https://github.com/pmndrs/drei)
- **Physics**: [@react-three/rapier](https://github.com/pmndrs/react-three-rapier)
- **State Management**: [Zustand](https://github.com/pmndrs/zustand)
- **Icons & FX**: [lucide-react](https://lucide.dev/), [canvas-confetti](https://www.npmjs.com/package/canvas-confetti)

## 🚀 Getting Started

### Prerequisites

- Node.js (v18 or higher)
- npm or yarn / pnpm

### Installation

```bash
# Clone the repository
git clone https://github.com/kreatiff/ScootMania.git
cd ScootMania

# Install dependencies
npm install

# Start local development server
npm run dev
```

### Build for Production

```bash
npm run build
```

## 📄 License

MIT
