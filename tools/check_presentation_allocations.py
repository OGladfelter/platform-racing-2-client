#!/usr/bin/env python3
"""Reject obvious steady-state allocations in smooth60 presentation paths."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    "haxe/src/pr2/gameplay/Course.hx": [
        "renderLocalPresentationFrame",
        "applyLocalPresentationPose",
        "renderRemotePresentationFrames",
        "renderFollowFadePresentationFrames",
        "renderLooseHatPresentationFrame",
        "renderCameraPresentationFrame",
        "renderCourseRotationPresentationFrame",
    ],
    "haxe/src/pr2/character/RemoteCharacter.hx": ["renderPresentationFrame"],
    "haxe/src/pr2/gameplay/SnakeManager.hx": ["renderPresentationFrame"],
    "haxe/src/pr2/gameplay/EggRound.hx": ["renderPresentationFrame"],
    "haxe/src/pr2/gameplay/HatEffect.hx": ["renderPresentationFrame"],
    "haxe/src/pr2/character/PhysicsParticle.hx": ["renderPresentationFrame"],
    "haxe/src/pr2/effects/BlockPiece.hx": ["renderPresentationFrame"],
    "haxe/src/pr2/effects/ShotEffect.hx": ["renderPresentationFrame"],
    "haxe/src/pr2/effects/FollowFadeEffect.hx": ["renderPresentationFrame"],
    "haxe/src/pr2/level/LevelRenderer.hx": [
        "setPresentationCameraOffset",
        "setPresentationCourseTweenRotation",
        "applyLayerTransforms",
        "applyTweenRotation",
        "configureLayerMatrix",
        "configureTweenRotationMatrix",
    ],
}

FORBIDDEN = {
    r"\bnew\s+": "object construction",
    r"\[\s*for\s*\(": "array comprehension",
    r"\.copy\s*\(": "collection copy",
    r"\.concat\s*\(": "array concatenation",
    r"\.keys\s*\(": "map-key iterator",
    r"\.iterator\s*\(": "iterator construction",
}


def method_body(source: str, method: str) -> str:
    match = re.search(rf"\bfunction\s+{re.escape(method)}\s*\(", source)
    if match is None:
        raise ValueError(f"missing method {method}")
    opening = source.find("{", match.end())
    if opening < 0:
        raise ValueError(f"missing body for {method}")
    depth = 0
    for index in range(opening, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise ValueError(f"unterminated body for {method}")


def main() -> int:
    errors: list[str] = []
    checked = 0
    for relative_path, methods in TARGETS.items():
        source = (ROOT / relative_path).read_text(encoding="utf-8")
        for method in methods:
            try:
                body = method_body(source, method)
            except ValueError as error:
                errors.append(f"{relative_path}: {error}")
                continue
            checked += 1
            for pattern, label in FORBIDDEN.items():
                if re.search(pattern, body):
                    errors.append(f"{relative_path}:{method}: forbidden steady-state {label}")

    if errors:
        print("Presentation allocation policy failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Presentation allocation policy passed: {checked} guarded methods")
    return 0


if __name__ == "__main__":
    sys.exit(main())
