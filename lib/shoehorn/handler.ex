defmodule Shoehorn.Handler do
  @moduledoc """
  A behaviour module for implementing handling of failing applications

  A Shoehorn.Handler is a module that knows how to respond to specific
  applications going down. There are two types of failing applications.
  The first is an application that fails to initialize and the second
  is an application that stops while it is running.

  ## Example

  The Shoehorn.Handler behaviour requires developers to implement two
  callbacks. The `init` callback sets up any state the handler needs.
  The `handle_application` callback processes the incoming failure and
  replies with the action that the `Shoehorn.ApplicationController`
  should take in case of application failure.

          defmodule Example.ShoehornHandler do
            @behaviour Shoehorn.Handler

            def init(_opts) do
              {:ok, %{restart_counts: 0}}
            end

            def handle_application(:not_started, _, state) do
              {:halt, state}
            end

            def handle_application({:stopped, reason}, :non_esential_app, state) do
              {:continue, state}
            end

            def handle_application({:stopped, reason}, :esential_app, %{restart_counts: restart_counts} = state) when restart_counts < 2 do
              {:restart, %{state | restart_counts: restart_counts + 1}}
            end

            def handle_application({:stopped, reason}, _, state) do
              {:halt, state}
            end
          end

  We initailize our `Shoehorn.Handler` with a restart count for state
  by calling `init` with the configuration options from our shoehorn
  config. This state is stored and passed in from the
  `Shoehorn.ApplicationController`.

  The next step is to implement our handlers. When called with
  `:not_started` an application failed in `init` and never started
  running. In our case we are going to inform the controller that
  the system should completely shutdown and there is no saving.

  When we have an app that is non-esential we return `:contiue` to
  inform the system to keep going like nothing happened.

  We restart the esential application of our system two times, and
  then we tell the system to halt if restarting wasn't fixing the
  system.
  """

  @typedoc """
  The action letting `Shoehorn.ApplicationController` know what to do

  * `:contine` - keep the system going like nothing happened
  * `:restart` - restart the application
  * `:halt`    - stop the application and bring the system down
  """
  @type action :: :continue | :restart | :halt

  @typedoc """
  The cause that is firing the handler

  * `:not_started` - the application failed during init
  * `{:stopped, reason}` - the application has stopped with the reason given
  """
  @type cause :: :not_started | {:stopped, any}

  @doc """
  Callback to intialize the handle

  The callback must return a tuple of `{:ok, state}`. The state can be
  anything and will be passed back to `handle_application` any time it
  is called. If anything other than `:ok` is returned the system will
  halt.
  """
  @callback init(opts :: map) :: {:ok, state :: any}

  @doc """
  Callback for handling application crashes

  Called with the cause, application name, and the handlers current
  state. It must return a tuple containg the `action` that the
  `Shoehorn.ApplicationController` should take, and the new state
  of the handler.
  """
  @callback handle_application(cause, app :: atom, state :: any) :: {action, state :: any}

  def init(_opts) do
    {:ok, :no_state}
  end

  def handle_application(_reason, _app, state) do
    {:halt, state}
  end
end
