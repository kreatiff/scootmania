import React from 'react';
import { RigidBody, CuboidCollider, CylinderCollider } from '@react-three/rapier';
import * as THREE from 'three';

// Grind rail definition for magnetic snap-to-rail assist
export interface GrindRail {
  id: string;
  start: THREE.Vector3;
  end: THREE.Vector3;
  type: 'round_rail' | 'square_ledge' | 'coping';
  height: number;
}

export const GRIND_RAILS: GrindRail[] = [
  // Stair down-rail
  {
    id: 'stair_handrail',
    start: new THREE.Vector3(-14, 2.8, -4),
    end: new THREE.Vector3(-14, 0.9, 5),
    type: 'round_rail',
    height: 0.9,
  },
  // Stair hubba ledge
  {
    id: 'stair_hubba',
    start: new THREE.Vector3(-17, 2.7, -4),
    end: new THREE.Vector3(-17, 0.8, 5),
    type: 'square_ledge',
    height: 0.8,
  },
  // Funbox flat-down rail
  {
    id: 'funbox_rail',
    start: new THREE.Vector3(0, 1.85, -6),
    end: new THREE.Vector3(0, 1.85, 6),
    type: 'round_rail',
    height: 1.85,
  },
  // Flat practice rail
  {
    id: 'flat_rail',
    start: new THREE.Vector3(12, 0.55, -8),
    end: new THREE.Vector3(12, 0.55, 8),
    type: 'round_rail',
    height: 0.55,
  },
  // Manual pad ledge
  {
    id: 'manual_pad_ledge',
    start: new THREE.Vector3(7, 0.45, -5),
    end: new THREE.Vector3(7, 0.45, 5),
    type: 'square_ledge',
    height: 0.45,
  },
  // Quarterpipe 1 Coping
  {
    id: 'qp1_coping',
    start: new THREE.Vector3(-24, 3.55, -12),
    end: new THREE.Vector3(-24, 3.55, 12),
    type: 'coping',
    height: 3.55,
  },
  // Quarterpipe 2 Coping
  {
    id: 'qp2_coping',
    start: new THREE.Vector3(24, 3.55, -12),
    end: new THREE.Vector3(24, 3.55, 12),
    type: 'coping',
    height: 3.55,
  },
];

