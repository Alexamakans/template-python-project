{
  description = "Template Python project using uv + uv2nix (dev shell + packaging)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # pyproject-nix ecosystem bits uv2nix relies on
    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    uv2nix.url = "github:pyproject-nix/uv2nix";
    pyproject-build-systems.url = "github:pyproject-nix/build-system-pkgs";

    # keep everyone on the same nixpkgs + pyproject-nix
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

      # Choose your Python here
      python = pkgs.python312;

      # Load the uv workspace (reads pyproject.toml + uv.lock when present)
      workspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = ./.;
      };

      # Turn the uv lock into a Nix overlay
      uvLockedOverlay = workspace.mkPyprojectOverlay {
        # "wheel" prefers prebuilt wheels, "sdist" can build from source
        sourcePreference = "wheel";
      };

      # Base Python package set from pyproject.nix
      basePySet = pkgs.callPackage pyproject-nix.build.packages {inherit python;};

      # Combine overlays: build-system tools + your locked deps + any local fixes
      pythonSet = basePySet.overrideScope (nixpkgs.lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        uvLockedOverlay
        # You can add overrides here, e.g. fix a package:
        # (final: prev: { somepkg = prev.somepkg.overridePythonAttrs (_: { ... }); })
      ]);

      # Name of this project must match [project.name] in pyproject.toml
      projectName = "template-python-project";

      # The project itself as a python package inside pythonSet
      thisProj = pythonSet.${projectName};

      # A runtime environment for the app (virtualenv-like closure)
      appEnv =
        pythonSet.mkVirtualEnv
        (thisProj.pname + "-env")
        workspace.deps.default; # deps from [project.dependencies]
    in {
      devShells.default = pkgs.mkShell {
        # Everything you want on PATH while hacking:
        packages = [
          appEnv
          pkgs.uv
          pkgs.ruff
          pkgs.pyright
          pkgs.python312Packages.pytest
        ];

        shellHook = ''
          echo "🐍 template-python-project dev shell"
          echo "Python: $(python --version)"
          echo "uv: $(uv --version)"
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
          # Create an entrypoint that runs your module
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
