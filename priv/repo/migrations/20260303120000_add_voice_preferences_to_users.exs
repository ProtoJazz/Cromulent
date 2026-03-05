defmodule Cromulent.Repo.Migrations.AddVoicePreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :voice_mode, :string, default: "ptt", null: false
      add :vad_threshold, :integer, default: -40, null: false
      add :mic_device_id, :string
      add :speaker_device_id, :string
    end
  end
end