export const Skatepark: React.FC = () => {
  const concreteColor = '#94a3b8';      // polished light concrete
  const darkConcreteColor = '#64748b';  // dark transition concrete
  const copingColor = '#e2e8f0';        // bright galvanized steel
  const railColor = '#ef4444';          // powder-coated red rail
  const railYellow = '#f59e0b';         // bright yellow rail
  const grassColor = '#22c55e';         // surrounding grass
  const curbColor = '#facc15';          // safety curb yellow

  return (
    <group dispose={null}>
      {/* ================= MAIN GROUND FLOOR ================= */}
      <RigidBody type="fixed" friction={0.4} restitution={0.05}>
        <mesh position={[0, -0.2, 0]} receiveShadow>
          <boxGeometry args={[120, 0.4, 120]} />
          <meshStandardMaterial color={concreteColor} roughness={0.7} />
        </mesh>
        <CuboidCollider args={[60, 0.2, 60]} position={[0, -0.2, 0]} />
      </RigidBody>

      {/* Surrounding Grass Buffer */}
      <mesh position={[0, -0.25, 0]} receiveShadow>
        <boxGeometry args={[200, 0.3, 200]} />
        <meshStandardMaterial color={grassColor} roughness={0.9} />
      </mesh>

      {/* Park Perimeter Safety Curbs */}
      <RigidBody type="fixed">
        <mesh position={[0, 0.2, -45]} castShadow receiveShadow>
          <boxGeometry args={[90, 0.4, 0.6]} />
          <meshStandardMaterial color={curbColor} roughness={0.8} />
        </mesh>
        <CuboidCollider args={[45, 0.2, 0.3]} position={[0, 0.2, -45]} />

        <mesh position={[0, 0.2, 45]} castShadow receiveShadow>
          <boxGeometry args={[90, 0.4, 0.6]} />
          <meshStandardMaterial color={curbColor} roughness={0.8} />
        </mesh>
        <CuboidCollider args={[45, 0.2, 0.3]} position={[0, 0.2, 45]} />

        <mesh position={[-45, 0.2, 0]} rotation={[0, Math.PI / 2, 0]} castShadow receiveShadow>
          <boxGeometry args={[90, 0.4, 0.6]} />
          <meshStandardMaterial color={curbColor} roughness={0.8} />
        </mesh>
        <CuboidCollider args={[45, 0.2, 0.3]} position={[-45, 0.2, 0]} />

        <mesh position={[45, 0.2, 0]} rotation={[0, Math.PI / 2, 0]} castShadow receiveShadow>
          <boxGeometry args={[90, 0.4, 0.6]} />
          <meshStandardMaterial color={curbColor} roughness={0.8} />
        </mesh>
        <CuboidCollider args={[45, 0.2, 0.3]} position={[45, 0.2, 0]} />
      </RigidBody>

      {/* ================= CENTRAL FUNBOX / PYRAMID ================= */}
      <group position={[0, 0, 0]}>
        {/* Tabletop platform */}
        <RigidBody type="fixed" friction={0.35}>
          <mesh position={[0, 0.6, 0]} castShadow receiveShadow>
            <boxGeometry args={[6, 1.2, 10]} />
            <meshStandardMaterial color={darkConcreteColor} roughness={0.6} />
          </mesh>
          <CuboidCollider args={[3, 0.6, 5]} position={[0, 0.6, 0]} />
        </RigidBody>

        {/* Funbox Center Grind Rail */}
        <RigidBody type="fixed">
          {/* Main Round Rail Pipe */}
          <mesh position={[0, 1.85, 0]} rotation={[Math.PI / 2, 0, 0]} castShadow>
            <cylinderGeometry args={[0.045, 0.045, 12, 16]} />
            <meshStandardMaterial color={railColor} metalness={0.9} roughness={0.2} />
          </mesh>
          {/* Support Legs */}
          {[-5, -2, 2, 5].map((zPos, i) => (
            <mesh key={i} position={[0, 1.5, zPos]} castShadow>
              <cylinderGeometry args={[0.035, 0.035, 0.7, 12]} />
              <meshStandardMaterial color="#1e293b" metalness={0.8} />
            </mesh>
          ))}
          <CuboidCollider args={[0.1, 0.1, 6]} position={[0, 1.85, 0]} />
        </RigidBody>

        {/* North Ramp */}
        <RigidBody type="fixed" friction={0.35}>
          <mesh position={[0, 0.55, -8]} rotation={[0.26, 0, 0]} castShadow receiveShadow>
            <boxGeometry args={[6, 0.2, 6.4]} />
            <meshStandardMaterial color={concreteColor} roughness={0.6} />
          </mesh>
          <CuboidCollider
            args={[3, 0.1, 3.2]}
            position={[0, 0.55, -8]}
            rotation={[0.26, 0, 0]}
          />
        </RigidBody>

        {/* South Ramp */}
        <RigidBody type="fixed" friction={0.35}>
          <mesh position={[0, 0.55, 8]} rotation={[-0.26, 0, 0]} castShadow receiveShadow>
            <boxGeometry args={[6, 0.2, 6.4]} />
            <meshStandardMaterial color={concreteColor} roughness={0.6} />
          </mesh>
          <CuboidCollider
            args={[3, 0.1, 3.2]}
            position={[0, 0.55, 8]}
            rotation={[-0.26, 0, 0]}
          />
        </RigidBody>

        {/* East Side Wedge */}
        <RigidBody type="fixed" friction={0.35}>
          <mesh position={[5.5, 0.55, 0]} rotation={[0, 0, -0.26]} castShadow receiveShadow>
            <boxGeometry args={[5.2, 0.2, 10]} />
            <meshStandardMaterial color={concreteColor} roughness={0.6} />
          </mesh>
          <CuboidCollider
            args={[2.6, 0.1, 5]}
            position={[5.5, 0.55, 0]}
            rotation={[0, 0, -0.26]}
          />
        </RigidBody>

        {/* West Side Wedge */}
        <RigidBody type="fixed" friction={0.35}>
          <mesh position={[-5.5, 0.55, 0]} rotation={[0, 0, 0.26]} castShadow receiveShadow>
            <boxGeometry args={[5.2, 0.2, 10]} />
            <meshStandardMaterial color={concreteColor} roughness={0.6} />
          </mesh>
          <CuboidCollider
            args={[2.6, 0.1, 5]}
            position={[-5.5, 0.55, 0]}
            rotation={[0, 0, 0.26]}
          />
        </RigidBody>
      </group>

      {/* ================= STREET STAIRS & HANDRAIL ================= */}
      <group position={[-15, 0, 0]}>
        {/* Upper Platform */}
        <RigidBody type="fixed" friction={0.4}>
          <mesh position={[-4, 1.0, -8]} castShadow receiveShadow>
            <boxGeometry args={[8, 2.0, 8]} />
            <meshStandardMaterial color={darkConcreteColor} roughness={0.7} />
          </mesh>
          <CuboidCollider args={[4, 1.0, 4]} position={[-4, 1.0, -8]} />
        </RigidBody>

        {/* 6 Stairs */}
        {[0, 1, 2, 3, 4, 5].map((step) => {
          const z = -3.5 + step * 0.7;
          const y = 1.75 - step * 0.3;
          const h = y * 2;
          return (
            <RigidBody key={step} type="fixed" friction={0.4}>
              <mesh position={[0, y / 2, z]} castShadow receiveShadow>
                <boxGeometry args={[5, y, 0.7]} />
                <meshStandardMaterial color={concreteColor} roughness={0.6} />
              </mesh>
              <CuboidCollider args={[2.5, y / 2, 0.35]} position={[0, y / 2, z]} />
            </RigidBody>
          );
        })}

        {/* Down Handrail (Yellow) */}
        <RigidBody type="fixed">
          {/* Rail Pipe angled down stairs */}
          <mesh position={[1, 1.85, 0.5]} rotation={[0.42, 0, 0]} castShadow>
            <cylinderGeometry args={[0.04, 0.04, 9.5, 16]} />
            <meshStandardMaterial color={railYellow} metalness={0.9} roughness={0.2} />
          </mesh>
          {/* Vertical Legs */}
          <mesh position={[1, 1.9, -3.2]} castShadow>
            <cylinderGeometry args={[0.03, 0.03, 1.1, 12]} />
            <meshStandardMaterial color="#1e293b" metalness={0.8} />
          </mesh>
          <mesh position={[1, 0.9, 4.2]} castShadow>
            <cylinderGeometry args={[0.03, 0.03, 0.9, 12]} />
            <meshStandardMaterial color="#1e293b" metalness={0.8} />
          </mesh>
          <CuboidCollider
            args={[0.08, 0.08, 4.8]}
            position={[1, 1.85, 0.5]}
            rotation={[0.42, 0, 0]}
          />
        </RigidBody>

        {/* Hubba Ledge along stairs */}
        <RigidBody type="fixed" friction={0.25}>
          <mesh position={[-2, 1.75, 0.5]} rotation={[0.42, 0, 0]} castShadow receiveShadow>
            <boxGeometry args={[0.6, 0.4, 9.5]} />
            <meshStandardMaterial color={darkConcreteColor} roughness={0.5} />
          </mesh>
          {/* Metal Angle Coping on Hubba edge */}
          <mesh position={[-1.72, 1.96, 0.5]} rotation={[0.42, 0, 0]}>
            <boxGeometry args={[0.05, 0.05, 9.5]} />
            <meshStandardMaterial color={copingColor} metalness={0.9} roughness={0.2} />
          </mesh>
          <CuboidCollider
            args={[0.3, 0.2, 4.8]}
            position={[-2, 1.75, 0.5]}
            rotation={[0.42, 0, 0]}
          />
        </RigidBody>
      </group>

      {/* ================= FLAT PRACTICE RAIL & MANUAL PAD ================= */}
      <group position={[12, 0, 0]}>
        {/* Flat Red Rail */}
        <RigidBody type="fixed">
          <mesh position={[0, 0.55, 0]} rotation={[Math.PI / 2, 0, 0]} castShadow>
            <cylinderGeometry args={[0.04, 0.04, 16, 16]} />
            <meshStandardMaterial color={railColor} metalness={0.9} roughness={0.2} />
          </mesh>
          {[-7, -2.5, 2.5, 7].map((z, idx) => (
            <mesh key={idx} position={[0, 0.27, z]} castShadow>
              <cylinderGeometry args={[0.03, 0.03, 0.55, 12]} />
              <meshStandardMaterial color="#1e293b" metalness={0.8} />
            </mesh>
          ))}
          <CuboidCollider args={[0.08, 0.08, 8]} position={[0, 0.55, 0]} />
        </RigidBody>

        {/* Low Manual Pad */}
        <RigidBody type="fixed" friction={0.3}>
          <mesh position={[-5, 0.22, 0]} castShadow receiveShadow>
            <boxGeometry args={[3.2, 0.44, 10]} />
            <meshStandardMaterial color={darkConcreteColor} roughness={0.6} />
          </mesh>
          {/* Coping along manual pad edge */}
          <mesh position={[-3.42, 0.43, 0]}>
            <boxGeometry args={[0.06, 0.06, 10]} />
            <meshStandardMaterial color={copingColor} metalness={0.85} roughness={0.2} />
          </mesh>
          <CuboidCollider args={[1.6, 0.22, 5]} position={[-5, 0.22, 0]} />
        </RigidBody>
      </group>

      {/* ================= QUARTERPIPE 1 (WEST LAUNCH RAMP) ================= */}
      <group position={[-26, 0, 0]}>
        {/* Transition segments approximating a smooth 3.5m radius curve */}
        {[
          { y: 0.2, z: 4.8, rotX: -0.15, depth: 2.2, h: 0.4 },
          { y: 0.7, z: 3.0, rotX: -0.35, depth: 2.0, h: 0.4 },
          { y: 1.5, z: 1.5, rotX: -0.65, depth: 2.0, h: 0.4 },
          { y: 2.6, z: 0.4, rotX: -1.05, depth: 2.0, h: 0.4 },
          { y: 3.4, z: -0.2, rotX: -1.45, depth: 1.6, h: 0.4 },
        ].map((seg, idx) => (
          <RigidBody key={idx} type="fixed" friction={0.2}>
            <mesh
              position={[2, seg.y, 0]}
              rotation={[0, 0, -seg.rotX]}
              castShadow
              receiveShadow
            >
              <boxGeometry args={[seg.depth, seg.h, 24]} />
              <meshStandardMaterial color={concreteColor} roughness={0.5} />
            </mesh>
            <CuboidCollider
              args={[seg.depth / 2, seg.h / 2, 12]}
              position={[2, seg.y, 0]}
              rotation={[0, 0, -seg.rotX]}
            />
          </RigidBody>
        ))}

        {/* Top Deck Platform */}
        <RigidBody type="fixed" friction={0.4}>
          <mesh position={[-2, 3.4, 0]} castShadow receiveShadow>
            <boxGeometry args={[5, 0.4, 24]} />
            <meshStandardMaterial color={darkConcreteColor} roughness={0.7} />
          </mesh>
          <CuboidCollider args={[2.5, 0.2, 12]} position={[-2, 3.4, 0]} />
        </RigidBody>

        {/* Metal Coping along top lip */}
        <RigidBody type="fixed">
          <mesh position={[0.45, 3.55, 0]} rotation={[Math.PI / 2, 0, 0]} castShadow>
            <cylinderGeometry args={[0.07, 0.07, 24, 16]} />
            <meshStandardMaterial color={copingColor} metalness={0.9} roughness={0.2} />
          </mesh>
          <CuboidCollider args={[0.1, 0.1, 12]} position={[0.45, 3.55, 0]} />
        </RigidBody>
      </group>

      {/* ================= QUARTERPIPE 2 (EAST LAUNCH RAMP) ================= */}
      <group position={[26, 0, 0]} rotation={[0, Math.PI, 0]}>
        {[
          { y: 0.2, z: 4.8, rotX: -0.15, depth: 2.2, h: 0.4 },
          { y: 0.7, z: 3.0, rotX: -0.35, depth: 2.0, h: 0.4 },
          { y: 1.5, z: 1.5, rotX: -0.65, depth: 2.0, h: 0.4 },
          { y: 2.6, z: 0.4, rotX: -1.05, depth: 2.0, h: 0.4 },
          { y: 3.4, z: -0.2, rotX: -1.45, depth: 1.6, h: 0.4 },
        ].map((seg, idx) => (
          <RigidBody key={idx} type="fixed" friction={0.2}>
            <mesh
              position={[2, seg.y, 0]}
              rotation={[0, 0, -seg.rotX]}
              castShadow
              receiveShadow
            >
              <boxGeometry args={[seg.depth, seg.h, 24]} />
              <meshStandardMaterial color={concreteColor} roughness={0.5} />
            </mesh>
            <CuboidCollider
              args={[seg.depth / 2, seg.h / 2, 12]}
              position={[2, seg.y, 0]}
              rotation={[0, 0, -seg.rotX]}
            />
          </RigidBody>
        ))}

        {/* Top Deck Platform */}
        <RigidBody type="fixed" friction={0.4}>
          <mesh position={[-2, 3.4, 0]} castShadow receiveShadow>
            <boxGeometry args={[5, 0.4, 24]} />
            <meshStandardMaterial color={darkConcreteColor} roughness={0.7} />
          </mesh>
          <CuboidCollider args={[2.5, 0.2, 12]} position={[-2, 3.4, 0]} />
        </RigidBody>

        {/* Metal Coping */}
        <RigidBody type="fixed">
          <mesh position={[0.45, 3.55, 0]} rotation={[Math.PI / 2, 0, 0]} castShadow>
            <cylinderGeometry args={[0.07, 0.07, 24, 16]} />
            <meshStandardMaterial color={copingColor} metalness={0.9} roughness={0.2} />
          </mesh>
          <CuboidCollider args={[0.1, 0.1, 12]} position={[0.45, 3.55, 0]} />
        </RigidBody>
      </group>

      {/* ================= NORTH BOWL / HALFPIPE ================= */}
      <group position={[0, 0, -28]}>
        {/* Back wall quarterpipe */}
        {[
          { y: 0.2, x: 0, z: -3.8, rotX: 0.2, len: 26, h: 0.4, d: 2.2 },
          { y: 0.7, x: 0, z: -5.4, rotX: 0.45, len: 26, h: 0.4, d: 2.0 },
          { y: 1.5, x: 0, z: -6.7, rotX: 0.8, len: 26, h: 0.4, d: 2.0 },
          { y: 2.5, x: 0, z: -7.6, rotX: 1.25, len: 26, h: 0.4, d: 1.8 },
        ].map((b, i) => (
          <RigidBody key={i} type="fixed" friction={0.2}>
            <mesh position={[b.x, b.y, b.z]} rotation={[b.rotX, 0, 0]} castShadow receiveShadow>
              <boxGeometry args={[b.len, b.h, b.d]} />
              <meshStandardMaterial color={darkConcreteColor} roughness={0.5} />
            </mesh>
            <CuboidCollider
              args={[b.len / 2, b.h / 2, b.d / 2]}
              position={[b.x, b.y, b.z]}
              rotation={[b.rotX, 0, 0]}
            />
          </RigidBody>
        ))}

        {/* North Bowl Coping */}
        <RigidBody type="fixed">
          <mesh position={[0, 3.2, -8.3]} rotation={[0, 0, Math.PI / 2]} castShadow>
            <cylinderGeometry args={[0.07, 0.07, 26, 16]} />
            <meshStandardMaterial color={copingColor} metalness={0.9} roughness={0.2} />
          </mesh>
          <CuboidCollider args={[13, 0.1, 0.1]} position={[0, 3.2, -8.3]} />
        </RigidBody>
      </group>

      {/* ================= ENVIRONMENT ASSETS ================= */}
      {/* Stadium Floodlights */}
      {[
        [-38, 0, -38],
        [38, 0, -38],
        [-38, 0, 38],
        [38, 0, 38],
      ].map(([x, y, z], i) => (
        <group key={i} position={[x, y, z]}>
          {/* Concrete Base */}
          <mesh position={[0, 0.4, 0]} castShadow>
            <cylinderGeometry args={[0.6, 0.8, 0.8, 8]} />
            <meshStandardMaterial color="#475569" roughness={0.9} />
          </mesh>
          {/* Light Mast */}
          <mesh position={[0, 6, 0]} castShadow>
            <cylinderGeometry args={[0.12, 0.22, 12, 10]} />
            <meshStandardMaterial color="#334155" metalness={0.8} />
          </mesh>
          {/* Light Head Bank */}
          <mesh position={[0, 12.2, 0]} rotation={[0.4, Math.atan2(-x, -z), 0]} castShadow>
            <boxGeometry args={[2.8, 1.4, 0.4]} />
            <meshStandardMaterial color="#1e293b" />
          </mesh>
          {/* Spotlights glow */}
          <pointLight
            position={[0, 12.5, 0]}
            intensity={250}
            distance={50}
            color="#fef08a"
          />
        </group>
      ))}

      {/* Low-Poly Palm Trees */}
      {[
        [-36, 0, -15],
        [-36, 0, 15],
        [36, 0, -15],
        [36, 0, 15],
        [-15, 0, 36],
        [15, 0, 36],
      ].map(([x, y, z], i) => (
        <group key={i} position={[x, y, z]}>
          {/* Curved Trunk */}
          <mesh position={[0, 2.5, 0]} rotation={[0.1, 0, 0.05]} castShadow>
            <cylinderGeometry args={[0.22, 0.35, 5, 8]} />
            <meshStandardMaterial color="#78350f" roughness={0.9} />
          </mesh>
          {/* Palm Fronds Canopy */}
          {[0, 1, 2, 3, 4].map((frond) => (
            <mesh
              key={frond}
              position={[0, 5.0, 0]}
              rotation={[0.45, (frond * Math.PI * 2) / 5, 0]}
              castShadow
            >
              <coneGeometry args={[1.6, 2.2, 5]} />
              <meshStandardMaterial color="#15803d" roughness={0.8} />
            </mesh>
          ))}
        </group>
      ))}

      {/* Park Benches */}
      {[
        [-8, 0, 25],
        [8, 0, 25],
      ].map(([x, y, z], i) => (
        <group key={i} position={[x, y, z]}>
          {/* Wooden Slats */}
          <mesh position={[0, 0.45, 0]} castShadow>
            <boxGeometry args={[3.2, 0.08, 0.5]} />
            <meshStandardMaterial color="#92400e" roughness={0.7} />
          </mesh>
          {/* Bench Legs */}
          <mesh position={[-1.3, 0.22, 0]} castShadow>
            <boxGeometry args={[0.08, 0.44, 0.4]} />
            <meshStandardMaterial color="#1e293b" metalness={0.8} />
          </mesh>
          <mesh position={[1.3, 0.22, 0]} castShadow>
            <boxGeometry args={[0.08, 0.44, 0.4]} />
            <meshStandardMaterial color="#1e293b" metalness={0.8} />
          </mesh>
        </group>
      ))}
    </group>
  );
};
