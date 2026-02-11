const ICE_SERVERS = {
  iceServers: [
    { urls: "stun:stun.l.google.com:19302" },
    // Add your TURN server here when testing across networks:
    // {
    //   urls: "turn:your-turn-server.com:3478",
    //   username: "user",
    //   credential: "pass"
    // }
  ]
}

class VoiceRoom {
  constructor(channelId, userId, socket) {
    this.channelId = channelId
    this.userId = String(userId)
    this.peers = {}
    this.channel = null
    this.localStream = null

    this.channel = socket.channel(`voice:${channelId}`)
    this.bindChannelEvents()
  }

enablePTT(key = ' ') {
  this.pttKey = key
  this.pttActive = false

  // Start muted
  this.localStream.getTracks().forEach(t => t.enabled = false)

  const activate = () => {
    if (this.pttActive) return
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
  const btn = document.getElementById("ptt-button")
  if (btn) {
    btn.addEventListener("pointerdown", (e) => { e.preventDefault(); activate() })
    btn.addEventListener("pointerup", deactivate)
    btn.addEventListener("pointerleave", deactivate)  // finger slides off button
    btn.addEventListener("pointercancel", deactivate)
  }

  // Keyboard
  this._onKeyDown = (e) => {
    if (e.key === this.pttKey && !e.repeat) activate()
  }
  this._onKeyUp = (e) => {
    if (e.key === this.pttKey) deactivate()
  }

  window.addEventListener("keydown", this._onKeyDown)
  window.addEventListener("keyup", this._onKeyUp)
}
  async join() {
   this.localStream = await navigator.mediaDevices.getUserMedia({
    audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        sampleRate: 48000
    }
    })
        console.log("🎤 Got local stream", this.localStream.getTracks())

    this.channel.join()
       .receive("ok", () => {
      console.log("✅ Joined voice channel")
      this.enablePTT(' ')  // spacebar
    })
      .receive("error", (err) => console.error("❌ Failed to join:", err))
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

    const peer = new RTCPeerConnection(ICE_SERVERS)
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
      window.removeEventListener("keydown", this._onKeyDown)
  window.removeEventListener("keyup", this._onKeyUp)
    Object.keys(this.peers).forEach(id => this.removePeer(id))
    this.localStream?.getTracks().forEach(t => t.stop())
    this.channel.leave()
  }
}

export default VoiceRoom