"""Read the module identity used to identify the current release archive."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def module_identity(text):
    values = {}
    for field in ("name", "version"):
        matches = re.findall(rf'^\s*{field}\s*=\s*"([^"\r\n]+)"\s*$', text, re.MULTILINE)
        if len(matches) != 1:
            raise ValueError(f"Expected one {field} in moon.mod")
        values[field] = matches[0]
    if not re.fullmatch(r"[A-Za-z0-9_-]+/[A-Za-z0-9_-]+", values["name"]):
        raise ValueError("Invalid module name in moon.mod")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", values["version"]):
        raise ValueError("Invalid version in moon.mod")
    return values["name"], values["version"]


def release_info():
    name, version = module_identity((ROOT / "moon.mod").read_text(encoding="utf8"))
    archive = ROOT / "_build" / "publish" / f"{name.replace('/', '-')}-{version}.zip"
    return name, version, archive
