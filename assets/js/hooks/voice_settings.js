const VoiceSettings = {
  mounted() {
    this.micStream = null
    this.micAudioCtx = null
    this.micAnimFrame = null
    this.testActive = false

    // Live label update as slider moves
    const slider = this.el.querySelector('input[name="vad_threshold"]')
    const label = this.el.querySelector('#vad-threshold-label')
    if (slider && label) {
      slider.addEventListener('input', () => {
        label.textContent = `Current: ${slider.value} dBFS`
      })
    }

    const testBtn = document.getElementById("test-mic-btn")
    const levelBar = document.getElementById("mic-level-bar")
    const levelFill = document.getElementById("mic-level-fill")
    const levelLabel = document.getElementById("mic-level-label")

    testBtn?.addEventListener("click", async () => {
      if (this.testActive) {
        // Stop test
        this.stopMicTest()
        testBtn.textContent = "Test Mic"
        levelBar?.classList.add("hidden")
        levelLabel?.classList.add("hidden")
        return
      }

      try {
        // Must call getUserMedia before enumerateDevices for device labels
        this.micStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false })

        // Enumerate devices now that we have permission
        const devices = await navigator.mediaDevices.enumerateDevices()
        const audioInputs = devices
          .filter(d => d.kind === "audioinput")
          .map(d => ({ id: d.deviceId, label: d.label || `Microphone ${d.deviceId.slice(0, 8)}` }))
        const audioOutputs = devices
          .filter(d => d.kind === "audiooutput")
          .map(d => ({ id: d.deviceId, label: d.label || `Speaker ${d.deviceId.slice(0, 8)}` }))

        this.pushEvent("devices_loaded", { inputs: audioInputs, outputs: audioOutputs })

        // Start mic level visualizer
        this.micAudioCtx = new AudioContext()
        const source = this.micAudioCtx.createMediaStreamSource(this.micStream)
        const analyser = this.micAudioCtx.createAnalyser()
        analyser.fftSize = 1024
        source.connect(analyser)

        const buffer = new Float32Array(analyser.fftSize)
        this.testActive = true
        testBtn.textContent = "Stop Test"
        levelBar?.classList.remove("hidden")
        levelLabel?.classList.remove("hidden")

        const tick = () => {
          if (!this.testActive) return
          analyser.getFloatTimeDomainData(buffer)
          const rms = Math.sqrt(buffer.reduce((s, v) => s + v * v, 0) / buffer.length)
          const dBFS = 20 * Math.log10(rms || 0.000001)
          // Map -60 dBFS (silent) to 0%, -20 dBFS (loud) to 100%
          const pct = Math.min(100, Math.max(0, ((dBFS + 60) / 40) * 100))
          if (levelFill) levelFill.style.width = `${pct}%`
          this.micAnimFrame = requestAnimationFrame(tick)
        }
        requestAnimationFrame(tick)
      } catch (err) {
        console.error("Mic test failed:", err)
        testBtn.textContent = "Test Mic (access denied)"
      }
    })
  },

  stopMicTest() {
    this.testActive = false
    if (this.micAnimFrame) cancelAnimationFrame(this.micAnimFrame)
    if (this.micAudioCtx) {
      this.micAudioCtx.close()
      this.micAudioCtx = null
    }
    if (this.micStream) {
      this.micStream.getTracks().forEach(t => t.stop())
      this.micStream = null
    }
  },

  destroyed() {
    this.stopMicTest()
  }
}

export default VoiceSettings
