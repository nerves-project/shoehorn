# SPDX-FileCopyrightText: 2017 Justin Schneck
#
# SPDX-License-Identifier: Apache-2.0
#
Application.put_env(:shoehorn, :handler, ShoehornTest.Handler)
ExUnit.start()
