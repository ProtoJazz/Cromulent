// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import "flowbite/dist/flowbite.phoenix.js";
import VoiceRoom from "./voice"
import "./electron-bridge.js"
import MentionAutocomplete from "./hooks/mention_autocomplete"
import NotificationHandler from "./hooks/notification_handler"

let voiceRoom = null
let voiceSocket = null
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const Hooks = {
  MentionAutocomplete,
  NotificationHandler,
  VoiceRoom: {
    mounted() {
      // This element is always in the DOM, so mounted() fires once on page load.
      // Voice join/leave is driven entirely by server-pushed events.
      this.handleEvent("voice:join", ({ channel_id, user_token, user_id, ice_servers }) => {
        // Leave existing voice session if switching channels
        if (voiceRoom) {
          voiceRoom.leave()
          voiceRoom = null
        }
        if (voiceSocket) {
          voiceSocket.disconnect()
          voiceSocket = null
        }

        console.log("Joining voice channel:", channel_id)

        voiceSocket = new Socket("/socket", { params: { token: user_token } })
        voiceSocket.connect()

        voiceSocket.onOpen(() => console.log("Voice socket connected"))
        voiceSocket.onError((err) => console.error("Voice socket error:", err))
        voiceSocket.onClose(() => console.log("Voice socket closed"))

        voiceRoom = new VoiceRoom(channel_id, user_id, voiceSocket, ice_servers)
        voiceRoom.join()
          .then(() => {
            // Phoenix Channel join succeeded = "connected" (peers connect independently)
            this.pushEvent("voice_state_changed", { state: "connected" })
          })
          .catch((err) => {
            console.error("Failed to join voice channel:", err)
            this.pushEvent("voice_state_changed", { state: "disconnected" })
          })
      })

      this.handleEvent("voice:leave", () => {
        console.log("Leaving voice channel")
        if (voiceRoom) {
          voiceRoom.leave()
          voiceRoom = null
        }
        if (voiceSocket) {
          voiceSocket.disconnect()
          voiceSocket = null
        }
      })
    },
    destroyed() {
      // Only fires on full page reload / logout
      console.log("Destroy voice")
      if (voiceRoom) {
        voiceRoom.leave()
        voiceRoom = null
      }
      if (voiceSocket) {
        voiceSocket.disconnect()
        voiceSocket = null
      }
    }
  },
  ChatScroll: {
  mounted() {
    this.scrollContainer = this.el
    this.scrollBtn = document.getElementById("scroll-to-bottom-btn")
    this.isAtBottom = true
    this.loadingMore = false

    this.scrollToBottom(false)

    this.scrollContainer.addEventListener("scroll", () => {
      const distanceFromBottom =
        this.scrollContainer.scrollHeight -
        this.scrollContainer.scrollTop -
        this.scrollContainer.clientHeight

      this.isAtBottom = distanceFromBottom < 50

      if (this.isAtBottom) {
        this.scrollBtn.classList.add("hidden")
      }

      // Trigger load more when near the top
      if (this.scrollContainer.scrollTop < 100 && !this.loadingMore) {
        this.loadingMore = true
        this.pushEvent("load_more", {}, () => {
          this.loadingMore = false
        })
      }
    })

    this.handleEvent("chat:new_message", () => {
      if (this.isAtBottom) {
        this.scrollToBottom(true)
      } else {
        this.scrollBtn.classList.remove("hidden")
      }
    })

    window.chatScroll = this
  },

  updated() {
    // Only auto-scroll if we're at the bottom (don't jump when prepending old messages)
    if (this.isAtBottom) {
      this.scrollToBottom(false)
    }
  },

  scrollToBottom(smooth) {
    this.scrollContainer.scrollTo({
      top: this.scrollContainer.scrollHeight,
      behavior: smooth ? "smooth" : "instant"
    })
    this.scrollBtn.classList.add("hidden")
    this.isAtBottom = true
  }
}
}

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

