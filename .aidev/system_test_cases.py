#!/usr/bin/env python3
"""Turn the junit report of a pytest run of the HAF system tests into cases.

    system_test_cases.py JUNIT LOG_DIR

Prints one line per test in the format .aidev/junit_cases.py reads:

    case<TAB>NODE_ID<TAB>pass|fail|skip<TAB>SECONDS<TAB>MESSAGE[<TAB>LOG]

NODE_ID is the test's pytest node id relative to tests/integration/system/haf/
(`test_x.py::test_y[param]`), whatever rootdir pytest chose, so that a re-run can
hand it back to pytest as it is. A failing test's failure text is written to
LOG_DIR/<node id>.log, the body junit_cases.py reports. A test the report names
more than once (a teardown error after its call) is reported once, failing if
any of its entries failed.
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

_RANK = {"pass": 0, "skip": 1, "fail": 2}
_UNSAFE = re.compile(r"[^A-Za-z0-9_.\[\]-]+")


def _node_id(classname: str, name: str) -> str:
    parts = classname.split(".")
    module = next((i for i, part in enumerate(parts) if part.startswith("test_")), len(parts) - 1)
    return "::".join([f"{parts[module]}.py", *parts[module + 1 :], name])


def _one_line(text: str) -> str:
    return " ".join(text.split())[:300]


def main(junit: str, log_dir: str) -> None:
    os.makedirs(log_dir, exist_ok=True)
    cases: dict[str, tuple[str, float, str, str]] = {}
    for case in ET.parse(junit).getroot().iter("testcase"):
        node_id = _node_id(case.get("classname", ""), case.get("name", ""))
        seconds = float(case.get("time") or 0)
        failure = case.find("failure")
        if failure is None:
            failure = case.find("error")
        skipped = case.find("skipped")
        status, message, log = "pass", "", ""
        if failure is not None:
            status, message = "fail", _one_line(failure.get("message") or failure.tag)
            log = os.path.join(log_dir, _UNSAFE.sub("_", node_id) + ".log")
            with open(log, "w", encoding="utf-8") as handle:
                handle.write(failure.text or message)
        elif skipped is not None:
            status, message = "skip", _one_line(skipped.get("message") or "skipped")
        previous = cases.get(node_id)
        if previous is not None:
            seconds += previous[1]
            if _RANK[previous[0]] >= _RANK[status]:
                status, message, log = previous[0], previous[2], previous[3]
        cases[node_id] = (status, seconds, message, log)
    for node_id, (status, seconds, message, log) in cases.items():
        print("\t".join(["case", node_id, status, f"{seconds:.1f}", message, log]))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} JUNIT LOG_DIR")
    main(*sys.argv[1:])
