import subprocess
import sys


def test_package_imports():
    # Import shouldn't raise
    import template_python_project  # noqa

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
    assert "Hello from template-python-project v" in proc.stdout
