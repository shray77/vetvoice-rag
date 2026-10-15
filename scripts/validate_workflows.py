#!/usr/bin/env python3
"""Validate all GitHub Actions workflow YAML files."""

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML not installed — installing...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--break-system-packages", "pyyaml"])
    import yaml


def main():
    workflow_dir = Path("/home/z/my-project/repos/vetvoice-rag/.github/workflows")
    if not workflow_dir.exists():
        print(f"Error: {workflow_dir} does not exist")
        return 1

    yml_files = sorted(workflow_dir.glob("*.yml")) + sorted(workflow_dir.glob("*.yaml"))
    if not yml_files:
        print(f"No workflow files found in {workflow_dir}")
        return 1

    print(f"Found {len(yml_files)} workflow files:")
    print()

    all_ok = True
    for f in yml_files:
        print(f"=== {f.name} ===")
        try:
            with f.open("r", encoding="utf-8") as fp:
                data = yaml.safe_load(fp)
            print("  ✓ Valid YAML")

            # Check required top-level keys
            if "name" not in data:
                print("  ⚠️  Missing 'name' field")
                all_ok = False
            else:
                print(f"  name: {data['name']}")

            if "on" not in data:
                print("  ⚠️  Missing 'on' field (triggers)")
                all_ok = False
            else:
                triggers = data["on"]
                if isinstance(triggers, dict):
                    trigger_names = list(triggers.keys())
                else:
                    trigger_names = [str(triggers)]
                print(f"  triggers: {', '.join(trigger_names)}")

            if "jobs" not in data:
                print("  ⚠️  Missing 'jobs' field")
                all_ok = False
            else:
                job_names = list(data["jobs"].keys())
                print(f"  jobs: {', '.join(job_names)}")

            # Check for top-level env block (new requirement for secrets)
            if "env" in data:
                env_keys = list(data["env"].keys())
                print(f"  top-level env: {', '.join(env_keys)}")
                if "HF_TOKEN" in data["env"]:
                    print("  ✓ HF_TOKEN exposed to all steps")

            # Check each job
            for job_name, job in data.get("jobs", {}).items():
                if "steps" not in job:
                    print(f"  ⚠️  Job '{job_name}' has no steps")
                    all_ok = False
                else:
                    step_count = len(job["steps"])
                    print(f"  job '{job_name}': {step_count} steps")

            # Check for env: secrets in individual steps (anti-pattern we fixed)
            for job_name, job in data.get("jobs", {}).items():
                for i, step in enumerate(job.get("steps", [])):
                    step_name = step.get("name", f"step #{i}")
                    step_env = step.get("env", {})
                    if "HF_TOKEN" in step_env and "env" not in data:
                        # Only warn if there's no top-level env
                        print(f"  ℹ️  Step '{step_name}' has env.HF_TOKEN — consider moving to top-level env")

            print()
        except yaml.YAMLError as e:
            print(f"  ✗ Invalid YAML: {e}")
            all_ok = False
            print()

    print("=" * 60)
    if all_ok:
        print("✓ All workflow files are valid.")
        return 0
    else:
        print("✗ Some workflow files have issues.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
