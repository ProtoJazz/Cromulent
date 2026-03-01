defmodule Cromulent.Turn.Provider do
  @moduledoc """
  Behaviour for TURN server credential providers.
  Implementations return an iceServers array for RTCPeerConnection.
  """

  @callback get_ice_servers(user_id :: integer()) ::
              {:ok, list(map())} | {:error, term()}
end
