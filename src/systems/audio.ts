// Procedural Web Audio API sound synthesizer for ScootMania
// Zero external sound assets needed - works 100% offline and instantly

class SoundEngine {
  private ctx: AudioContext | null = null;
  private isMuted: boolean = false;

  // Rolling sound state
  private rollGain: GainNode | null = null;
  private rollFilter: BiquadFilterNode | null = null;
  private rollNoiseSource: AudioBufferSourceNode | null = null;
  private isRolling: boolean = false;

  // Grind sound state
  private grindGain: GainNode | null = null;
  private grindFilter: BiquadFilterNode | null = null;
  private grindNoiseSource: AudioBufferSourceNode | null = null;
  private isGrinding: boolean = false;

  private initContext() {
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      this.ctx = new AudioCtx();
    }
    if (this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  public setMuted(muted: boolean) {
    this.isMuted = muted;
    if (muted && this.ctx) {
      if (this.rollGain) this.rollGain.gain.value = 0;
      if (this.grindGain) this.grindGain.gain.value = 0;
    }
  }

  public getMuted(): boolean {
    return this.isMuted;
  }

  // Create a 1-second looping pinkish noise buffer for physical textures
  private createNoiseBuffer(): AudioBuffer {
    if (!this.ctx) this.initContext();
    const ctx = this.ctx!;
    const bufferSize = ctx.sampleRate * 2;
    const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const output = buffer.getChannelData(0);

    let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      output[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11;
      b6 = white * 0.115926;
    }
    return buffer;
  }

  // Start continuous wheel roll sound
  public updateRollSound(speed: number, isGrounded: boolean) {
    if (this.isMuted) return;
    this.initContext();
    const ctx = this.ctx!;

    if (!isGrounded || speed < 0.2) {
      if (this.rollGain) {
        this.rollGain.gain.setTargetAtTime(0, ctx.currentTime, 0.1);
      }
      return;
    }

    if (!this.isRolling) {
      const noiseBuffer = this.createNoiseBuffer();
      this.rollNoiseSource = ctx.createBufferSource();
      this.rollNoiseSource.buffer = noiseBuffer;
      this.rollNoiseSource.loop = true;

      this.rollFilter = ctx.createBiquadFilter();
      this.rollFilter.type = 'lowpass';
      this.rollFilter.frequency.value = 400;

      this.rollGain = ctx.createGain();
      this.rollGain.gain.value = 0;

      this.rollNoiseSource.connect(this.rollFilter);
      this.rollFilter.connect(this.rollGain);
      this.rollGain.connect(ctx.destination);

      this.rollNoiseSource.start();
      this.isRolling = true;
    }

    if (this.rollGain && this.rollFilter) {
      const targetGain = Math.min(0.25, (speed / 15) * 0.2);
      const targetFreq = Math.min(2200, 300 + (speed / 15) * 1500);
      this.rollGain.gain.setTargetAtTime(targetGain, ctx.currentTime, 0.05);
      this.rollFilter.frequency.setTargetAtTime(targetFreq, ctx.currentTime, 0.05);
    }
  }

  // Push sound (foot kicks ground)
  public playPushSound() {
    if (this.isMuted) return;
    this.initContext();
    const ctx = this.ctx!;

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    const filter = ctx.createBiquadFilter();

    osc.type = 'triangle';
    osc.frequency.setValueAtTime(120, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(45, ctx.currentTime + 0.15);

    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(250, ctx.currentTime);

    gain.gain.setValueAtTime(0.3, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.16);
  }

  // Pop / Bunnyhop sound
  public playPopSound(power: number = 1) {
    if (this.isMuted) return;
    this.initContext();
    const ctx = this.ctx!;

    // Spring clack
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(220, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(550, ctx.currentTime + 0.08);

    const volume = 0.25 * Math.min(1.5, Math.max(0.6, power));
    gain.gain.setValueAtTime(volume, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.12);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.13);
  }

  // Landing impact sound
  public playLandingSound(impactSpeed: number = 5) {
    if (this.isMuted) return;
    this.initContext();
    const ctx = this.ctx!;

    const normalizedImpact = Math.min(1.5, Math.max(0.2, impactSpeed / 8));

    // Thud
    const osc = ctx.createOscillator();
    const oscGain = ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(140, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(30, ctx.currentTime + 0.18);

    oscGain.gain.setValueAtTime(0.4 * normalizedImpact, ctx.currentTime);
    oscGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.2);

    osc.connect(oscGain);
    oscGain.connect(ctx.destination);

    // Deck slap noise
    const noiseBuffer = ctx.createBuffer(1, ctx.sampleRate * 0.1, ctx.sampleRate);
    const data = noiseBuffer.getChannelData(0);
    for (let i = 0; i < data.length; i++) {
      data[i] = (Math.random() * 2 - 1) * Math.exp(-i / (data.length * 0.2));
    }
    const noise = ctx.createBufferSource();
    noise.buffer = noiseBuffer;

    const noiseFilter = ctx.createBiquadFilter();
    noiseFilter.type = 'highpass';
    noiseFilter.frequency.value = 800;

    const noiseGain = ctx.createGain();
    noiseGain.gain.setValueAtTime(0.3 * normalizedImpact, ctx.currentTime);
    noiseGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.1);

    noise.connect(noiseFilter);
    noiseFilter.connect(noiseGain);
    noiseGain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.2);
    noise.start();
  }

