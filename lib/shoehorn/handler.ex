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
  replies with the action that `Shoehorn` should take in case of
  application failure.

          defmodule Example.ShoehornHandler do
            use Shoehorn.Handler

            def init(_opts) do
              {:ok, %{restart_counts: 0}}
            end

            def application_started(app, state) do
              IO.inspect app
              {:continue, state}
            end

            def application_exited(:non_esential_app, _reason,  state) do
              {:continue, state}
            end

            def application_exited(:esential_app, _reason, %{restart_counts: restart_counts} = state) when restart_counts < 2 do
              Application.ensure_all_started(:essential_app)
              {:continue, %{state | restart_counts: restart_counts + 1}}
            end

            def applicaton_exited(_, state) do
              {:halt, state}
            end
          end

  We initialize our `Shoehorn.Handler` with a restart count for state
  by calling `init` with the configuration options from our shoehorn
  config. This state is stored and passed in from the
  `Shoehorn.ApplicationController`.

  When we have an application start up we will put a message in the
  console to notify the developer.

  When we have an non-esential application fail we return `:continue` to
  inform the system to keep going like nothing happened.

  We restart the esential application of our system two times, and
  then we tell the system to halt if restarting wasn't fixing the
  system.
  """

  @typedoc """
  The action letting `Shoehorn.ApplicationController` know what to do

  * `:continue` - keep the system going like nothing happened
  * `:halt`    - stop the application and bring the system down
  """
  @type action :: :continue | :halt

  @typedoc """
  The cause that is firing the handler
  """
  @type cause :: any

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

  The default implementation returns unchanged state, and a `:halt`
  action.
  """
  @callback application_exited(cause, app :: atom, state :: any) :: {action, state :: any}

  @doc """
  Callback for handling application starts

  Called with the application name, and the handlers current
  state. It must return a tuple containg the `action` that the
  `Shoehorn.ApplicationController` should take, and the new state
  of the handler.

  The default implementation returns unchanged state, and a `:continue`
  action.
  """
  @callback application_started(app :: atom, state :: any) :: {action, state :: any}

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

  @spec invoke(:application_exited, app :: atom, cause, t) :: {action, t}
  def invoke(:application_exited = event, app, cause, %__MODULE__{state: state, module: module} = handler) do
    {action, new_state} = apply(module, event, [app, cause, state])
    {action, %{handler | state: new_state}}
  rescue
    e ->
      IO.puts("Shoehorn handler raised an exception: #{inspect(e)}")
      {:halt, state}
  end

  @spec invoke(:application_started, app :: atom, t) :: {action, t}
  def invoke(:application_started = event, app, %__MODULE__{state: state, module: module} = handler) do
    {action, new_state} = apply(module, event, [app, state])
    {action, %{handler | state: new_state}}
  rescue
    e ->
      IO.puts("Shoehorn handler raised an exception: #{inspect(e)}")
      {:continue, state}
  end
end
