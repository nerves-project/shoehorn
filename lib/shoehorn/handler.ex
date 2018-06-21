defmodule Shoehorn.Handler do
  @moduledoc """
  A behaviour module for implementing handling of failing applications

  A Shoehorn.Handler is a module that knows how to respond to specific
  applications going down. There are two types of failing applications.
  The first is an application that fails to initialize and the second
  is an application that stops while it is running.

  ## Example

  The Shoehorn.Handler behaviour requires developers to implement two
  callbacks.

  The `init` callback sets up any state the handler needs.

  Ther `application_started` callback is called when an application
  starts up.

  The `application_exited` callback processes the incoming failure and
  replies with the reaction that `Shoehorn` should take in case of
  application failure.

          defmodule Example.ShoehornHandler do
            use Shoehorn.Handler

            def init(_opts) do
              {:ok, %{restart_counts: 0}}
            end

            def application_started(app, state) do
              {:continue, state}
            end

            def application_exited(:non_essential_app, _reason,  state) do
              {:continue, state}
            end

            def application_exited(:essential_app, _reason, %{restart_counts: restart_counts} = state) when restart_counts < 2 do
              # repair actions to make before restarting
              Application.ensure_all_started(:essential_app)
              {:continue, %{state | restart_counts: restart_counts + 1}}
            end

            def applicaton_exited(_, state) do
              {:halt, state}
            end
          end

  We initialize our `Shoehorn.Handler` with a restart count for state
  by calling `init` with the configuration options from our shoehorn
  config. The stored state is passed in from the
  `Shoehorn.ApplicationController`.

  When we have an application startup, we will put a message on the
  console to notify the developer.

  When we have a non-essential application fail we return `:continue` to
  inform the system to keep going like nothing happened.

  We restart the essential application of our system two times, and
  then we tell the system to halt if starting over wasn't fixing the
  system.
  """

  @typedoc """
  The reaction letting `Shoehorn.ApplicationController` know what to do

  * `:continue` - keep the system going like nothing happened
  * `:halt`    - stop the application and bring the system down
  """
  @type reaction :: :continue | :halt

  @typedoc """
  The cause that is firing the handler
  """
  @type cause :: any

  @doc """
  Callback to initialize the handle

  The callback must return a tuple of `{:ok, state}`. Where state is
  the initial state of the handler. The system will halt if the
  return is anything other than `:ok`.
  """
  @callback init(opts :: map) :: {:ok, state :: any}

  @doc """
  Callback for handling application crashes

  Called with the application name, cause, and the handler's
  state. It must return a tuple contaning the `reaction` that the
  `Shoehorn.ApplicationController` should take, and the new state
  of the handler.

  The code that you execute here can be used to notify or capture some
  information before halting the system. This information can later
  be used to recreate the issue or debug the problem  causing the
  application to exit.

  Use `application_exited` as a place for a last-ditch effort to fix the
  issue and restart the application.  Ideally, capture
  some information on the system state, and solve it upstream. Shoehorn
  restarts should be used as a splint to keep a critical system
  running.

  The default implementation returns the previous state, and a `:halt`
  reaction.
  """
  @callback application_exited(cause, app :: atom, state :: any) :: {reaction, state :: any}

  @doc """
  Callback for handling application starts

  Called with the application name, and the handler's
  state. It must return a tuple containing the `reaction` that the
  `Shoehorn.ApplicationController` should take, and the new state
  of the handler.

            def application_exited(:essential_app, _reason, state) do
              # repair actions to make before restarting
              # notify someone of the crash and the details
              # log debug data
              Application.ensure_all_started(:essential_app)
              {:continue, %{state | restart_counts: restart_counts + 1}}
            end

  The default implementation returns unchanged state, and a `:continue`
  reaction.
  """
  @callback application_started(app :: atom, state :: any) :: {reaction, state :: any}

  defmacro __using__(_opts) do
    quote do
      @behaviour Shoehorn.Handler

      def init(_opts) do
        {:ok, :no_state}
      end

      def application_started(_app, state) do
        {:continue, state}
      end

      def application_exited(_app, _reason, state) do
        {:halt, state}
      end

      defoverridable init: 1, application_started: 2, application_exited: 3
    end
  end

  @type t :: %__MODULE__{module: atom, state: any}
  @type opts :: [handler: atom]

  defstruct [:module, :state]

  @spec init(opts) :: t | no_return
  def init(opts) do
    module = opts[:handler] || Shoehorn.Handler.Default
    {:ok, state} = module.init(opts)
    %__MODULE__{module: module, state: state}
  end

  @spec invoke(:application_exited, app :: atom, cause, t) :: {reaction, t}
  def invoke(
        :application_exited = event,
        app,
        cause,
        %__MODULE__{state: state, module: module} = handler
      ) do
    {reaction, new_state} = apply(module, event, [app, cause, state])
    {reaction, %{handler | state: new_state}}
  rescue
    e ->
      IO.puts("Shoehorn handler raised an exception: #{inspect(e)}")
      {:halt, state}
  end

  @spec invoke(:application_started, app :: atom, t) :: {reaction, t}
  def invoke(
        :application_started = event,
        app,
        %__MODULE__{state: state, module: module} = handler
      ) do
    {reaction, new_state} = apply(module, event, [app, state])
    {reaction, %{handler | state: new_state}}
  rescue
    e ->
      IO.puts("Shoehorn handler raised an exception: #{inspect(e)}")
      {:continue, state}
  end
end
