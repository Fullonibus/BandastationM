"""Bind one map worker and all descendants to its Windows process lifetime."""
from __future__ import annotations

import ctypes
from ctypes import wintypes
import os
import runpy
import sys


def own_process_tree() -> int:
    if os.name != 'nt':
        raise OSError('Maps worker requires Windows JobObject support')

    class BasicLimits(ctypes.Structure):
        _fields_ = [
            ('process_time', ctypes.c_int64), ('job_time', ctypes.c_int64),
            ('flags', wintypes.DWORD), ('min_working_set', ctypes.c_size_t),
            ('max_working_set', ctypes.c_size_t), ('active_processes', wintypes.DWORD),
            ('affinity', ctypes.c_size_t), ('priority', wintypes.DWORD),
            ('scheduling', wintypes.DWORD),
        ]

    class IoCounters(ctypes.Structure):
        _fields_ = [(name, ctypes.c_uint64) for name in (
            'reads', 'writes', 'other', 'read_bytes', 'write_bytes', 'other_bytes')]

    class ExtendedLimits(ctypes.Structure):
        _fields_ = [
            ('basic', BasicLimits), ('io', IoCounters),
            ('process_memory', ctypes.c_size_t), ('job_memory', ctypes.c_size_t),
            ('peak_process_memory', ctypes.c_size_t), ('peak_job_memory', ctypes.c_size_t),
        ]

    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    kernel.CreateJobObjectW.restype = wintypes.HANDLE
    kernel.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    kernel.SetInformationJobObject.restype = wintypes.BOOL
    kernel.SetHandleInformation.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.DWORD]
    kernel.SetHandleInformation.restype = wintypes.BOOL
    kernel.GetCurrentProcess.argtypes = []
    kernel.GetCurrentProcess.restype = wintypes.HANDLE
    kernel.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    kernel.AssignProcessToJobObject.restype = wintypes.BOOL
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL

    job = kernel.CreateJobObjectW(None, None)
    if not job:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        limits = ExtendedLimits()
        limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE; no breakaway.
        if not kernel.SetInformationJobObject(job, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
            raise ctypes.WinError(ctypes.get_last_error())
        if not kernel.SetHandleInformation(job, 1, 0):  # HANDLE_FLAG_INHERIT must stay clear.
            raise ctypes.WinError(ctypes.get_last_error())
        if not kernel.AssignProcessToJobObject(job, kernel.GetCurrentProcess()):
            raise ctypes.WinError(ctypes.get_last_error())
    except OSError:
        kernel.CloseHandle(job)
        raise
    return job


if __name__ == '__main__':
    try:
        _job = own_process_tree()
    except OSError as error:
        print('Cannot own map worker process tree: '+str(error), file=sys.stderr)
        raise SystemExit(1)
    # Keep the sole non-inherited handle open until OS process teardown. Closing it
    # here would kill this worker before Python flushes its JSON stdout response.
    sys.argv = sys.argv[1:]
    runpy.run_path(sys.argv[0], run_name='__main__')
