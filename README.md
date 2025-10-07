# template-python-project

A tiny Python template that uses **uv** for dependency management and **uv2nix** to build reproducible Nix packages. It **does not require Nix** to use or develop—Nix is optional and just makes the environment fully reproducible.

---

## Requirements

- **Python ≥ 3.12**
- **uv** (recommended) — fast package/dependency manager
  - Install one of the following ways:
    - `pipx install uv`
    - or `python -m pip install --user uv`
    - or the official install script: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Optional developer tools if you don't use Nix:
  - `ruff`, `pytest`, `pre-commit`
  - Or run them ad‑hoc via `uvx` (see below), no install needed.

> If you use **Nix with flakes**, you don't need to install any of the tools above; the dev shell provides them.

---

## Quick start (with Nix — optional)

```bash
# enter the dev environment (brings uv, python, ruff, pytest, pre-commit onto PATH)
nix develop

# inside the dev shell: create/update the lockfile and local virtualenv
uv lock
uv sync

# run the app
uv run template-python-project
# or
python -m template_python_project
```

---

## Quick start (without Nix)

### Option A: uv end-to-end (recommended)

```bash
# ensure you have Python 3.12+ and uv installed

# create/update the lockfile and local virtualenv at .venv
uv lock
uv sync

# run the app
uv run template-python-project
# or
python -m template_python_project

# lint / format / test (no installs needed thanks to uvx)
uvx ruff check .
uvx ruff format .
uvx pytest -q

# (optional) install git hooks
uvx pre-commit install --install-hooks
uvx pre-commit install -t pre-push
```

### Option B: standard venv + pip

```bash
python -m venv .venv
. .venv/bin/activate
python -m pip install -U pip wheel
# install the project in editable mode
pip install -e .
# install dev tools (optional)
pip install ruff pytest pre-commit

# run the app
python -m template_python_project

# lint / format / test
ruff check .
ruff format .
pytest -q
```

---

## Build a Nix package (uses uv.lock via uv2nix)

```bash
# ensure lock exists
uv lock

# build the package
nix build

# run the produced binary
./result/bin/template-python-project
```

You can also run directly via flake apps:

```bash
nix run
```

---

## Usage cheatsheet

```bash
# once per clone (with or without Nix)
uv lock            # produce/update uv.lock
uv sync            # create .venv and install deps

# lint / format / test
uvx ruff check .
uvx ruff format .
uvx pytest -q

# package & run via Nix (optional)
nix build
nix run
```

---

## Common tasks (Makefile)

```bash
# set up env (creates/updates .venv using uv)
make setup

# auto-format + lint + tests
make fmt
make lint
make test
make check   # lint + test

# run the app
make run

# build the Nix package (uses uv2nix + flake)
make build

# clean artifacts
make clean
```

> Tip: Even without Nix, the Makefile targets work if you have `uv` installed. They call `uv run`/`uvx` under the hood via the `UV` variable.

---

## Git hooks (pre-commit)

If you're using Nix, hooks are auto-installed when you enter `nix develop`. Without Nix:

```bash
uvx pre-commit install --install-hooks
uvx pre-commit install -t pre-push
# run hooks on all files
uvx pre-commit run -a
```

---

## Tests

A tiny smoke test is included:

```bash
# with Nix
nix develop
make setup
make test

# without Nix
uv lock && uv sync
uvx pytest -q
```

---

## Renaming this template

Use the provided script to rename both hyphenated and underscored names across files and paths:

```bash
./rename.sh template-python-project my-cool-project
```

This replaces:
- `template-python-project` → `my-cool-project`
- `template_python_project` → `my_cool_project`

and renames matching files/directories (e.g., `src/template_python_project/` → `src/my_cool_project/`).

---

## Layout

```
.
├─ flake.nix
├─ pyproject.toml
├─ .pre-commit-config.yaml
├─ Makefile
├─ rename.sh
├─ src/
│  └─ template_python_project/
│     ├─ __init__.py
│     └─ __main__.py
└─ tests/
   └─ test_smoke.py
```

---

## Notes

- With **Nix**, the dev shell includes `uv`, `ruff`, `pyright`, `pytest`, and `pre-commit`.
- Without Nix, install `uv` and use `uvx` to run dev tools without polluting your environment.
- The flake ingests `pyproject.toml` + `uv.lock` through **uv2nix** to build a pinned environment.
