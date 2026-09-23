import React, { useRef, Suspense } from 'react';
import { Canvas } from '@react-three/fiber';
import { Physics } from '@react-three/rapier';
import { Sky } from '@react-three/drei';
import * as THREE from 'three';
import { Skatepark } from './components/environment/Skatepark';
import { ScooterController } from './components/scooter/ScooterController';
import { FollowCamera } from './components/camera/FollowCamera';
import { Particles, ParticleHandle } from './components/environment/Particles';
import { HUD } from './components/ui/HUD';
import { useGameStore } from './store/useGameStore';

// Holographic 3D marker ring indicating where the player will respawn
const SessionMarkerVisual: React.FC = () => {
  const marker = useGameStore((s) => s.sessionMarker);
  if (!marker) return null;

  return (
    <group position={[marker.position[0], 0.05, marker.position[2]]}>
      {/* Outer ring */}
      <mesh rotation={[-Math.PI / 2, 0, 0]}>
        <ringGeometry args={[0.7, 0.85, 32]} />
        <meshBasicMaterial color="#00f0ff" transparent opacity={0.6} side={THREE.DoubleSide} />
      </mesh>
      {/* Inner dot */}
      <mesh rotation={[-Math.PI / 2, 0, 0]}>
        <circleGeometry args={[0.2, 16]} />
        <meshBasicMaterial color="#ff3366" transparent opacity={0.8} />
      </mesh>
      {/* Direction Arrow */}
      <group rotation={[0, -marker.yaw, 0]}>
        <mesh position={[0, 0.01, 0.45]} rotation={[-Math.PI / 2, 0, 0]}>
          <coneGeometry args={[0.15, 0.35, 3]} />
          <meshBasicMaterial color="#00f0ff" />
        </mesh>
      </group>
    </group>
  );
};

export function App() {
  const particleRef = useRef<ParticleHandle>(null);

  return (
    <div style={{ width: '100vw', height: '100vh', position: 'relative', overflow: 'hidden' }}>
      <Canvas
        shadows
        gl={{
          antialias: true,
          toneMapping: THREE.ACESFilmicToneMapping,
          toneMappingExposure: 1.05,
        }}
        camera={{ position: [0, 2, 5], fov: 65 }}
      >
        {/* Skybox & Atmospheric Lighting */}
        <Sky
          sunPosition={[40, 25, 30]}
          turbidity={6}
          rayleigh={0.8}
          mieCoefficient={0.005}
          mieDirectionalG={0.8}
        />
        <ambientLight intensity={0.4} />
        <hemisphereLight
          args={['#e0f2fe', '#64748b', 0.5]}
        />
        <directionalLight
          position={[40, 50, 30]}
          intensity={1.3}
          castShadow
          shadow-mapSize-width={2048}
          shadow-mapSize-height={2048}
          shadow-camera-near={1}
          shadow-camera-far={140}
          shadow-camera-left={-45}
          shadow-camera-right={45}
          shadow-camera-top={45}
          shadow-camera-bottom={-45}
          shadow-bias={-0.0003}
        />

        {/* Soft park fog */}
        <fog attach="fog" args={['#bfdbfe', 40, 110]} />

        {/* Rapier Physics World */}
        <Suspense fallback={null}>
          <Physics gravity={[0, -18.0, 0]}>
            <Skatepark />
            <ScooterController particleRef={particleRef} />
            <FollowCamera />
            <SessionMarkerVisual />
          </Physics>
        </Suspense>

        {/* Spark and dust particles */}
        <Particles ref={particleRef} />
      </Canvas>

      {/* 2D HUD & Controls Layer */}
      <HUD />
    </div>
  );
}

export default App;
