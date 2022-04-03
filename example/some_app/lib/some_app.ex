defmodule SomeApp do
  @moduledoc """
  This is just a normal application.

  The one thing it does is optionally depend on `:optional_app`. It's good for
  `:optional_app` to be started before this one, but that's only possible if
  you're using OTP 24+.
  """
end
