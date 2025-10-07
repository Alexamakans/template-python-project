import sys
import subprocess


def test_package_imports():
    # Import shouldn't raise
    import template_python_project  # renamed by ./rename.sh
    assert hasattr(template_python_project, "__version__")


def test_module_runs():
    # Running "python -m template_python_project" should succeed and print something
    proc = subprocess.run(
        [sys.executable, "-m", "template_python_project"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr
    # keep the assertion generic so renaming is easy
    assert "Hello from" in proc.stdout

