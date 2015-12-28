defmodule Wanderer do
  @behaviour :websocket_client
  @wandering_speed 75

  def start_link(opts) do
    url = Dict.get(opts, :url, 'ws://10.0.0.230:4000/socket/websocket?vsn=1.0.0')
    :websocket_client.start_link(url, __MODULE__, [])
  end

  # Callbacks
  def init(_opts) do
    :random.seed(:erlang.timestamp())
    :timer.send_interval(5_000, :heartbeat)
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
    IO.puts "Received: #{msg}"
    msg = Poison.decode!(msg)
    case msg do
      %{"event" => "phx_reply", "ref" => 1, "payload" => %{"status" => "ok"}} ->
        IO.puts "joined the rommba channel, time to wander"
        drive(@wandering_speed, 0)
        {:ok, state}
      %{"event" => "phx_reply", "payload" => %{"status" => "ok"}} ->
        {:ok, state}
      %{"event" => "sensor_update", "payload" => sensors} ->
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

  defp react_to(%{"bumper_left" => 1, "bumper_right" => 1}), do: drive(-100, 0)
  defp react_to(%{"bumper_left" => 1, "bumper_right" => 0}), do: drive(-100, +100)
  defp react_to(%{"bumper_left" => 0, "bumper_right" => 1}), do: drive(-100, -100)
  defp react_to(sensors) do
    cond do
      up_front?(sensors) -> drive(div(@wandering_speed, 2), 50)
      on_the_left?(sensors) -> drive(div(@wandering_speed, 2), -100)
      on_the_right?(sensors) -> drive(div(@wandering_speed, 2), +100)
      true -> drive(@wandering_speed,0)
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
