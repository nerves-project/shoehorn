# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Shoehorn.ReleaseError do
  @moduledoc """
  Error type for release boot script errors
  """
  defexception [:message]
end
