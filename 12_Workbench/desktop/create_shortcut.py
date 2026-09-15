"""Rebuild the repository's portable shortcut on Windows with Python's stdlib.

The target is relative to the shortcut file, so a downloaded or cloned project
can move without retaining a developer's drive, account, or machine identity.
Keep the shortcut beside Start EMI Workbench.cmd. The launcher itself anchors
its paths to its own directory.

Windows stores a neutral, nonexistent target identity and the relative target.
The identity contains no user path; resolution uses the sibling launcher.
https://devblogs.microsoft.com/oldnewthing/20171019-00/?p=97247
"""
import argparse
import ctypes as c
import os
from pathlib import Path, PureWindowsPath
import tempfile
import uuid


SHORTCUT_NAME = "Open EMI Workbench.lnk"
LAUNCHER_NAME = "Start EMI Workbench.cmd"


def shortcut_bytes(target: str = LAUNCHER_NAME) -> bytes:
    relative = PureWindowsPath(target)
    if (relative.is_absolute() or relative.drive or relative.root
            or ".." in relative.parts or not relative.parts):
        raise ValueError("Target must be a file path within the shortcut's folder.")
    if os.name != "nt":
        raise ValueError("Shortcut regeneration uses Windows Shell APIs; run on Windows.")
    neutral_root = PureWindowsPath("C:/__EMI_WORKBENCH_PORTABLE__")
    if Path(neutral_root).exists():
        raise ValueError("The reserved shortcut identity unexpectedly exists on this computer.")

    class GUID(c.Structure):
        _fields_ = [("data", c.c_ubyte * 16)]

        def __init__(self, value):
            super().__init__((c.c_ubyte * 16).from_buffer_copy(uuid.UUID(value).bytes_le))

    def checked(result, operation):
        if result < 0:
            raise OSError(f"{operation}: HRESULT 0x{result & 0xFFFFFFFF:08X}")

    def method(pointer, slot, result, *args):
        table = c.cast(pointer, c.POINTER(c.POINTER(c.c_void_p))).contents
        return c.WINFUNCTYPE(result, c.c_void_p, *args)(table[slot])

    ole = c.WinDLL("ole32")
    ole.CoInitializeEx.argtypes = [c.c_void_p, c.c_uint32]
    ole.CoInitializeEx.restype = c.c_long
    ole.CoCreateInstance.argtypes = [c.POINTER(GUID), c.c_void_p, c.c_uint32,
                                     c.POINTER(GUID), c.POINTER(c.c_void_p)]
    ole.CoCreateInstance.restype = c.c_long
    checked(ole.CoInitializeEx(None, 2), "Initialize Shell COM")
    link, persist = c.c_void_p(), c.c_void_p()
    try:
        checked(ole.CoCreateInstance(
            c.byref(GUID("00021401-0000-0000-C000-000000000046")), None, 1,
            c.byref(GUID("000214F9-0000-0000-C000-000000000046")), c.byref(link)),
            "Create IShellLinkW")
        checked(method(link, 0, c.c_long, c.POINTER(GUID), c.POINTER(c.c_void_p))(
            link, c.byref(GUID("0000010B-0000-0000-C000-000000000046")), c.byref(persist)),
            "Get IPersistFile")
        checked(method(link, 20, c.c_long, c.c_wchar_p)(
            link, str(neutral_root / relative)), "Set neutral target")
        checked(method(link, 7, c.c_long, c.c_wchar_p)(
            link, "Open the local EMI Robotics Workbench"), "Set description")
        checked(method(link, 18, c.c_long, c.c_wchar_p, c.c_uint32)(
            link, str(neutral_root / SHORTCUT_NAME), 0), "Set relative resolution anchor")
        with tempfile.TemporaryDirectory(prefix="emi-shortcut-") as temporary:
            output = Path(temporary) / SHORTCUT_NAME
            checked(method(persist, 6, c.c_long, c.c_wchar_p, c.c_int)(
                persist, str(output), 1), "Save shortcut")
            return output.read_bytes()
    finally:
        if persist:
            method(persist, 2, c.c_uint32)(persist)
        if link:
            method(link, 2, c.c_uint32)(link)
        ole.CoUninitialize()


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", "--destination", type=Path,
                        default=root / SHORTCUT_NAME)
    parser.add_argument("--target", default=LAUNCHER_NAME,
                        help="Target path relative to the shortcut's folder.")
    args = parser.parse_args()
    try:
        content = shortcut_bytes(args.target)
    except ValueError as error:
        parser.error(str(error))
    destination = args.output.resolve()
    relative = PureWindowsPath(args.target)
    if not destination.parent.joinpath(*relative.parts).is_file():
        parser.error("The target must exist beside or within the shortcut's folder.")
    destination.write_bytes(content)
    print(f"Created {destination.name}; relative target: {relative}.")


if __name__ == "__main__":
    main()
