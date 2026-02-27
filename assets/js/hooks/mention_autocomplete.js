const MentionAutocomplete = {
  mounted() {
    // Find the input element
    this.input = this.el.querySelector('input[name="body"]')
    if (!this.input) {
      console.error("MentionAutocomplete: Could not find input[name='body']")
      return
    }

    // Initialize state
    this.autocompleteOpen = false
    this.mentionStartPos = null

    // Add event listeners
    this.input.addEventListener("input", (e) => this.handleInput(e))
    this.input.addEventListener("keydown", (e) => this.handleKeydown(e))

    // Register server event handler for mention selection
    this.handleEvent("mention_selected", ({ text }) => this.insertMention(text))
  },

  handleInput(e) {
    // Get cursor position
    const cursorPos = this.input.selectionStart

    // Get text before cursor
    const textBefore = this.input.value.slice(0, cursorPos)

    // Match @ trigger (@ followed by zero or more word characters)
    const match = textBefore.match(/@(\w*)$/)

    if (match) {
      // Found @ trigger
      this.mentionStartPos = cursorPos - match[0].length // position of the @ character
      this.autocompleteOpen = true
      this.pushEvent("autocomplete_open", { query: match[1] }) // match[1] is text after @
    } else if (this.autocompleteOpen) {
      // No match found but autocomplete is open - close it
      this.autocompleteOpen = false
      this.pushEvent("autocomplete_close", {})
    }
  },

  handleKeydown(e) {
    // If autocomplete is not open, don't intercept normal typing
    if (!this.autocompleteOpen) {
      return
    }

    // Handle keys when autocomplete is open
    switch (e.key) {
      case "ArrowDown":
        e.preventDefault()
        this.pushEvent("autocomplete_navigate", { direction: "down" })
        break

      case "ArrowUp":
        e.preventDefault()
        this.pushEvent("autocomplete_navigate", { direction: "up" })
        break

      case "Enter":
        // CRITICAL: Prevent form submission when selecting a mention
        e.preventDefault()
        e.stopPropagation()

        // Read selected index from data attribute
        const selectedIndex = this.el.dataset.selectedIndex
        if (selectedIndex !== undefined && selectedIndex !== null) {
          this.pushEvent("autocomplete_select", { index: parseInt(selectedIndex) })
        }
        break

      case "Tab":
        // Tab also selects current item (Discord/Slack behavior)
        e.preventDefault()
        const tabSelectedIndex = this.el.dataset.selectedIndex
        if (tabSelectedIndex !== undefined && tabSelectedIndex !== null) {
          this.pushEvent("autocomplete_select", { index: parseInt(tabSelectedIndex) })
        }
        break

      case "Escape":
        e.preventDefault()
        this.autocompleteOpen = false
        this.pushEvent("autocomplete_close", {})
        break
    }
  },

  insertMention(text) {
    // Get current value
    const value = this.input.value

    // Get text before the @ trigger
    const before = value.slice(0, this.mentionStartPos)

    // Get text after current cursor
    const after = value.slice(this.input.selectionStart)

    // Build new value
    const newValue = before + text + after

    // Set input value
    this.input.value = newValue

    // Calculate new cursor position (after the inserted mention)
    const newPos = this.mentionStartPos + text.length

    // Set cursor
    this.input.selectionStart = newPos
    this.input.selectionEnd = newPos

    // Reset state
    this.autocompleteOpen = false
    this.mentionStartPos = null

    // Focus input to ensure it retains focus after mention insertion
    this.input.focus()

    // Dispatch input event so LiveView picks up the value change
    this.input.dispatchEvent(new Event("input", { bubbles: true }))
  },

  updated() {
    // Re-acquire input reference in case LiveView replaced the DOM element
    const currentInput = this.el.querySelector('input[name="body"]')
    if (currentInput && currentInput !== this.input) {
      this.input = currentInput
      this.input.addEventListener("input", (e) => this.handleInput(e))
      this.input.addEventListener("keydown", (e) => this.handleKeydown(e))
    }

    // Sync autocomplete open state with DOM
    const dropdown = this.el.querySelector('[role="listbox"]')
    if (!dropdown && this.autocompleteOpen) {
      this.autocompleteOpen = false
    }

    // Update ARIA activedescendant attribute for accessibility
    if (this.autocompleteOpen && this.el.dataset.selectedIndex !== undefined) {
      this.input.setAttribute(
        "aria-activedescendant",
        "mention-option-" + this.el.dataset.selectedIndex
      )
    } else if (this.input) {
      this.input.removeAttribute("aria-activedescendant")
    }
  },

  destroyed() {
    // Event listeners on child elements will be cleaned up automatically
    // when the DOM is destroyed, so no explicit cleanup needed
  }
}

export default MentionAutocomplete
