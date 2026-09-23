import React, { useRef, useState, useEffect } from 'react';
import { useFrame } from '@react-three/fiber';
import {
  RigidBody,
  CapsuleCollider,
  RapierRigidBody,
  useRapier,
} from '@react-three/rapier';
import * as THREE from 'three';
import { ScooterModel } from './ScooterModel';
import { useKeyboardControls } from '../../hooks/useKeyboardControls';
import { useGameStore } from '../../store/useGameStore';
import { sound } from '../../systems/audio';
import { GRIND_RAILS, GrindRail } from '../environment/Skatepark';
import { ParticleHandle } from '../environment/Particles';

interface ScooterControllerProps {
  particleRef: React.RefObject<ParticleHandle>;
}

export const ScooterController: React.FC<ScooterControllerProps> = ({ particleRef }) => {
  const rbRef = useRef<RapierRigidBody>(null);
  const { rapier, world } = useRapier();
  const { stateRef, updateCharge } = useKeyboardControls();

  // Internal visual & animation state
  const [steerAngle, setSteerAngle] = useState(0);
  const [deckRotation, setDeckRotation] = useState(0);
  const [barRotation, setBarRotation] = useState(0);
  const [flipRotation, setFlipRotation] = useState(0);
  const [pitchAngle, setPitchAngle] = useState(0);
  const [leanAngle, setLeanAngle] = useState(0);
  const [wheelSpeed, setWheelSpeed] = useState(0);

  // Trick execution state
  const activeWhipRef = useRef<{ progress: number; spins: number } | null>(null);
  const activeBarspinRef = useRef<{ progress: number; spins: number } | null>(null);
  const activeBriFlipRef = useRef<{ progress: number } | null>(null);
  const activeHeelwhipRef = useRef<{ progress: number } | null>(null);

  // Rotation & spin tracking in air
  const airYawStartRef = useRef<number>(0);
  const totalAirYawRef = useRef<number>(0);
  const airTimeRef = useRef<number>(0);
  const isGroundedRef = useRef<boolean>(true);
  const isGrindingRef = useRef<boolean>(false);
  const activeRailRef = useRef<GrindRail | null>(null);
  const lastGrindSparkTimeRef = useRef<number>(0);
  const comboBankTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Sound push timer
  const lastPushSoundTime = useRef<number>(0);

  const {
    sessionMarker,
    respawnCount,
    setGrounded,
    setGrinding,
    setSpeed,
    setJumpCharge,
    addTrickToCombo,
    bankCombo,
    bailCombo,
    isBailing,
  } = useGameStore();

  // Handle respawn when respawnCount triggers
  useEffect(() => {
    if (!rbRef.current || !sessionMarker) return;
    const [x, y, z] = sessionMarker.position;
    rbRef.current.setTranslation({ x, y: y + 0.5, z }, true);
    rbRef.current.setLinvel({ x: 0, y: 0, z: 0 }, true);
    rbRef.current.setAngvel({ x: 0, y: 0, z: 0 }, true);

    const q = new THREE.Quaternion().setFromAxisAngle(
      new THREE.Vector3(0, 1, 0),
      sessionMarker.yaw
    );
    rbRef.current.setRotation({ x: q.x, y: q.y, z: q.z, w: q.w }, true);

    // Reset trick animations
    activeWhipRef.current = null;
    activeBarspinRef.current = null;
    activeBriFlipRef.current = null;
    activeHeelwhipRef.current = null;
    setDeckRotation(0);
    setBarRotation(0);
    setFlipRotation(0);
    setPitchAngle(0);
  }, [respawnCount, sessionMarker]);

  // Set Session Marker key ('M')
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.code === 'KeyM' && rbRef.current) {
        const pos = rbRef.current.translation();
        const rot = rbRef.current.rotation();
        const q = new THREE.Quaternion(rot.x, rot.y, rot.z, rot.w);
        const euler = new THREE.Euler().setFromQuaternion(q, 'YXZ');
        useGameStore.getState().setSessionMarker({
          position: [pos.x, pos.y, pos.z],
          rotation: [rot.x, rot.y, rot.z, rot.w],
          yaw: euler.y,
        });
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  useFrame((_, delta) => {
    if (!rbRef.current) return;
    const body = rbRef.current;
    const input = stateRef.current;

    updateCharge();
    setJumpCharge(input.jumpCharge);

    const pos = body.translation();
    const vel = body.linvel();
    const angvel = body.angvel();
    const rot = body.rotation();

    const currentSpeed = Math.sqrt(vel.x * vel.x + vel.z * vel.z);
    setSpeed(Math.round(currentSpeed * 3.6)); // km/h
    setWheelSpeed(currentSpeed);

    // Quaternion & orientation
    const q = new THREE.Quaternion(rot.x, rot.y, rot.z, rot.w);
    const forward = new THREE.Vector3(0, 0, 1).applyQuaternion(q);
    const up = new THREE.Vector3(0, 1, 0).applyQuaternion(q);
    const right = new THREE.Vector3(1, 0, 0).applyQuaternion(q);
    const euler = new THREE.Euler().setFromQuaternion(q, 'YXZ');

    // 1. Raycast ground detection
    const rayOrigin = new rapier.Vector3(pos.x, pos.y + 0.1, pos.z);
    const rayDir = new rapier.Vector3(0, -1, 0);
    const ray = new rapier.Ray(rayOrigin, rayDir);
    const maxToi = 0.55;
    const hit = world.castRay(ray, maxToi, true, undefined, undefined, undefined, body);

    const wasGrounded = isGroundedRef.current;
    const isGrounded = !!hit && !isGrindingRef.current;
    isGroundedRef.current = isGrounded;
    setGrounded(isGrounded);

    // Update wheel rolling sound
    sound.updateRollSound(currentSpeed, isGrounded);

    // Landing detection
    if (!wasGrounded && isGrounded && !isGrindingRef.current) {
      const impactSpeed = Math.abs(vel.y);
      sound.playLandingSound(impactSpeed);

      if (particleRef.current) {
        particleRef.current.emitDust(new THREE.Vector3(pos.x, pos.y - 0.25, pos.z), Math.min(20, Math.floor(impactSpeed * 3)));
      }

      // Check bail angle (landing too tilted)
      const tiltAngle = Math.acos(Math.min(1, Math.max(-1, up.y)));
      if (tiltAngle > 1.25 && !isBailing) {
        // Punishing hard bail if upside down
        bailCombo();
      } else {
        // Check air rotation completed (180, 360, 540)
        const airSpinDeg = Math.round(Math.abs(totalAirYawRef.current) * (180 / Math.PI));
        if (airSpinDeg >= 130) {
          const roundedSpin = Math.round(airSpinDeg / 180) * 180;
          if (roundedSpin > 0) {
            addTrickToCombo(`${roundedSpin}° Spin`, roundedSpin * 2);
          }
        }

        // Start combo bank timer (1.8s of flatland before banking combo)
        if (comboBankTimerRef.current) clearTimeout(comboBankTimerRef.current);
        comboBankTimerRef.current = setTimeout(() => {
          if (useGameStore.getState().isGrounded && !useGameStore.getState().isGrinding) {
            bankCombo();
          }
        }, 1800);
      }

      // Reset air tracking
      totalAirYawRef.current = 0;
      airTimeRef.current = 0;
    }

    if (!isGrounded && !isGrindingRef.current) {
      airTimeRef.current += delta;
      totalAirYawRef.current += angvel.y * delta;
    }

    // 2. MAGNETIC SNAP-TO-RAIL GRIND ASSIST
    let isGrindDetected = false;
    let targetRail: GrindRail | null = null;
    const scooterPos = new THREE.Vector3(pos.x, pos.y, pos.z);

    if (!isGrounded && vel.y < 2.0) {
      for (const rail of GRIND_RAILS) {
        // Project position onto rail segment
        const railVec = new THREE.Vector3().subVectors(rail.end, rail.start);
        const railLen = railVec.length();
        const railDir = railVec.clone().normalize();

        const toScooter = new THREE.Vector3().subVectors(scooterPos, rail.start);
        const proj = toScooter.dot(railDir);

        if (proj >= -0.2 && proj <= railLen + 0.2) {
          const closestPoint = rail.start.clone().add(railDir.clone().multiplyScalar(proj));
          const dist = scooterPos.distanceTo(closestPoint);

          // Close enough to snap onto rail!
          if (dist < 1.1 && Math.abs(pos.y - rail.height) < 0.8) {
            isGrindDetected = true;
            targetRail = rail;

            // Snap position to rail with slight upward offset
            body.setTranslation(
              {
                x: closestPoint.x,
                y: rail.height + 0.38,
                z: closestPoint.z,
              },
              true
            );

            // Align velocity along rail direction
            const forwardSpeed = Math.max(3.5, currentSpeed);
            // Determine travel direction along rail
            const travelDir = forward.dot(railDir) >= 0 ? 1 : -1;
            const grindVel = railDir.clone().multiplyScalar(forwardSpeed * travelDir);

            body.setLinvel({ x: grindVel.x, y: 0, z: grindVel.z }, true);
            body.setAngvel({ x: 0, y: 0, z: 0 }, true);

            // Snap yaw to rail heading
            const railAngle = Math.atan2(grindVel.x, grindVel.z);
            const railQ = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), railAngle);
            body.setRotation({ x: railQ.x, y: railQ.y, z: railQ.z, w: railQ.w }, true);

            break;
          }
        }
      }
    }

    // Update grinding state
    if (isGrindDetected && targetRail) {
      if (!isGrindingRef.current) {
        isGrindingRef.current = true;
        activeRailRef.current = targetRail;
        const grindName = targetRail.type === 'round_rail' ? '50-50 Grind' : targetRail.type === 'coping' ? 'Smith Grind' : 'Feeble Grind';
        setGrinding(true, grindName);
        addTrickToCombo(grindName, 350);
      }

      // Spark particles while grinding
      const now = performance.now();
      if (now - lastGrindSparkTimeRef.current > 50 && particleRef.current) {
        lastGrindSparkTimeRef.current = now;
        particleRef.current.emitSparks(
          new THREE.Vector3(pos.x, pos.y - 0.25, pos.z),
          new THREE.Vector3(vel.x, vel.y, vel.z)
        );
      }

      sound.updateGrindSound(true, currentSpeed);
    } else {
      if (isGrindingRef.current) {
        isGrindingRef.current = false;
        activeRailRef.current = null;
        setGrinding(false, null);
        sound.updateGrindSound(false, 0);
      }
    }

    // 3. BUNNY HOP / POP
    if (input.jumpTriggered) {
      input.jumpTriggered = false;
      if (isGrounded || isGrindingRef.current) {
        const chargeFactor = Math.max(0.2, input.jumpCharge);
        const popSpeed = 5.2 + chargeFactor * 4.5; // up to 9.7 m/s pop
        body.setLinvel({ x: vel.x, y: popSpeed, z: vel.z }, true);

        sound.playPopSound(chargeFactor);
        isGroundedRef.current = false;
        isGrindingRef.current = false;
        setGrounded(false);
        setGrinding(false, null);

        airYawStartRef.current = euler.y;
        totalAirYawRef.current = 0;

        addTrickToCombo('Bunnyhop', 50);

        if (comboBankTimerRef.current) clearTimeout(comboBankTimerRef.current);
      }
    }

    // 4. DRIVING & STEERING (Ground / Semi-Arcade)
    if (isGrounded && !isBailing) {
      // Pushing forward
      if (input.forward) {
        const maxSpeed = 13.5;
        if (currentSpeed < maxSpeed) {
          const pushForce = 28.0;
          body.applyImpulse({ x: forward.x * pushForce, y: 0, z: forward.z * pushForce }, true);

          const now = performance.now();
          if (now - lastPushSoundTime.current > 650) {
            lastPushSoundTime.current = now;
            sound.playPushSound();
          }
        }
      }

      // Braking / Reverse
      if (input.backward) {
        if (currentSpeed > 0.5) {
          // Brake hard
          body.setLinvel({ x: vel.x * 0.92, y: vel.y, z: vel.z * 0.92 }, true);
        } else {
          // Reverse slowly
          const revForce = 10.0;
          body.applyImpulse({ x: -forward.x * revForce, y: 0, z: -forward.z * revForce }, true);
        }
      }

      // Steering
      const steerSpeed = 3.6;
      let targetSteer = 0;
      if (input.left) {
        targetSteer = 0.45;
        body.setAngvel({ x: 0, y: steerSpeed, z: 0 }, true);
      } else if (input.right) {
        targetSteer = -0.45;
        body.setAngvel({ x: 0, y: -steerSpeed, z: 0 }, true);
      } else {
        body.setAngvel({ x: 0, y: angvel.y * 0.85, z: 0 }, true);
      }
      setSteerAngle(targetSteer);

      // Banking lean
      const targetLean = -targetSteer * Math.min(1.0, currentSpeed / 6) * 0.4;
      setLeanAngle(targetLean);

      // Manual / Nose manual balance
      if (input.backward && currentSpeed > 1.5 && !input.forward) {
        setPitchAngle(0.35); // Manual
      } else {
        setPitchAngle(0);
      }
    } else if (!isGrounded && !isGrindingRef.current) {
      // In mid-air: A & D control air rotation (180, 360, 540)
      if (input.left) {
        body.setAngvel({ x: 0, y: 5.5, z: 0 }, true);
      } else if (input.right) {
        body.setAngvel({ x: 0, y: -5.5, z: 0 }, true);
      }

      // SEMI-ARCADE LANDING ALIGNMENT ASSIST
      // If close to ground and falling, smoothly align pitch and roll towards upright
      if (vel.y < 0 && hit && hit.timeOfImpact < 0.9) {
        const uprightQ = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), euler.y);
        const slerpedQ = q.clone().slerp(uprightQ, 0.15);
        body.setRotation({ x: slerpedQ.x, y: slerpedQ.y, z: slerpedQ.z, w: slerpedQ.w }, true);
        body.setAngvel({ x: angvel.x * 0.7, y: angvel.y, z: angvel.z * 0.7 }, true);
      }
    }

    // 5. HYBRID TRICK ENGINE (Tailwhip, Barspin, Bri-Flip, Heelwhip)
    // Tailwhip (J)
    if (input.whipTriggered) {
      input.whipTriggered = false;
      if (!isGrounded || isGrindingRef.current) {
        if (!activeWhipRef.current) {
          activeWhipRef.current = { progress: 0, spins: 1 };
        } else {
          // Double tailwhip!
          activeWhipRef.current.spins = 2;
        }
      }
    }

    if (activeWhipRef.current) {
      const whip = activeWhipRef.current;
      whip.progress += delta * 7.5; // fast whip snap
      const currentRot = whip.progress * Math.PI * 2;
      setDeckRotation(currentRot);

      if (whip.progress >= whip.spins) {
        setDeckRotation(0);
        const trickName = whip.spins === 2 ? 'Double Tailwhip' : 'Tailwhip';
        const points = whip.spins === 2 ? 650 : 300;
        addTrickToCombo(trickName, points);
        activeWhipRef.current = null;
      }
    }

    // Barspin (K)
    if (input.barspinTriggered) {
      input.barspinTriggered = false;
      if (!isGrounded || isGrindingRef.current) {
        if (!activeBarspinRef.current) {
          activeBarspinRef.current = { progress: 0, spins: 1 };
        } else {
          activeBarspinRef.current.spins = 2;
        }
      }
    }

    if (activeBarspinRef.current) {
      const bar = activeBarspinRef.current;
      bar.progress += delta * 8.0;
      const currentRot = bar.progress * Math.PI * 2;
      setBarRotation(currentRot);

      if (bar.progress >= bar.spins) {
        setBarRotation(0);
        const trickName = bar.spins === 2 ? 'Double Barspin' : 'Barspin';
        const points = bar.spins === 2 ? 550 : 250;
        addTrickToCombo(trickName, points);
        activeBarspinRef.current = null;
      }
    }

    // Bri-Flip (L)
    if (input.briflipTriggered) {
      input.briflipTriggered = false;
      if (!isGrounded && !activeBriFlipRef.current) {
        activeBriFlipRef.current = { progress: 0 };
      }
    }

    if (activeBriFlipRef.current) {
      const bri = activeBriFlipRef.current;
      bri.progress += delta * 5.0;
      const currentRot = bri.progress * Math.PI * 2;
      setFlipRotation(currentRot);

      if (bri.progress >= 1.0) {
        setFlipRotation(0);
        addTrickToCombo('Bri Flip', 800);
        activeBriFlipRef.current = null;
      }
    }

    // Heelwhip / Decade (I)
    if (input.heelwhipTriggered) {
      input.heelwhipTriggered = false;
      if (!isGrounded && !activeHeelwhipRef.current) {
        activeHeelwhipRef.current = { progress: 0 };
      }
    }

    if (activeHeelwhipRef.current) {
      const heel = activeHeelwhipRef.current;
      heel.progress += delta * 7.0;
      // Spins opposite direction to tailwhip
      const currentRot = -heel.progress * Math.PI * 2;
      setDeckRotation(currentRot);

      if (heel.progress >= 1.0) {
        setDeckRotation(0);
        addTrickToCombo('Heelwhip', 450);
        activeHeelwhipRef.current = null;
      }
    }
  });

  return (
    <RigidBody
      ref={rbRef}
      colliders={false}
      type="dynamic"
      position={[0, 1.2, 0]}
      friction={0.3}
      restitution={0.05}
      linearDamping={0.4}
      angularDamping={2.5}
      ccd={true}
    >
      {/* Main scooter capsule collider */}
      <CapsuleCollider args={[0.3, 0.28]} position={[0, 0.45, 0]} />

      <ScooterModel
        steerAngle={steerAngle}
        deckRotation={deckRotation}
        barRotation={barRotation}
        flipRotation={flipRotation}
        pitchAngle={pitchAngle}
        crouchAmount={stateRef.current.jumpCharge}
        wheelSpeed={wheelSpeed}
        leanAngle={leanAngle}
        isGrinding={useGameStore((s) => s.isGrinding)}
        isBailing={isBailing}
      />
    </RigidBody>
  );
};
