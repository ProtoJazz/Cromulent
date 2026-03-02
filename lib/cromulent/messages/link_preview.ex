defmodule Cromulent.Messages.LinkPreview do
  @moduledoc """
  Fetches Open Graph metadata for a URL using Finch and Floki.
  Returns an ephemeral preview struct — no database storage.
  """

  @image_extensions ~w(.jpg .jpeg .png .gif .webp .svg)
  @link_regex ~r/https?:\/\/[^\s]+/i
  @timeout 5_000

  @doc """
  Fetches OG metadata for the given URL.
  Returns {:ok, preview_map} or {:error, :fetch_failed}.
  """
  def fetch(url) when is_binary(url) do
    result =
      try do
        Finch.build(:get, url, [{"user-agent", "Cromulent/1.0 LinkPreview"}])
        |> Finch.request(Cromulent.Finch, receive_timeout: @timeout)
      rescue
        _ -> {:error, :fetch_failed}
      end

    with {:ok, %{body: body, status: status}} when status in 200..299 <- result,
         {:ok, document} <- Floki.parse_document(body) do
      {:ok, extract_og(document, url)}
    else
      _ -> {:error, :fetch_failed}
    end
  end

  @doc """
  Extracts the first non-image URL from a message body.
  Returns nil if no eligible URL found.
  Image URLs are excluded because they are already embedded as inline images.
  """
  def extract_first_link(body) when is_binary(body) do
    @link_regex
    |> Regex.scan(body)
    |> List.flatten()
    |> Enum.find(fn url ->
      uri = URI.parse(url)
      extension = uri.path && Path.extname(uri.path) |> String.downcase()
      extension not in @image_extensions
    end)
  end

  # ── Private ──────────────────────────────────────────────────

  defp extract_og(document, fallback_url) do
    meta = fn property ->
      document
      |> Floki.find("meta[property='#{property}'], meta[name='#{property}']")
      |> Floki.attribute("content")
      |> List.first()
    end

    title =
      meta.("og:title") ||
        (document |> Floki.find("title") |> Floki.text() |> blank_to_nil())

    description =
      meta.("og:description") || meta.("description")

    raw_image = meta.("og:image")
    # Security: only allow https:// image URLs in preview cards to prevent XSS via javascript: URIs
    image_url =
      if raw_image && String.starts_with?(raw_image, "https://") do
        raw_image
      else
        nil
      end

    %{
      title: title,
      description: description,
      image_url: image_url,
      url: meta.("og:url") || fallback_url
    }
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(str), do: str
end
