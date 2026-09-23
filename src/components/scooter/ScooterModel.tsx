import React, { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

interface ScooterModelProps {
  steerAngle: number;
  deckRotation: number;    // for tailwhips (radians)
  barRotation: number;     // for barspins (radians)
  flipRotation: number;    // for bri-flips (radians)
  pitchAngle: number;      // for manuals (radians)
  crouchAmount: number;    // 0 to 1 (bunnyhop charge)
  wheelSpeed: number;      // for wheel spinning
  leanAngle: number;       // banking during carves
  isGrinding: boolean;
  isBailing: boolean;
}

export const ScooterModel: React.FC<ScooterModelProps> = ({
  steerAngle,
  deckRotation,
  barRotation,
  flipRotation,
  pitchAngle,
  crouchAmount,
  wheelSpeed,
  leanAngle,
  isGrinding,
  isBailing,
}) => {
  const rootRef = useRef<THREE.Group>(null);
  const deckRef = useRef<THREE.Group>(null);
  const steerAssemblyRef = useRef<THREE.Group>(null);
  const barAssemblyRef = useRef<THREE.Group>(null);
  const frontWheelRef = useRef<THREE.Mesh>(null);
  const rearWheelRef = useRef<THREE.Mesh>(null);

  // Rider limbs
  const riderRef = useRef<THREE.Group>(null);
  const riderTorsoRef = useRef<THREE.Group>(null);
  const riderLeftArmRef = useRef<THREE.Group>(null);
  const riderRightArmRef = useRef<THREE.Group>(null);
  const riderLeftLegRef = useRef<THREE.Group>(null);
  const riderRightLegRef = useRef<THREE.Group>(null);

  useFrame((_, delta) => {
    // Wheel spin
    if (frontWheelRef.current && rearWheelRef.current) {
      const spinDelta = wheelSpeed * delta * 12;
      frontWheelRef.current.rotation.x += spinDelta;
      rearWheelRef.current.rotation.x += spinDelta;
    }

    // Steer angle (yaw)
    if (steerAssemblyRef.current) {
      steerAssemblyRef.current.rotation.y = THREE.MathUtils.lerp(
        steerAssemblyRef.current.rotation.y,
        steerAngle,
        0.3
      );
    }

    // Barspin rotation around steerer tube
    if (barAssemblyRef.current) {
      barAssemblyRef.current.rotation.y = barRotation;
    }

    // Tailwhip rotation (deck spinning around headset)
    if (deckRef.current) {
      deckRef.current.rotation.y = deckRotation;
    }

    // Bri-flip & manual pitch
    if (rootRef.current) {
      rootRef.current.rotation.x = pitchAngle + flipRotation;
      rootRef.current.rotation.z = leanAngle;

      if (isBailing) {
        rootRef.current.rotation.x += Math.PI * 0.45;
        rootRef.current.rotation.z += Math.PI * 0.3;
      }
    }

    // Rider crouching and reactive poses
    if (riderRef.current) {
      const crouchY = -crouchAmount * 0.22;
      riderRef.current.position.y = THREE.MathUtils.lerp(
        riderRef.current.position.y,
        crouchY,
        0.2
      );

      // Tailwhip kick out pose
      if (Math.abs(deckRotation) > 0.1 && Math.abs(deckRotation) < Math.PI * 1.8) {
        if (riderRightLegRef.current) riderRightLegRef.current.rotation.z = -0.6;
        if (riderLeftLegRef.current) riderLeftLegRef.current.rotation.z = 0.5;
      } else {
        if (riderRightLegRef.current) riderRightLegRef.current.rotation.z = THREE.MathUtils.lerp(riderRightLegRef.current.rotation.z, 0, 0.2);
        if (riderLeftLegRef.current) riderLeftLegRef.current.rotation.z = THREE.MathUtils.lerp(riderLeftLegRef.current.rotation.z, 0, 0.2);
      }

      // Barspin arms release / catch
      const isBarspinning = Math.abs(barRotation) > 0.2 && Math.abs(barRotation) < Math.PI * 1.8;
      if (riderLeftArmRef.current && riderRightArmRef.current) {
        if (isBarspinning) {
          riderLeftArmRef.current.rotation.x = THREE.MathUtils.lerp(riderLeftArmRef.current.rotation.x, -0.4, 0.3);
          riderRightArmRef.current.rotation.x = THREE.MathUtils.lerp(riderRightArmRef.current.rotation.x, -0.4, 0.3);
        } else {
          riderLeftArmRef.current.rotation.x = THREE.MathUtils.lerp(riderLeftArmRef.current.rotation.x, 0.6, 0.2);
          riderRightArmRef.current.rotation.x = THREE.MathUtils.lerp(riderRightArmRef.current.rotation.x, 0.6, 0.2);
        }
      }
    }
  });

  // Materials
  const deckColor = '#1f242e';
  const clampColor = '#ff3366'; // neon hot pink / anodized
  const barColor = '#00f0ff';   // neon cyan
  const gripColor = '#111115';
  const wheelColor = '#222228';
  const rimColor = '#e6e6e6';
  const riderHoodieColor = '#3b82f6'; // vibrant blue hoodie
  const riderPantsColor = '#1e293b';  // dark charcoal denim
  const riderSkinColor = '#f8c291';
  const riderHelmetColor = '#f59e0b'; // golden yellow helmet

  return (
    <group ref={rootRef} dispose={null}>
      {/* SCOOTER DECK & REAR WHEEL ASSEMBLY */}
      <group ref={deckRef} position={[0, 0.08, 0]}>
        {/* Extruded Aluminum Deck */}
        <mesh position={[0, 0.04, -0.22]} castShadow receiveShadow>
          <boxGeometry args={[0.22, 0.04, 0.85]} />
          <meshStandardMaterial color={deckColor} roughness={0.3} metalness={0.7} />
        </mesh>

        {/* Grip Tape */}
        <mesh position={[0, 0.062, -0.22]} receiveShadow>
          <planeGeometry args={[0.20, 0.82]} />
          <meshStandardMaterial color="#090a0d" roughness={0.95} />
        </mesh>

        {/* Deck Center Cutout Graphic Stripe */}
        <mesh position={[0, 0.063, -0.22]}>
          <planeGeometry args={[0.04, 0.70]} />
          <meshStandardMaterial color={clampColor} roughness={0.5} />
        </mesh>

        {/* Headtube Neck */}
        <mesh position={[0, 0.16, 0.20]} rotation={[0.35, 0, 0]} castShadow>
          <boxGeometry args={[0.08, 0.28, 0.06]} />
          <meshStandardMaterial color={deckColor} roughness={0.3} metalness={0.8} />
        </mesh>

        {/* Headtube Tube */}
        <mesh position={[0, 0.27, 0.25]} rotation={[0.25, 0, 0]} castShadow>
          <cylinderGeometry args={[0.05, 0.05, 0.18, 16]} />
          <meshStandardMaterial color={deckColor} roughness={0.2} metalness={0.85} />
        </mesh>

        {/* Rear Wheel Fork Dropouts */}
        <mesh position={[0.07, 0.04, -0.66]} castShadow>
          <boxGeometry args={[0.02, 0.05, 0.12]} />
          <meshStandardMaterial color={deckColor} metalness={0.8} />
        </mesh>
        <mesh position={[-0.07, 0.04, -0.66]} castShadow>
          <boxGeometry args={[0.02, 0.05, 0.12]} />
          <meshStandardMaterial color={deckColor} metalness={0.8} />
        </mesh>

        {/* Rear Wheel Assembly */}
        <group position={[0, 0.04, -0.66]}>
          <mesh ref={rearWheelRef} rotation={[0, 0, Math.PI / 2]} castShadow>
            <cylinderGeometry args={[0.085, 0.085, 0.05, 20]} />
            <meshStandardMaterial color={wheelColor} roughness={0.7} />
          </mesh>
          {/* Rear Rim Core */}
          <mesh rotation={[0, 0, Math.PI / 2]}>
            <cylinderGeometry args={[0.05, 0.05, 0.055, 12]} />
            <meshStandardMaterial color={rimColor} metalness={0.9} roughness={0.2} />
          </mesh>
        </group>

        {/* Rear Brake Fender */}
        <mesh position={[0, 0.11, -0.63]} rotation={[-0.3, 0, 0]} castShadow>
          <boxGeometry args={[0.08, 0.015, 0.14]} />
          <meshStandardMaterial color="#111115" metalness={0.9} />
        </mesh>
      </group>

      {/* STEER ASSEMBLY (Fork, Front Wheel, Clamp, Bars) */}
      {/* Origin is at headtube axis: approx [0, 0.27, 0.25] */}
      <group position={[0, 0.27, 0.25]} rotation={[0.25, 0, 0]}>
        <group ref={steerAssemblyRef}>
          {/* Fork Stem */}
          <mesh position={[0, -0.06, 0]} castShadow>
            <cylinderGeometry args={[0.035, 0.035, 0.24, 16]} />
            <meshStandardMaterial color={deckColor} metalness={0.85} />
          </mesh>

          {/* Fork Legs */}
          <mesh position={[0.05, -0.20, 0]} castShadow>
            <boxGeometry args={[0.02, 0.16, 0.04]} />
            <meshStandardMaterial color={deckColor} metalness={0.85} />
          </mesh>
          <mesh position={[-0.05, -0.20, 0]} castShadow>
            <boxGeometry args={[0.02, 0.16, 0.04]} />
            <meshStandardMaterial color={deckColor} metalness={0.85} />
          </mesh>

          {/* Front Wheel */}
          <group position={[0, -0.23, 0]}>
            <mesh ref={frontWheelRef} rotation={[0, 0, Math.PI / 2]} castShadow>
              <cylinderGeometry args={[0.085, 0.085, 0.05, 20]} />
              <meshStandardMaterial color={wheelColor} roughness={0.7} />
            </mesh>
            <mesh rotation={[0, 0, Math.PI / 2]}>
              <cylinderGeometry args={[0.05, 0.05, 0.055, 12]} />
              <meshStandardMaterial color={rimColor} metalness={0.9} roughness={0.2} />
            </mesh>
          </group>

          {/* SCS / IHC Quad Clamp */}
          <mesh position={[0, 0.09, 0]} castShadow>
            <cylinderGeometry args={[0.048, 0.048, 0.14, 16]} />
            <meshStandardMaterial color={clampColor} metalness={0.9} roughness={0.2} />
          </mesh>

          {/* BARS ASSEMBLY (Able to spin for barspin!) */}
          <group ref={barAssemblyRef} position={[0, 0.15, 0]}>
            {/* Vertical Bar Tube (T-Bar) */}
            <mesh position={[0, 0.42, 0]} castShadow>
              <cylinderGeometry args={[0.03, 0.03, 0.84, 16]} />
              <meshStandardMaterial color={barColor} metalness={0.7} roughness={0.3} />
            </mesh>

            {/* Gussets / Support Triangle for T-Bar */}
            <mesh position={[0, 0.78, 0]} rotation={[0, 0, Math.PI / 4]} castShadow>
              <boxGeometry args={[0.08, 0.08, 0.03]} />
              <meshStandardMaterial color={barColor} metalness={0.7} />
            </mesh>

            {/* Crossbar (Handlebars) */}
            <mesh position={[0, 0.84, 0]} rotation={[0, 0, Math.PI / 2]} castShadow>
              <cylinderGeometry args={[0.03, 0.03, 0.76, 16]} />
              <meshStandardMaterial color={barColor} metalness={0.7} roughness={0.3} />
            </mesh>

            {/* Left Grip */}
            <mesh position={[-0.26, 0.84, 0]} rotation={[0, 0, Math.PI / 2]} castShadow>
              <cylinderGeometry args={[0.038, 0.038, 0.20, 16]} />
              <meshStandardMaterial color={gripColor} roughness={0.8} />
            </mesh>

            {/* Right Grip */}
            <mesh position={[0.26, 0.84, 0]} rotation={[0, 0, Math.PI / 2]} castShadow>
              <cylinderGeometry args={[0.038, 0.038, 0.20, 16]} />
              <meshStandardMaterial color={gripColor} roughness={0.8} />
            </mesh>

            {/* Bar Ends */}
            <mesh position={[-0.37, 0.84, 0]} rotation={[0, 0, Math.PI / 2]}>
              <cylinderGeometry args={[0.039, 0.039, 0.02, 16]} />
              <meshStandardMaterial color={clampColor} metalness={0.9} />
            </mesh>
            <mesh position={[0.37, 0.84, 0]} rotation={[0, 0, Math.PI / 2]}>
              <cylinderGeometry args={[0.039, 0.039, 0.02, 16]} />
              <meshStandardMaterial color={clampColor} metalness={0.9} />
            </mesh>
          </group>
        </group>
      </group>

      {/* LOW-POLY RIDER CHARACTER */}
      <group ref={riderRef} position={[0, 0.12, 0]}>
        {/* FEET & SNEAKERS */}
        {/* Front Foot (angled slightly across deck) */}
        <group position={[-0.03, 0.06, -0.05]} rotation={[0, 0.35, 0]}>
          <mesh castShadow>
            <boxGeometry args={[0.11, 0.08, 0.24]} />
            <meshStandardMaterial color="#f1f5f9" roughness={0.7} />
          </mesh>
          <mesh position={[0, -0.025, 0]}>
            <boxGeometry args={[0.115, 0.03, 0.25]} />
            <meshStandardMaterial color="#0f172a" roughness={0.9} />
          </mesh>
        </group>

        {/* Back Foot (near brake) */}
        <group ref={riderRightLegRef} position={[0.02, 0.06, -0.42]} rotation={[0, 0.45, 0]}>
          <mesh castShadow>
            <boxGeometry args={[0.11, 0.08, 0.24]} />
            <meshStandardMaterial color="#f1f5f9" roughness={0.7} />
          </mesh>
          <mesh position={[0, -0.025, 0]}>
            <boxGeometry args={[0.115, 0.03, 0.25]} />
            <meshStandardMaterial color="#0f172a" roughness={0.9} />
          </mesh>
        </group>

        {/* LEGS (Jeans) */}
        <group ref={riderLeftLegRef} position={[-0.05, 0.36, -0.1]}>
          <mesh rotation={[0.15, 0, 0.05]} castShadow>
            <cylinderGeometry args={[0.08, 0.065, 0.52, 10]} />
            <meshStandardMaterial color={riderPantsColor} roughness={0.8} />
          </mesh>
        </group>

        <group position={[0.05, 0.36, -0.32]}>
          <mesh rotation={[-0.15, 0, -0.05]} castShadow>
            <cylinderGeometry args={[0.08, 0.065, 0.52, 10]} />
            <meshStandardMaterial color={riderPantsColor} roughness={0.8} />
          </mesh>
        </group>

        {/* HIPS & TORSO */}
        <group ref={riderTorsoRef} position={[0, 0.65, -0.18]} rotation={[0.18, 0.1, 0]}>
          {/* Hips */}
          <mesh castShadow>
            <boxGeometry args={[0.26, 0.16, 0.20]} />
            <meshStandardMaterial color={riderPantsColor} roughness={0.8} />
          </mesh>

          {/* Hoodie Torso */}
          <mesh position={[0, 0.24, 0]} castShadow>
            <boxGeometry args={[0.32, 0.40, 0.24]} />
            <meshStandardMaterial color={riderHoodieColor} roughness={0.65} />
          </mesh>

          {/* Hoodie Pocket / Kangaroo Pouch */}
          <mesh position={[0, 0.18, 0.13]} castShadow>
            <boxGeometry args={[0.22, 0.14, 0.04]} />
            <meshStandardMaterial color="#2563eb" roughness={0.65} />
          </mesh>

          {/* NECK & HEAD */}
          <group position={[0, 0.48, 0.04]}>
            {/* Neck */}
            <mesh castShadow>
              <cylinderGeometry args={[0.06, 0.07, 0.1, 10]} />
              <meshStandardMaterial color={riderSkinColor} roughness={0.6} />
            </mesh>

            {/* Head */}
            <mesh position={[0, 0.11, 0]} castShadow>
              <sphereGeometry args={[0.12, 12, 12]} />
              <meshStandardMaterial color={riderSkinColor} roughness={0.6} />
            </mesh>

            {/* Skate Helmet */}
            <group position={[0, 0.14, 0]}>
              <mesh castShadow>
                <sphereGeometry args={[0.135, 14, 14, 0, Math.PI * 2, 0, Math.PI * 0.65]} />
                <meshStandardMaterial color={riderHelmetColor} roughness={0.3} metalness={0.1} />
              </mesh>
              {/* Helmet Brim */}
              <mesh position={[0, -0.02, 0.12]} rotation={[-0.2, 0, 0]}>
                <boxGeometry args={[0.16, 0.02, 0.05]} />
                <meshStandardMaterial color="#1e293b" />
              </mesh>
            </group>
          </group>

          {/* ARMS reaching forward to handlebars */}
          {/* Left Arm */}
          <group ref={riderLeftArmRef} position={[-0.18, 0.34, 0.08]} rotation={[0.6, 0.25, -0.3]}>
            {/* Shoulder to elbow */}
            <mesh position={[0, -0.16, 0]} castShadow>
              <cylinderGeometry args={[0.055, 0.05, 0.32, 10]} />
              <meshStandardMaterial color={riderHoodieColor} roughness={0.65} />
            </mesh>
            {/* Forearm & hand */}
            <group position={[0, -0.32, 0]} rotation={[-0.45, 0, 0]}>
              <mesh position={[0, -0.14, 0]} castShadow>
                <cylinderGeometry args={[0.048, 0.042, 0.28, 10]} />
                <meshStandardMaterial color={riderHoodieColor} roughness={0.65} />
              </mesh>
              {/* Hand */}
              <mesh position={[0, -0.28, 0]} castShadow>
                <boxGeometry args={[0.07, 0.07, 0.08]} />
                <meshStandardMaterial color={riderSkinColor} roughness={0.6} />
              </mesh>
            </group>
          </group>

          {/* Right Arm */}
          <group ref={riderRightArmRef} position={[0.18, 0.34, 0.08]} rotation={[0.6, -0.25, 0.3]}>
            <mesh position={[0, -0.16, 0]} castShadow>
              <cylinderGeometry args={[0.055, 0.05, 0.32, 10]} />
              <meshStandardMaterial color={riderHoodieColor} roughness={0.65} />
            </mesh>
            <group position={[0, -0.32, 0]} rotation={[-0.45, 0, 0]}>
              <mesh position={[0, -0.14, 0]} castShadow>
                <cylinderGeometry args={[0.048, 0.042, 0.28, 10]} />
                <meshStandardMaterial color={riderHoodieColor} roughness={0.65} />
              </mesh>
              {/* Hand */}
              <mesh position={[0, -0.28, 0]} castShadow>
                <boxGeometry args={[0.07, 0.07, 0.08]} />
                <meshStandardMaterial color={riderSkinColor} roughness={0.6} />
              </mesh>
            </group>
          </group>
        </group>
      </group>
    </group>
  );
};
