Application.put_env(:shoehorn, :handler, ShoehornTest.Handler)
Code.ensure_loaded?(Distillery.Releases.Plugin)
ExUnit.start()
