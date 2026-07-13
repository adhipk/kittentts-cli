#!/usr/bin/env python3
"""Focused failure-path tests for kit streaming without model dependencies."""

from __future__ import annotations

import runpy
import subprocess
import sys
import tempfile
import threading
import time
import types
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parent.parent


class FakeSoundFile(types.ModuleType):
    def __init__(self) -> None:
        super().__init__("soundfile")
        self.paths: list[Path] = []

    def write(self, path: str, _audio: object, _sample_rate: int) -> None:
        output = Path(path)
        output.write_bytes(b"fake wav")
        self.paths.append(output)


class StreamingFailureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.kit = runpy.run_path(str(ROOT / "kit"), run_name="kit_stream_test")
        self.soundfile = FakeSoundFile()
        self.soundfile_patch = mock.patch.dict(sys.modules, {"soundfile": self.soundfile})
        self.soundfile_patch.start()
        self.temp_dir = tempfile.TemporaryDirectory(prefix="kit-stream-test.")
        self.original_tempdir = tempfile.tempdir
        tempfile.tempdir = self.temp_dir.name

    def tearDown(self) -> None:
        tempfile.tempdir = self.original_tempdir
        self.temp_dir.cleanup()
        self.soundfile_patch.stop()

    def assert_no_audio_leaks(self) -> None:
        self.assertEqual(list(Path(self.temp_dir.name).glob("*.wav")), [])

    def test_generator_error_propagates_promptly_and_cleans_audio(self) -> None:
        class FailingModel:
            calls = 0

            def generate(self, _text: str, *, voice: str, speed: float) -> bytes:
                self.calls += 1
                if self.calls == 2:
                    raise RuntimeError("generator exploded")
                return b"audio"

        started = time.monotonic()
        with mock.patch.object(subprocess, "run", return_value=None):
            with self.assertRaisesRegex(RuntimeError, "generator exploded"):
                self.kit["stream_text"](
                    FailingModel(),
                    "First sentence. Second sentence.",
                    "Jasper",
                    1.0,
                    18,
                )

        self.assertLess(time.monotonic() - started, 2.0)
        self.assertTrue(self.soundfile.paths, "the successful first chunk should create audio")
        self.assert_no_audio_leaks()

    def test_player_error_cancels_generation_and_cleans_queued_audio(self) -> None:
        class Model:
            def generate(self, _text: str, *, voice: str, speed: float) -> bytes:
                return b"audio"

        player_error = subprocess.CalledProcessError(1, ["afplay"])
        started = time.monotonic()
        with mock.patch.object(subprocess, "run", side_effect=player_error):
            with self.assertRaises(subprocess.CalledProcessError):
                self.kit["stream_text"](
                    Model(),
                    "One. Two. Three. Four. Five.",
                    "Jasper",
                    1.0,
                    5,
                )

        self.assertLess(time.monotonic() - started, 2.0)
        self.assert_no_audio_leaks()

    def test_player_error_does_not_wait_forever_for_inflight_generation(self) -> None:
        release_generation = threading.Event()

        class SlowSecondChunkModel:
            calls = 0

            def generate(self, _text: str, *, voice: str, speed: float) -> bytes:
                self.calls += 1
                if self.calls == 2:
                    release_generation.wait(timeout=10)
                return b"audio"

        player_error = subprocess.CalledProcessError(1, ["afplay"])
        started = time.monotonic()
        try:
            with mock.patch.object(subprocess, "run", side_effect=player_error):
                with self.assertRaises(subprocess.CalledProcessError):
                    self.kit["stream_text"](
                        SlowSecondChunkModel(),
                        "One. Two.",
                        "Jasper",
                        1.0,
                        5,
                    )
        finally:
            release_generation.set()

        self.assertLess(time.monotonic() - started, 2.0)
        self.assert_no_audio_leaks()


if __name__ == "__main__":
    unittest.main()
