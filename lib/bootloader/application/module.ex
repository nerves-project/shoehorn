defmodule Bootloader.Application.Module do
  defstruct [name: nil, hash: nil, binary: nil]

  @type t :: %__MODULE__{
    name: atom,
    hash: String.t | number(),
    binary: binary()
  }

  def load(app, mod) do
    %__MODULE__{
      name: mod,
      hash: hash(app, mod)
    }
  end

  def hash(app, mod) do
    attributes(app, mod)[:vsn]
    |> List.first
  end

  def attributes(app, mod) do
    try do
      beam =
        beam(app, mod)
        |> Kernel.to_charlist()
      {:ok, {_, [attributes: attributes]}} = :beam_lib.chunks(beam, [:attributes])
      attributes
    rescue
      _ ->
        mod.module_info(:attributes)
    end
  end

  def bin(app, mod) do
    try do
      beam(app, mod)
      |> File.read!()
    rescue
      _ ->
        {_, bin, _} = :code.get_object_code(mod.name)
        bin
    end
  end

  def beam(app, mod) do
    Bootloader.Application.ebin(app)
    |> Path.join("#{mod}.beam")
  end

  def compare(sources, targets) when is_list(sources) and is_list(targets) do
    modified =
      Enum.reduce(sources, [], fn(s, acc) ->
        t = Enum.find(targets, & &1.name == s.name)
        case compare(s, t) do
          {:noop, _} -> acc
          modification ->
            [modification | acc]
        end
      end)
    deleted =
      Enum.reduce(targets, [], fn(t, acc) ->
        if Enum.any?(sources, & &1.name == t.name) do
          acc
        else
          [{:deleted, t} | acc]
        end
      end)
    modified ++ deleted
  end
  def compare(s, nil), do: {:inserted, s}
  def compare(%{hash: hash} = s, %{hash: hash}), do: {:noop, s}
  def compare(s, _), do: {:modified, s}

  def apply({action, mod}, overlay_path) when action in [:inserted, :modified] do
    ebin_path = Path.join(overlay_path, "ebin")
    File.mkdir_p(ebin_path)

    beam_file = Path.join(ebin_path, "#{mod.name}.beam")
    File.write(beam_file, mod.binary)
    if action == :modified do
      :code.purge(mod.name)
    end

    Code.prepend_path(ebin_path)
    :code.load_file(mod.name)
  end
  def apply({:deleted, mod}, _) do
    :code.delete(mod.name)
    :code.purge(mod.name)
  end

end
