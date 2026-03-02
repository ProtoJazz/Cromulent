defmodule Cromulent.FeatureFlagsTest do
  use Cromulent.DataCase

  alias Cromulent.FeatureFlags
  alias Cromulent.FeatureFlags.Flags

  describe "get_flags/0" do
    test "returns %Flags{} defaults when no DB row exists" do
      flags = FeatureFlags.get_flags()
      assert %Flags{} = flags
      assert flags.voice_enabled == true
      assert flags.registration_enabled == true
      assert flags.link_previews_enabled == true
      assert flags.email_confirmation_required == false
      assert flags.turn_provider == "disabled"
      assert is_nil(flags.turn_url)
      assert is_nil(flags.turn_secret)
    end

    test "returns nil id when no DB row exists (struct defaults, not persisted)" do
      flags = FeatureFlags.get_flags()
      assert is_nil(flags.id)
    end

    test "calling get_flags/0 twice without upsert returns the same defaults (idempotent)" do
      flags1 = FeatureFlags.get_flags()
      flags2 = FeatureFlags.get_flags()
      assert flags1.voice_enabled == flags2.voice_enabled
      assert flags1.registration_enabled == flags2.registration_enabled
      assert flags1.link_previews_enabled == flags2.link_previews_enabled
      assert flags1.email_confirmation_required == flags2.email_confirmation_required
      assert flags1.turn_provider == flags2.turn_provider
    end

    test "returns the persisted row after upsert" do
      {:ok, _} = FeatureFlags.upsert_flags(%{voice_enabled: false})
      flags = FeatureFlags.get_flags()
      assert flags.voice_enabled == false
      assert not is_nil(flags.id)
    end
  end

  describe "upsert_flags/1" do
    test "persists and returns {:ok, %Flags{voice_enabled: false}} when voice_enabled is false" do
      assert {:ok, %Flags{voice_enabled: false}} = FeatureFlags.upsert_flags(%{voice_enabled: false})
    end

    test "inserts a new row when none exists" do
      {:ok, flags} = FeatureFlags.upsert_flags(%{registration_enabled: false})
      assert flags.registration_enabled == false
      assert not is_nil(flags.id)
    end

    test "updates an existing row when one already exists" do
      {:ok, first} = FeatureFlags.upsert_flags(%{voice_enabled: false})
      {:ok, second} = FeatureFlags.upsert_flags(%{voice_enabled: true})
      assert first.id == second.id
      assert second.voice_enabled == true
    end

    test "returns {:error, changeset} for invalid turn_provider" do
      assert {:error, changeset} = FeatureFlags.upsert_flags(%{turn_provider: "invalid_provider"})
      assert changeset.errors[:turn_provider] != nil
    end

    test "accepts valid turn_provider values: disabled, coturn, metered" do
      assert {:ok, %Flags{turn_provider: "disabled"}} = FeatureFlags.upsert_flags(%{turn_provider: "disabled"})
      assert {:ok, %Flags{turn_provider: "coturn"}} = FeatureFlags.upsert_flags(%{turn_provider: "coturn"})
      assert {:ok, %Flags{turn_provider: "metered"}} = FeatureFlags.upsert_flags(%{turn_provider: "metered"})
    end
  end
end
