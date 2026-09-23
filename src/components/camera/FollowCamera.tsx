import React, { useRef } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import { useRapier } from '@react-three/rapier';
import * as THREE from 'three';
import { useGameStore } from '../../store/useGameStore';

export const FollowCamera: React.FC = () => {
  const { camera } = useThree();
  const { rapier, world } = useRapier();
  const cameraMode = useGameStore((s) => s.cameraMode);
  const isBailing = useGameStore((s) => s.isBailing);

  // Smooth target positions
  const currentPos = useRef(new THREE.Vector3(0, 2, 5));
  const currentLookAt = useRef(new THREE.Vector3(0, 1, 0));
  const shakeIntensity = useRef(0);

  useFrame((_, delta) => {
    // Find the dynamic scooter rigid body in the Rapier world
    let scooterPos = new THREE.Vector3(0, 1, 0);
    let scooterVel = new THREE.Vector3(0, 0, 0);
    let scooterRotation = new THREE.Quaternion();

    world.forEachRigidBody((body) => {
      if (body.isDynamic()) {
        const t = body.translation();
        const v = body.linvel();
        const r = body.rotation();
        scooterPos.set(t.x, t.y, t.z);
        scooterVel.set(v.x, v.y, v.z);
        scooterRotation.set(r.x, r.y, r.z, r.w);
      }
    });

    const speed = scooterVel.length();

    // Trigger camera shake on bail
    if (isBailing) {
      shakeIntensity.current = Math.max(shakeIntensity.current, 0.25);
    }
    shakeIntensity.current = THREE.MathUtils.lerp(shakeIntensity.current, 0, delta * 5);

    // Compute forward and up vectors
    const forward = new THREE.Vector3(0, 0, 1).applyQuaternion(scooterRotation);
    // Smooth out vertical pitch of forward vector for camera offset
    const flatForward = new THREE.Vector3(forward.x, 0, forward.z).normalize();
    if (flatForward.lengthSq() < 0.1) flatForward.set(0, 0, 1);

    let targetOffset: THREE.Vector3;
    let lookAtOffset: THREE.Vector3;
    let targetFov = 65;

    switch (cameraMode) {
      case 'chase_low':
        // Classic Skate fisheye/low chase angle
        targetOffset = flatForward
          .clone()
          .multiplyScalar(-2.8)
          .add(new THREE.Vector3(0, 0.95, 0));
        lookAtOffset = new THREE.Vector3(0, 0.75, 0).add(flatForward.clone().multiplyScalar(0.8));
        targetFov = 65 + Math.min(18, (speed / 15) * 15);
        break;

      case 'chase_high':
        // High arcade overview
        targetOffset = flatForward
          .clone()
          .multiplyScalar(-5.2)
          .add(new THREE.Vector3(0, 2.8, 0));
        lookAtOffset = new THREE.Vector3(0, 0.8, 0);
        targetFov = 60 + Math.min(10, (speed / 15) * 10);
        break;

      case 'free_orbit':
      default:
        targetOffset = new THREE.Vector3(0, 3.5, 6);
        lookAtOffset = new THREE.Vector3(0, 0.8, 0);
        targetFov = 60;
        break;
    }

    const desiredCamPos = scooterPos.clone().add(targetOffset);
    const desiredLookAt = scooterPos.clone().add(lookAtOffset);

    // Camera shake
    if (shakeIntensity.current > 0.01) {
      const s = shakeIntensity.current;
      desiredCamPos.x += (Math.random() - 0.5) * s;
      desiredCamPos.y += (Math.random() - 0.5) * s;
      desiredCamPos.z += (Math.random() - 0.5) * s;
    }

    // Smooth lerp
    const lerpFactor = Math.min(1.0, delta * 7.5);
    currentPos.current.lerp(desiredCamPos, lerpFactor);
    currentLookAt.current.lerp(desiredLookAt, lerpFactor * 1.2);

    camera.position.copy(currentPos.current);
    camera.lookAt(currentLookAt.current);

    // Dynamic FOV for speed
    if ('fov' in camera) {
      const perspCam = camera as THREE.PerspectiveCamera;
      perspCam.fov = THREE.MathUtils.lerp(perspCam.fov, targetFov, delta * 4);
      perspCam.updateProjectionMatrix();
    }
  });

  return null;
};
