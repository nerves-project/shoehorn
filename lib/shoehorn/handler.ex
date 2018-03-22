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

            def handle_application({:exited, {:bad_return, _}}, _, state) do
              {:halt, state}
            end

            def handle_application(:stopped, :non_esential_app, state) do
              {:continue, state}
            end

            def handle_application(:stopped, :esential_app, %{restart_counts: restart_counts} = state) when restart_counts < 2 do
              Application.ensure_all_started(:essential_app)
              {:continue, %{state | restart_counts: restart_counts + 1}}
            end

            def handle_application(:stopped, _, state) do
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
  * `:halt`    - stop the application and bring the system down
  """
  @type action :: :contine | :halt

  @typedoc """
  The cause that is firing the handler

  * `:not_started` - the application failed during init
  * `:stopped` - the application has stopped
  """
  @type cause :: {:bad_return, any} | any

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

  Called with the application name, cause, and the handlers current
  state. It must return a tuple containg the `action` that the
  `Shoehorn.ApplicationController` should take, and the new state
  of the handler.
  """
  @callback application_exited(cause, app :: atom, state :: any) :: {action, state :: any}

  @doc """
  Callback for handling application starts

  Called with the application name, and the handlers current
  state. It must return a tuple containg the `action` that the
  `Shoehorn.ApplicationController` should take, and the new state
  of the handler.
  """
  @callback application_exited(cause, app :: atom, state :: any) :: {action, state :: any}

  defmacro __using__(_opts) do
    quote do
      @behaviour Shoehorn.Handler

      def init(_opts) do
        {:ok, :no_state}
      end
      
      def application_started(_app, state) do
        {:continue, state}
      end

      def application_exited(_app ,_reason, state) do
        {:halt, state}
      end

      defoverridable [init: 1, application_started: 2, application_exited: 3]
    end
  end
  
end
