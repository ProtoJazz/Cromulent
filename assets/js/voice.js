class VoiceRoom {
  constructor(channelId, userId, socket, iceServers) {
    this.channelId = channelId
    this.userId = String(userId)
    this.peers = {}
    this.channel = null
    this.localStream = null
    // Use dynamic ICE servers from server; fall back to STUN-only if not provided
    this.iceServers = iceServers || [{ urls: "stun:stun.l.google.com:19302" }]

    // VAD state
    this.vadActive = false
    this.vadAudioCtx = null
    this.vadAnimFrame = null

    // Mute/deafen state
    this.muted = false
    this.deafened = false

    this.channel = socket.channel(`voice:${channelId}`)
    this.bindChannelEvents()
  }

enablePTT(key = ' ') {
  console.log("DEBUG: window.electronAPI =", window.electronAPI)

  this.pttKey = key
  this.pttActive = false

  // Start muted
  this.localStream.getTracks().forEach(t => t.enabled = false)

  const btn = document.getElementById("ptt-button")

  const activate = () => {
    if (this.pttActive) return
    if (this.muted) return  // mute blocks PTT
    this.pttActive = true
    this.localStream.getTracks().forEach(t => t.enabled = true)
    this.channel.push("ptt_state", { active: true })
    btn?.setAttribute("data-active", "true")
    btn?.classList.replace("bg-gray-600", "bg-green-500")
    btn.textContent = "🎙️ Talking..."
    console.log("🎙️ PTT on")
  }

  const deactivate = () => {
    if (!this.pttActive) return
    this.pttActive = false
    this.localStream.getTracks().forEach(t => t.enabled = false)
    this.channel.push("ptt_state", { active: false })
    btn?.setAttribute("data-active", "false")
    btn?.classList.replace("bg-green-500", "bg-gray-600")
    btn.textContent = "🎙️ Hold to Talk"
    console.log("🎙️ PTT off")
  }

  // Button — pointer events so it works on mobile and desktop
  if (btn) {
    btn.addEventListener("pointerdown", (e) => { e.preventDefault(); activate() })
    btn.addEventListener("pointerup", deactivate)
    btn.addEventListener("pointerleave", deactivate)
    btn.addEventListener("pointercancel", deactivate)
  }

  // Check if running in Electron
  if (window.electronAPI && window.electronAPI.onPTTState) {
    console.log("🎮 Using Electron PTT backend")
    
    // Listen to Electron PTT events
    window.electronAPI.onPTTState((isPressed) => {
      if (isPressed) {
        activate()
      } else {
        deactivate()
      }
    })

    // Listen for PTT errors
    window.electronAPI.onPTTError((message) => {
      console.error("PTT Error:", message)
      // Optionally show error to user
    })
  } else {
    // Fallback to keyboard events for web browser
    console.log("🌐 Using browser keyboard PTT")
    
    this._onKeyDown = (e) => {
      if (e.key === this.pttKey && !e.repeat) activate()
    }
    this._onKeyUp = (e) => {
      if (e.key === this.pttKey) deactivate()
    }

    window.addEventListener("keydown", this._onKeyDown)
    window.addEventListener("keyup", this._onKeyUp)
  }
}
  enableVAD(threshold = -40) {
    this.vadActive = true
    this.vadAudioCtx = new AudioContext()

    // Clone the audio track for the analyser. Per spec, a disabled MediaStreamTrack
    // produces silence in Web Audio API too — so we need an always-enabled clone
    // purely for level detection, while the original track controls transmission.
    const audioTracks = this.localStream.getAudioTracks()
    this.vadAnalyserStream = audioTracks.length > 0
      ? new MediaStream([audioTracks[0].clone()])
      : this.localStream

    const source = this.vadAudioCtx.createMediaStreamSource(this.vadAnalyserStream)
    const analyser = this.vadAudioCtx.createAnalyser()

    // Now disable the original tracks — analyser clone is unaffected
    if (this.localStream) {
      this.localStream.getTracks().forEach(t => t.enabled = false)
    }
    analyser.fftSize = 1024
    source.connect(analyser)

    const buffer = new Float32Array(analyser.fftSize)
    let speaking = false

    const tick = () => {
      if (!this.vadActive) return
      analyser.getFloatTimeDomainData(buffer)
      const rms = Math.sqrt(buffer.reduce((s, v) => s + v * v, 0) / buffer.length)
      const dBFS = 20 * Math.log10(rms || 0.000001)

      if (dBFS > threshold && !speaking) {
        speaking = true
        if (this.localStream && !this.muted) {
          this.localStream.getTracks().forEach(t => t.enabled = true)
        }
        this.channel.push("ptt_state", { active: true })
        console.log("VAD: speech detected", dBFS.toFixed(1), "dBFS")
      } else if (dBFS <= threshold && speaking) {
        speaking = false
        if (this.localStream) {
          this.localStream.getTracks().forEach(t => t.enabled = false)
        }
        this.channel.push("ptt_state", { active: false })
        console.log("VAD: silence detected", dBFS.toFixed(1), "dBFS")
      }

      this.vadAnimFrame = requestAnimationFrame(tick)
    }

    // Ensure AudioContext is running — may be suspended due to autoplay policy
    // (enableVAD is called from an async callback, not a direct user gesture)
    this.vadAudioCtx.resume().then(() => {
      this.vadAnimFrame = requestAnimationFrame(tick)
    })
    console.log("VAD enabled, threshold:", threshold, "dBFS")
  }

  setMute(muted) {
    this.muted = muted
    if (this.localStream) {
      this.localStream.getTracks().forEach(t => t.enabled = !muted)
    }
    // If currently PTT-active and now muting, deactivate PTT
    if (muted && this.pttActive) {
      this.pttActive = false
      this.channel.push("ptt_state", { active: false })
      const btn = document.getElementById("ptt-button")
      btn?.setAttribute("data-active", "false")
      btn?.classList.replace("bg-green-500", "bg-gray-600")
      if (btn) btn.textContent = "Push to Talk"
    }
    // Push mute state to channel so Presence meta updates
    this.channel.push("toggle_mute", { muted: muted })
  }

  setDeafen(deafened, muted) {
    this.deafened = deafened
    // Mute all remote audio elements
    document.querySelectorAll('audio[id^="audio-"]').forEach(a => {
      a.muted = deafened
    })
    // Apply mic mute (deafen auto-mutes; undeafen does NOT auto-unmute)
    this.setMute(muted)
    // Push deafen state to channel so Presence meta updates
    this.channel.push("toggle_deafen", { deafened: deafened })
  }

  async join(voiceMode = "ptt", vadThreshold = -40, micDeviceId = null, speakerDeviceId = null) {
    this.speakerDeviceId = speakerDeviceId

    // Use saved mic device if available, fall back gracefully on OverconstrainedError
    let audioConstraints = {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      sampleRate: 48000
    }
    if (micDeviceId) {
      audioConstraints.deviceId = { exact: micDeviceId }
    }

    try {
      this.localStream = await navigator.mediaDevices.getUserMedia({ audio: audioConstraints })
    } catch (err) {
      if (err.name === "OverconstrainedError" || err.name === "NotFoundError") {
        console.warn("Saved mic device not found, falling back to default mic")
        delete audioConstraints.deviceId
        this.localStream = await navigator.mediaDevices.getUserMedia({ audio: audioConstraints })
      } else {
        throw err
      }
    }

    console.log("Got local stream", this.localStream.getTracks())

    return new Promise((resolve, reject) => {
      this.channel.join()
        .receive("ok", () => {
          console.log("Joined voice channel")
          if (voiceMode === "vad") {
            this.enableVAD(vadThreshold)
          } else {
            this.enablePTT(" ")
          }
          resolve()
        })
        .receive("error", (err) => {
          console.error("Failed to join:", err)
          reject(err)
        })
    })
  }

  bindChannelEvents() {
    this.channel.on("peer_joined", ({ user_id }) => {
      const peerId = String(user_id)
      console.log("👤 Peer joined:", peerId, "| us:", this.userId)
      if (peerId !== this.userId) {
        console.log("📞 Initiating offer to", peerId)
        this.createPeer(peerId, true)
      }
    })

    this.channel.on("peer_left", ({ user_id }) => {
      const peerId = String(user_id)
      console.log("👋 Peer left:", peerId)
      this.removePeer(peerId)
    })

    this.channel.on("sdp_offer", ({ from, to, sdp }) => {
      const fromId = String(from)
      const toId = String(to)
      console.log("📨 SDP offer from", fromId, "to", toId, "| us:", this.userId)
      if (toId === this.userId) this.handleOffer(fromId, sdp)
    })

    this.channel.on("sdp_answer", ({ from, to, sdp }) => {
      const fromId = String(from)
      const toId = String(to)
      console.log("📨 SDP answer from", fromId, "to", toId)
      if (toId === this.userId) {
        const peer = this.peers[fromId]
        if (peer) peer.setRemoteDescription(new RTCSessionDescription(sdp))
      }
    })

    this.channel.on("ice_candidate", ({ from, to, candidate }) => {
      const fromId = String(from)
      const toId = String(to)
      console.log("🧊 ICE candidate from", fromId)
      if (toId === this.userId) {
        const peer = this.peers[fromId]
        if (peer) peer.addIceCandidate(new RTCIceCandidate(candidate))
      }
    })
  }

  createPeer(remoteUserId, isOfferer) {
    const id = String(remoteUserId)
    console.log("🔗 Creating peer connection to", id, isOfferer ? "(offerer)" : "(answerer)")

    const peer = new RTCPeerConnection({ iceServers: this.iceServers })
    this.peers[id] = peer

    this.localStream.getTracks().forEach(track => {
      console.log("🎵 Adding track to peer", id)
      peer.addTrack(track, this.localStream)
    })
    peer.getTransceivers().forEach(transceiver => {
    if (transceiver.kind === 'audio') {
      const { codecs } = RTCRtpSender.getCapabilities('audio')
      const opusCodecs = codecs.filter(c => c.mimeType === 'audio/opus')
      const otherCodecs = codecs.filter(c => c.mimeType !== 'audio/opus')
      transceiver.setCodecPreferences([...opusCodecs, ...otherCodecs])
    }
  })


    peer.ontrack = (event) => {
      console.log("🔊 Got remote track from", id)
      this.playRemoteAudio(id, event.streams[0])
    }

    peer.onicecandidate = (event) => {
      if (event.candidate) {
        console.log("🧊 Sending ICE candidate to", id)
        this.channel.push("ice_candidate", { to: id, candidate: event.candidate })
      }
    }

    peer.onconnectionstatechange = () => {
      console.log(`🔌 Peer ${id} state: ${peer.connectionState}`)
    }

    peer.onsignalingstatechange = () => {
      console.log(`📡 Peer ${id} signaling state: ${peer.signalingState}`)
    }

    if (isOfferer) {
      peer.createOffer()
        .then(offer => {
          console.log("📤 Sending SDP offer to", id)
          offer.sdp = offer.sdp.replace(
        'useinbandfec=1',
        'useinbandfec=1;maxaveragebitrate=128000'
      )
          return peer.setLocalDescription(offer)
        })
        .then(() => {
          this.channel.push("sdp_offer", { to: id, sdp: peer.localDescription })
        })
        .catch(err => console.error("💥 createOffer failed:", err))
    }

    return peer
  }

  async handleOffer(remoteUserId, sdp) {
    const id = String(remoteUserId)
    try {
      console.log("🤝 Handling offer from", id)
      const peer = this.createPeer(id, false)

      await peer.setRemoteDescription(new RTCSessionDescription(sdp))
      console.log("✅ Set remote description")

      const answer = await peer.createAnswer()
      console.log("✅ Created answer")

      await peer.setLocalDescription(answer)
      console.log("✅ Set local description")

      this.channel.push("sdp_answer", { to: id, sdp: peer.localDescription })
      console.log("📤 Sent answer to", id)
    } catch (err) {
      console.error("💥 handleOffer failed:", err)
    }
  }

  playRemoteAudio(userId, stream) {
    const id = String(userId)
    const existing = document.getElementById(`audio-${id}`)
    if (existing) existing.remove()

    const audio = document.createElement("audio")
    audio.id = `audio-${id}`
    audio.srcObject = stream
    audio.autoplay = true

    // Speaker device selection (Chromium/Electron only)
    if (this.speakerDeviceId && typeof audio.setSinkId !== "undefined") {
      audio.setSinkId(this.speakerDeviceId).catch(err => {
        console.warn("setSinkId failed:", err)
      })
    }

    document.body.appendChild(audio)
  }

  removePeer(userId) {
    const id = String(userId)
    const peer = this.peers[id]
    if (peer) {
      peer.close()
      delete this.peers[id]
    }
    const audio = document.getElementById(`audio-${id}`)
    if (audio) audio.remove()
  }

  leave() {
    // Stop VAD if active
    this.vadActive = false
    if (this.vadAnimFrame) cancelAnimationFrame(this.vadAnimFrame)
    if (this.vadAudioCtx) {
      this.vadAudioCtx.close()
      this.vadAudioCtx = null
    }
    if (this.vadAnalyserStream) {
      this.vadAnalyserStream.getTracks().forEach(t => t.stop())
      this.vadAnalyserStream = null
    }

    // Reset mute/deafen state on leave
    this.muted = false
    this.deafened = false
    document.querySelectorAll('audio[id^="audio-"]').forEach(a => {
      a.muted = false
    })

    // Only remove keyboard listeners if we added them (not using Electron)
    if (this._onKeyDown && this._onKeyUp) {
      window.removeEventListener("keydown", this._onKeyDown)
      window.removeEventListener("keyup", this._onKeyUp)
    }

    Object.keys(this.peers).forEach(id => this.removePeer(id))
    this.localStream?.getTracks().forEach(t => t.stop())
    this.channel.leave()
  }
}

export default VoiceRoom