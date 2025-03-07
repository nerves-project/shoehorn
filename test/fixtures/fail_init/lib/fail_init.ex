# SPDX-FileCopyrightText: 2017 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule FailInit do
  @moduledoc false
  require Logger

  def start(_, _) do
    Logger.warn("FailInit.start/2 Called")
    :error = "error"
  end
end
