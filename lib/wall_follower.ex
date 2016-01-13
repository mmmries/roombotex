defmodule WallFollower do
  @behaviour :websocket_client
  @speed 150
  @backup_speed -50
  @inplace_turn 5
  @tight_turn 25
  @loose_turn 60
  @left 1
  @right -1

  def start_link(opts) do
    url = Dict.get(opts, :url, 'ws://10.0.0.230:4000/socket/websocket?vsn=1.0.0')
    :websocket_client.start_link(url, __MODULE__, [])
  end

  # Callbacks
  def init(_opts) do
    :random.seed(:erlang.timestamp())
    :timer.send_interval(1_000, :heartbeat)
    {:once, %{sensors: %{}}}
  end

  def onconnect(_wsreq, state) do
    IO.puts "connected!"
    send_join_request
    {:ok, state}
  end

 def ondisconnect(reason, state) do
    IO.puts "disconnected because #{inspect reason}"
    {:reconnect, state}
  end

  def websocket_handle({:text, msg}, _conn, state) do
    msg = Poison.decode!(msg)
    case msg do
      %{"event" => "phx_reply", "ref" => 1, "payload" => %{"status" => "ok"}} ->
        IO.puts "joined the rommba channel, time to get through the maze"
        {:ok, state}
      %{"event" => "phx_reply", "payload" => %{"status" => "ok"}} ->
        {:ok, state}
      %{"event" => "sensor_update", "payload" => sensors} ->
        IO.puts "sensor update #{inspect sensors}"
        react_to(sensors)
        {:ok, Map.put(state, "sensors", sensors)}
      _ ->
        IO.puts("WAT?")
        {:ok, state}
    end
  end

  def websocket_info({:send, msg}, _connstate, state) do
    msg = Poison.encode!(msg)
    IO.puts "sending: #{msg}"
    {:reply, {:text, msg}, state}
  end
  def websocket_info(:heartbeat, _connstate, state) do
    msg = %{topic: :phoenix, event: :heartbeat, ref: 3, payload: %{}}
    {:reply, {:text, Poison.encode!(msg)}, state}
  end

  def websocket_terminate(reason, _connstate, state) do
    IO.puts "Websocket closed #{inspect reason}"
    IO.inspect state
    :ok
  end

  # Private Methods
  defp drive(velocity, radius) do
    send self, {:send, %{topic: :roomba, event: :drive, ref: 2, payload: %{velocity: velocity, radius: radius}}}
  end

  defp on_the_left?(%{"light_bumper_left" => 1}), do: true
  defp on_the_left?(%{"light_bumper_left_front" => 1}), do: true
  defp on_the_left?(_), do: false

  defp on_the_right?(%{"light_bumper_right" => 1}), do: true
  defp on_the_right?(%{"light_bumper_right_front" => 1}), do: true
  defp on_the_right?(_), do: false

  defp react_to(%{"bumper_left" => 1, "bumper_right" => 1}), do: drive(@backup_speed, 0)
  defp react_to(%{"bumper_left" => 1, "bumper_right" => 0}), do: drive(@backup_speed, @tight_turn * @right)
  defp react_to(%{"bumper_left" => 0, "bumper_right" => 1}), do: drive(@backup_speed, @tight_turn * @left)
  defp react_to(sensors) do
    cond do
      up_front?(sensors) -> drive(div(@speed, 3), @tight_turn * @right)
      on_the_left?(sensors) -> drive(div(@speed, 2), @loose_turn * @right)
      on_the_right?(sensors) -> drive(div(@speed, 2), @loose_turn * @left)
      true -> drive(0,0)
    end
  end

  defp send_join_request() do
    msg = %{topic: "roomba", event: "phx_join", ref: 1, payload: %{}}
    send self, {:send, msg}
  end

  defp up_front?(%{"light_bumper_left_center" => 1}), do: true
  defp up_front?(%{"light_bumper_right_center" => 1}), do: true
  defp up_front?(_), do: false
end
