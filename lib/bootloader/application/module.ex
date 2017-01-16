defmodule Bootloader.Application.Module do
  defstruct [module: nil, attributes: [], filename: nil, code_path: nil]

  def load(mod) do
    IO.inspect "Load Module #{inspect mod}"
    {file, path} =
      case :code.get_object_code(mod) do
        :error -> {nil, nil}
        {_mod, _bin, path} ->
          path = to_string(path)
          {Path.basename(path), Path.dirname(path)}
      end
    vsn =

    %__MODULE__{
      module: mod,
      attributes: mod.module_info(:attributes),
      filename: file,
      code_path: path
    }
  end

  def update(%__MODULE__{} = module, bin, opts) do

  end

end
