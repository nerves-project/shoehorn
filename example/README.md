# Example

```
mix deps.get
mix release
_build/dev/rel/example/bin/example console_boot `pwd`/_build/dev/rel/example/bin/shoehorn
iex> Application.stop(:example)
```
