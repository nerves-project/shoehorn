# Example

```
mix deps.get
mix release
_build/dev/rel/example/bin/example console_boot shoehorn
iex> Application.stop(:example)
```
