defmodule CromulentWeb.Components.MessageComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias CromulentWeb.Components.MessageComponent

  # Helper to build a minimal message map for rendering
  defp build_message(body, opts \\ []) do
    user = %{
      id: opts[:user_id] || 1,
      username: opts[:username] || "alice",
      role: :member
    }

    %{
      id: 1,
      body: body,
      user: user,
      mentions: opts[:mentions] || [],
      inserted_at: ~N[2024-01-01 12:00:00]
    }
  end

  defp render_message(body, opts \\ []) do
    message = build_message(body, Keyword.take(opts, [:user_id, :username, :mentions]))
    current_user = %{
      id: opts[:current_user_id] || 2,
      username: opts[:current_username] || "bob",
      role: :member
    }

    assigns = %{message: message, current_user: current_user, __changed__: nil}

    rendered_to_string(
      Phoenix.LiveView.TagEngine.component(
        &MessageComponent.message/1,
        assigns,
        {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
      )
    )
  end

  # ── plain text and markdown behavior ──────────────────────────────────────

  describe "markdown rendering" do
    test "plain text renders as paragraph content" do
      html = render_message("hello")
      assert html =~ "hello"
    end

    test "bold text renders as <strong> tag" do
      html = render_message("**bold**")
      assert html =~ "<strong>bold</strong>"
    end

    test "italic text renders as <em> tag" do
      html = render_message("_italic_")
      assert html =~ "<em>italic</em>"
    end

    test "inline code renders as <code> tag" do
      html = render_message("`code`")
      assert html =~ "<code>code</code>"
    end

    test "bare URL renders as anchor tag via autolink" do
      html = render_message("Visit https://example.com for more")
      assert html =~ ~s(href="https://example.com")
    end
  end

  # ── image URL detection ────────────────────────────────────────────────────

  describe "image URL detection" do
    test "png image URL renders as <img> tag" do
      html = render_message("https://example.com/photo.png")
      assert html =~ ~s(src="https://example.com/photo.png")
      assert html =~ "<img"
    end

    test "jpg image URL renders as <img> tag" do
      html = render_message("https://example.com/photo.jpg")
      assert html =~ ~s(src="https://example.com/photo.jpg")
      assert html =~ "<img"
    end

    test "jpeg image URL renders as <img> tag" do
      html = render_message("https://example.com/photo.jpeg")
      assert html =~ ~s(src="https://example.com/photo.jpeg")
    end

    test "gif image URL renders as <img> tag" do
      html = render_message("https://example.com/anim.gif")
      assert html =~ ~s(src="https://example.com/anim.gif")
    end

    test "webp image URL renders as <img> tag" do
      html = render_message("https://example.com/photo.webp")
      assert html =~ ~s(src="https://example.com/photo.webp")
    end

    test "svg image URL renders as <img> tag" do
      html = render_message("https://example.com/icon.svg")
      assert html =~ ~s(src="https://example.com/icon.svg")
    end

    test "image has broken-image fallback div" do
      html = render_message("https://example.com/photo.png")
      assert html =~ "Image unavailable"
    end

    test "image URL does not render as duplicate anchor from MDEx" do
      html = render_message("https://example.com/photo.png")
      # The image URL must NOT also be wrapped in an <a> tag from MDEx
      refute html =~ ~s(href="https://example.com/photo.png")
    end
  end

  # ── mention rendering ──────────────────────────────────────────────────────

  describe "mention rendering" do
    test "mention renders as pill span" do
      html = render_message("@alice hello")
      assert html =~ "@alice"
      assert html =~ "inline-flex"
    end

    test "mention pill has expected styling class" do
      html = render_message("@alice hello")
      assert html =~ "rounded"
    end
  end

  # ── mixed content ──────────────────────────────────────────────────────────

  describe "mixed content" do
    test "image URL alongside mention renders both" do
      html = render_message("see https://example.com/photo.jpg and @alice")
      assert html =~ "<img"
      assert html =~ "@alice"
    end

    test "bold text alongside mention renders both" do
      html = render_message("@alice **hello**")
      assert html =~ "@alice"
      assert html =~ "<strong>hello</strong>"
    end

    test "markdown text segment does not also become an image" do
      html = render_message("Visit https://example.com for more")
      refute html =~ "<img"
    end
  end

  # ── XSS safety ────────────────────────────────────────────────────────────

  describe "XSS safety" do
    test "script tags are stripped from message body" do
      html = render_message("<script>alert(1)</script>")
      refute html =~ "<script"
    end
  end
end
