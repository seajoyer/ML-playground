{
  description = "Jupyter Notebook with ML libraries";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonEnv = pkgs.python3.withPackages (ps:
          with ps; [
            jupyter
            numpy
            pandas
            matplotlib

            (buildPythonPackage rec {
              pname = "jupyterlab_vim";
              version = "4.1.3";

              src = fetchPypi {
                inherit pname version;
                sha256 = "sha256-V+GgpO3dIzTo16fA34D1CXt49UgP+oQwfy5QjfmLaHg=";
              };

              doCheck = false;
              format = "pyproject";

              propagatedBuildInputs = [
                hatchling
                jupyterlab
                hatch-nodejs-version
                hatch-jupyter-builder
              ];
            })
          ]);

        jupyterWrapper = pkgs.writeShellScriptBin "jupyter-notebook" ''
          export JUPYTER_CONFIG_DIR="$PWD/.jupyter"
          if [ ! -d "$JUPYTER_CONFIG_DIR" ]; then
            mkdir -p "$JUPYTER_CONFIG_DIR"
            echo "c.NotebookApp.notebook_dir = '$PWD'" > "$JUPYTER_CONFIG_DIR/jupyter_notebook_config.py"
          fi
          ${pythonEnv}/bin/jupyter-notebook
        '';
      in {
        packages.default = jupyterWrapper;

        apps.default = {
          type = "app";
          program = "${jupyterWrapper}/bin/jupyter-notebook";
        };

        devShells.default =
          pkgs.mkShell { buildInputs = [ pythonEnv jupyterWrapper pkgs.git ]; };
          shellHook = ''
            echo "Git version: $(git --version)"
            echo "Jupyter environment is ready. Run 'jupyter-notebook' to start."
          '';
      });
}
