{
  description = "Template Python project using uv + uv2nix (dev shell + packaging)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    uv2nix.url = "github:pyproject-nix/uv2nix";
    pyproject-build-systems.url = "github:pyproject-nix/build-system-pkgs";

    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    pyproject-build-systems.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.inputs.pyproject-nix.follows = "pyproject-nix";
    pyproject-build-systems.inputs.pyproject-nix.follows = "pyproject-nix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    uv2nix,
    pyproject-nix,
    pyproject-build-systems,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      lib = pkgs.lib;

      python = pkgs.python312;

      # --- NEW: detect whether a uv.lock exists in the repo ---
      hasLock = builtins.pathExists ./uv.lock;

      # Load workspace (safe even if there's no lock; we just won't use deps)
      workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};

      uvLockedOverlay =
        if hasLock
        then workspace.mkPyprojectOverlay {sourcePreference = "wheel";}
        else (final: prev: {}); # empty overlay when no lock

      basePySet = pkgs.callPackage pyproject-nix.build.packages {inherit python;};

      pythonSet = basePySet.overrideScope (lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        uvLockedOverlay
      ]);

      projectName = "template-python-project";
      thisProj = pythonSet.${projectName};

      # --- NEW: only construct a locked virtual env if uv.lock exists ---
      appEnv =
        if hasLock
        then pythonSet.mkVirtualEnv (thisProj.pname + "-env") workspace.deps.default
        else
          # minimal python when bootstrapping (no pinned deps yet)
          python.withPackages (_: []);
    in {
      devShells.default = pkgs.mkShell {
        packages =
          (
            if hasLock
            then [appEnv]
            else [python]
          )
          ++ [
            pkgs.uv
            pkgs.ruff
            pkgs.pyright
            pkgs.python312Packages.pytest
            pkgs.pre-commit
          ];

        shellHook = ''
          export DEVSHELL_TAG="${projectName}"

          # Tag the prompt in interactive bash/zsh shells
          case "''${-}" in
            *i*)
              if [ -n "''${ZSH_VERSION-}" ]; then
                export PS1="(%F{cyan}nix:''${DEVSHELL_TAG}%f) $PS1"
              elif [ -n "''${BASH_VERSION-}" ]; then
                export PS1="(nix:''${DEVSHELL_TAG}) $PS1"
              fi
              ;;
          esac

          echo "🐍 ${projectName} dev shell"
          echo "Python: $(python --version)"
          echo "uv: $(uv --version)"

          if [ ! -f uv.lock ]; then
            echo
            echo "➡  No uv.lock found. To get the fully pinned environment:"
            echo "   uv lock && uv sync"
            echo "   Then exit and re-run: nix develop"
            echo
          fi

          # Auto-install git hooks if inside a repo and config exists
          if [ -d .git ] && [ -f .pre-commit-config.yaml ]; then
            pre-commit install --install-hooks || true
            pre-commit install -t pre-push || true
          fi

          # Optional breadcrumb command available only inside the dev shell
          mkdir -p .nix-dev-bin
          printf '#!/usr/bin/env sh\necho "In nix dev shell: %s"\n' "''${DEVSHELL_TAG}" > .nix-dev-bin/whereami-nix
          chmod +x .nix-dev-bin/whereami-nix
          export PATH="$PWD/.nix-dev-bin:$PATH"

          export IN_TEMPLATE_DEV_SHELL=1
        '';
      };

      # Build a runnable app for `nix build` / `nix run`
      packages.default = pkgs.stdenv.mkDerivation {
        pname = thisProj.pname;
        version = thisProj.version;
        src = ./.;
        nativeBuildInputs = [pkgs.makeWrapper];
        buildInputs = [appEnv];

        installPhase = ''
          mkdir -p $out/bin
          makeWrapper ${appEnv}/bin/python $out/bin/${thisProj.pname} \
            --add-flags "-m template_python_project"
        '';
      };

      apps.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/${projectName}";
      };
    });
}
