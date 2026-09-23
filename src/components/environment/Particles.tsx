import React, { useRef, useImperativeHandle, forwardRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

export interface ParticleHandle {
  emitSparks: (position: THREE.Vector3, velocity: THREE.Vector3) => void;
  emitDust: (position: THREE.Vector3, count?: number) => void;
}

const MAX_SPARKS = 150;
const MAX_DUST = 80;

export const Particles = forwardRef<ParticleHandle>((_, ref) => {
  // Sparks
  const sparkPointsRef = useRef<THREE.Points>(null);
  const sparkGeoRef = useRef<THREE.BufferGeometry>(null);
  const sparkPositions = useRef<Float32Array>(new Float32Array(MAX_SPARKS * 3));
  const sparkVelocities = useRef<Float32Array>(new Float32Array(MAX_SPARKS * 3));
  const sparkLifetimes = useRef<Float32Array>(new Float32Array(MAX_SPARKS));
  const sparkIndex = useRef<number>(0);

  // Dust
  const dustPointsRef = useRef<THREE.Points>(null);
  const dustGeoRef = useRef<THREE.BufferGeometry>(null);
  const dustPositions = useRef<Float32Array>(new Float32Array(MAX_DUST * 3));
  const dustVelocities = useRef<Float32Array>(new Float32Array(MAX_DUST * 3));
  const dustLifetimes = useRef<Float32Array>(new Float32Array(MAX_DUST));
  const dustIndex = useRef<number>(0);

  useImperativeHandle(ref, () => ({
    emitSparks: (pos: THREE.Vector3, vel: THREE.Vector3) => {
      for (let i = 0; i < 4; i++) {
        const idx = sparkIndex.current;
        sparkIndex.current = (sparkIndex.current + 1) % MAX_SPARKS;

        sparkPositions.current[idx * 3] = pos.x + (Math.random() - 0.5) * 0.1;
        sparkPositions.current[idx * 3 + 1] = pos.y + (Math.random() - 0.5) * 0.05;
        sparkPositions.current[idx * 3 + 2] = pos.z + (Math.random() - 0.5) * 0.1;

        // Spray sparks backward and upward
        sparkVelocities.current[idx * 3] = -vel.x * 0.3 + (Math.random() - 0.5) * 4;
        sparkVelocities.current[idx * 3 + 1] = Math.random() * 3 + 1;
        sparkVelocities.current[idx * 3 + 2] = -vel.z * 0.3 + (Math.random() - 0.5) * 4;

        sparkLifetimes.current[idx] = 0.35 + Math.random() * 0.2;
      }
    },

    emitDust: (pos: THREE.Vector3, count = 12) => {
      for (let i = 0; i < count; i++) {
        const idx = dustIndex.current;
        dustIndex.current = (dustIndex.current + 1) % MAX_DUST;

        dustPositions.current[idx * 3] = pos.x + (Math.random() - 0.5) * 0.3;
        dustPositions.current[idx * 3 + 1] = pos.y + 0.05;
        dustPositions.current[idx * 3 + 2] = pos.z + (Math.random() - 0.5) * 0.3;

        const angle = Math.random() * Math.PI * 2;
        const speed = Math.random() * 2 + 1;
        dustVelocities.current[idx * 3] = Math.cos(angle) * speed;
        dustVelocities.current[idx * 3 + 1] = Math.random() * 1.5 + 0.5;
        dustVelocities.current[idx * 3 + 2] = Math.sin(angle) * speed;

        dustLifetimes.current[idx] = 0.5 + Math.random() * 0.3;
      }
    },
  }));

  useFrame((_, delta) => {
    // Update sparks
    const spPos = sparkPositions.current;
    const spVel = sparkVelocities.current;
    const spLife = sparkLifetimes.current;

    for (let i = 0; i < MAX_SPARKS; i++) {
      if (spLife[i] > 0) {
        spLife[i] -= delta;
        spPos[i * 3] += spVel[i * 3] * delta;
        spPos[i * 3 + 1] += spVel[i * 3 + 1] * delta;
        spPos[i * 3 + 2] += spVel[i * 3 + 2] * delta;
        spVel[i * 3 + 1] -= 9.8 * delta; // gravity
        if (spPos[i * 3 + 1] < 0) spPos[i * 3 + 1] = 0;
      } else {
        spPos[i * 3 + 1] = -100; // hide
      }
    }
    if (sparkGeoRef.current) {
      sparkGeoRef.current.attributes.position.needsUpdate = true;
    }

    // Update dust
    const dPos = dustPositions.current;
    const dVel = dustVelocities.current;
    const dLife = dustLifetimes.current;

    for (let i = 0; i < MAX_DUST; i++) {
      if (dLife[i] > 0) {
        dLife[i] -= delta;
        dPos[i * 3] += dVel[i * 3] * delta;
        dPos[i * 3 + 1] += dVel[i * 3 + 1] * delta;
        dPos[i * 3 + 2] += dVel[i * 3 + 2] * delta;
        dVel[i * 3] *= 0.95;
        dVel[i * 3 + 1] *= 0.92;
        dVel[i * 3 + 2] *= 0.95;
      } else {
        dPos[i * 3 + 1] = -100;
      }
    }
    if (dustGeoRef.current) {
      dustGeoRef.current.attributes.position.needsUpdate = true;
    }
  });

  return (
    <group>
      {/* Grind Sparks */}
      <points ref={sparkPointsRef}>
        <bufferGeometry ref={sparkGeoRef}>
          <bufferAttribute
            attach="attributes-position"
            count={MAX_SPARKS}
            array={sparkPositions.current}
            itemSize={3}
          />
        </bufferGeometry>
        <pointsMaterial
          size={0.12}
          color="#ffaa22"
          transparent
          opacity={0.9}
          blending={THREE.AdditiveBlending}
          depthWrite={false}
        />
      </points>

      {/* Landing Dust */}
      <points ref={dustPointsRef}>
        <bufferGeometry ref={dustGeoRef}>
          <bufferAttribute
            attach="attributes-position"
            count={MAX_DUST}
            array={dustPositions.current}
            itemSize={3}
          />
        </bufferGeometry>
        <pointsMaterial
          size={0.25}
          color="#cbd5e1"
          transparent
          opacity={0.4}
          depthWrite={false}
        />
      </points>
    </group>
  );
});

Particles.displayName = 'Particles';