  // Continuous grind sound (metal scraping against coping/rail)
  public updateGrindSound(isGrinding: boolean, speed: number) {
    if (this.isMuted) return;
    this.initContext();
    const ctx = this.ctx!;

    if (!isGrinding || speed < 0.5) {
      if (this.grindGain) {
        this.grindGain.gain.setTargetAtTime(0, ctx.currentTime, 0.08);
      }
      this.isGrinding = false;
      return;
    }

    if (!this.isGrinding) {
      const noiseBuffer = this.createNoiseBuffer();
      this.grindNoiseSource = ctx.createBufferSource();
      this.grindNoiseSource.buffer = noiseBuffer;
      this.grindNoiseSource.loop = true;

      // Resonant bandpass for metallic screech
      this.grindFilter = ctx.createBiquadFilter();
      this.grindFilter.type = 'bandpass';
      this.grindFilter.frequency.value = 1800;
      this.grindFilter.Q.value = 4.0;

      this.grindGain = ctx.createGain();
      this.grindGain.gain.value = 0;

      this.grindNoiseSource.connect(this.grindFilter);
      this.grindFilter.connect(this.grindGain);
      this.grindGain.connect(ctx.destination);

      this.grindNoiseSource.start();
      this.isGrinding = true;
    }

    if (this.grindGain && this.grindFilter) {
      const targetGain = Math.min(0.35, 0.15 + (speed / 15) * 0.2);
      const targetFreq = 1600 + Math.sin(ctx.currentTime * 20) * 300 + (speed / 15) * 600;
      this.grindGain.gain.setTargetAtTime(targetGain, ctx.currentTime, 0.04);
      this.grindFilter.frequency.setTargetAtTime(targetFreq, ctx.currentTime, 0.04);
    }
  }

  // Trick caught / landed celebration chime
  public playTrickSuccessSound(comboCount: number = 1) {
    if (this.isMuted) return;
    this.initContext();
    const ctx = this.ctx!;

    // Chime notes pitch up as combo increases
    const baseFreqs = [440, 554.37, 659.25, 880, 1108.73];
    const pitch = baseFreqs[Math.min(baseFreqs.length - 1, comboCount - 1)];

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(pitch, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(pitch * 1.5, ctx.currentTime + 0.18);

    gain.gain.setValueAtTime(0.22, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.35);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.36);
  }

  // Bail crash sound
  public playBailSound() {
    if (this.isMuted) return;
    this.initContext();
    const ctx = this.ctx!;

    // Harsh metal clack
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(320, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(60, ctx.currentTime + 0.3);

    gain.gain.setValueAtTime(0.4, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.35);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.36);
  }
}

export const sound = new SoundEngine();
