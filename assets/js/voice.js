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

  async join() {
    this.localStream = await navigator.mediaDevices.getUserMedia({ audio: true })
    console.log("🎤 Got local stream", this.localStream.getTracks())

    this.channel.join()
      .receive("ok", () => console.log("✅ Joined voice channel"))
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
    Object.keys(this.peers).forEach(id => this.removePeer(id))
    this.localStream?.getTracks().forEach(t => t.stop())
    this.channel.leave()
  }
}

export default VoiceRoom