{
  description = "Jupyter Notebook with ML libraries and Matplotlib Dracula theme";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Allow unfree packages
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };

        # Python packages
        jupyterlabVim = pkgs.python3.pkgs.buildPythonPackage rec {
          pname = "jupyterlab_vim";
          version = "4.1.3";
          format = "pyproject";

          src = pkgs.python3.pkgs.fetchPypi {
            inherit pname version;
            sha256 = "sha256-V+GgpO3dIzTo16fA34D1CXt49UgP+oQwfy5QjfmLaHg=";
          };

          propagatedBuildInputs = with pkgs.python3.pkgs; [
            hatchling
            jupyterlab
            hatch-nodejs-version
            hatch-jupyter-builder
          ];

          doCheck = false;
        };

        # Python environment with all packages
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          # Core data science
          jupyter
          numpy
          pandas

          # Visualization
          matplotlib
          seaborn

          # Machine learning
          scikit-learn
          kaggle

          # Deep learning (unfree packages)
          torch-bin
          torchvision-bin

          # Jupyter extensions
          jupyterlabVim
        ]);

        # Script to set up Dracula theme for Matplotlib
        draculaThemeSetup = pkgs.writeShellScript "setup-dracula-theme" ''
          MATPLOTLIB_CONFIG_DIR="$HOME/.config/matplotlib"
          mkdir -p "$MATPLOTLIB_CONFIG_DIR"

          if [ ! -f "$MATPLOTLIB_CONFIG_DIR/matplotlibrc" ]; then
            ${pkgs.curl}/bin/curl -L "https://raw.githubusercontent.com/dracula/matplotlib/master/dracula.mplstyle" \
              -o "$MATPLOTLIB_CONFIG_DIR/dracula.mplstyle"
            echo "backend: TkAgg" > "$MATPLOTLIB_CONFIG_DIR/matplotlibrc"
            echo "style: dracula.mplstyle" >> "$MATPLOTLIB_CONFIG_DIR/matplotlibrc"
          fi
        '';

        # Jupyter wrapper that sets up config and theme
        jupyterWrapper = pkgs.writeShellScriptBin "jupyter-notebook" ''
          # Set up Jupyter config directory
          export JUPYTER_CONFIG_DIR="$PWD/.jupyter"
          if [ ! -d "$JUPYTER_CONFIG_DIR" ]; then
            mkdir -p "$JUPYTER_CONFIG_DIR"
            echo "c.NotebookApp.notebook_dir = '$PWD'" > "$JUPYTER_CONFIG_DIR/jupyter_notebook_config.py"
          fi

          # Set up Dracula theme
          ${draculaThemeSetup}

          # Launch Jupyter
          ${pythonEnv}/bin/jupyter-notebook
        '';
      in {
        # Default package is just the Jupyter wrapper
        packages.default = jupyterWrapper;

        # Default app is the Jupyter wrapper
        apps.default = {
          type = "app";
          program = "${jupyterWrapper}/bin/jupyter-notebook";
        };

        # Development shell with all tools
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pythonEnv
            jupyterWrapper
            pkgs.git
          ];

          shellHook = ''
            echo "Git version: $(git --version)"
            echo "Jupyter environment is ready. Run 'jupyter-notebook' to start."
            echo "Matplotlib Dracula theme will be set up automatically when you run jupyter-notebook."
          '';
        };
      }
    );
}
