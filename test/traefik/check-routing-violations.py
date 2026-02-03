#!/usr/bin/env python3
"""
Design Review Tool: Check for Environment-Aware Routing Violations

This script scans JavaScript and HTML files for patterns that violate the
Traefik design principle: "Traefik handles ALL routing. Services should be
simple and not know about routing."

Violations include:
- Environment detection (hostname checking)
- URL construction based on environment
- Hardcoded domain names
- Conditional baseUrl logic

Usage:
    python3 check-routing-violations.py [path]
    python3 check-routing-violations.py labs/
    python3 check-routing-violations.py . --exclude node_modules
"""

import os
import re
import sys
import argparse
from pathlib import Path
from typing import List, Dict, Tuple
from dataclasses import dataclass, field
from enum import Enum


class ViolationType(Enum):
    """Types of routing violations"""
    HOSTNAME_CHECK = "hostname_check"
    ENV_DETECTION = "env_detection"
    URL_CONSTRUCTION = "url_construction"
    HARDCODED_DOMAIN = "hardcoded_domain"
    CONDITIONAL_BASEURL = "conditional_baseurl"
    ENVIRONMENT_AWARE_COMMENT = "environment_aware_comment"


@dataclass
class Violation:
    """Represents a routing violation"""
    file_path: str
    line_number: int
    violation_type: ViolationType
    pattern: str
    context: str = ""
    severity: str = "medium"  # low, medium, high


class RoutingViolationChecker:
    """Scans files for environment-aware routing patterns"""

    # Patterns that indicate violations
    PATTERNS = {
        ViolationType.HOSTNAME_CHECK: [
            r'window\.location\.hostname',
            r'location\.hostname',
            r'window\.location\.host',
            r'location\.host',
        ],
        ViolationType.ENV_DETECTION: [
            r'hostname\s*===\s*[\'"](localhost|127\.0\.0\.1|stg\.pcioasis\.com|pcioasis\.com)',
            r'hostname\s*===',
            r'isLocal\s*=',
            r'isStaging\s*=',
            r'isProduction\s*=',
            r'environment\s*===',
        ],
        ViolationType.URL_CONSTRUCTION: [
            r'baseUrl\s*=',
            r'baseURL\s*=',
            r'homeUrl\s*=',
            r'c2Url\s*=',
            r'writeupUrl\s*=',
            r'const\s+\w+Url\s*=',
            r'let\s+\w+Url\s*=',
        ],
        ViolationType.HARDCODED_DOMAIN: [
            r'https?://(localhost|127\.0\.0\.1|labs\.stg\.pcioasis\.com|labs\.pcioasis\.com)',
            r'https?://[a-zA-Z0-9.-]+\.(run\.app|pcioasis\.com)',
        ],
        ViolationType.CONDITIONAL_BASEURL: [
            r'if\s*\([^)]*hostname[^)]*\)\s*\{[^}]*baseUrl',
            r'baseUrl\s*=\s*\([^)]*hostname[^)]*\)\s*\?',
            r'baseUrl\s*=\s*hostname\s*===',
        ],
        ViolationType.ENVIRONMENT_AWARE_COMMENT: [
            r'Environment-aware\s+URL',
            r'environment-aware\s+URL',
            r'Environment\s+aware\s+URL',
        ],
    }

    # File extensions to check
    JS_EXTENSIONS = {'.js', '.jsx', '.ts', '.tsx'}
    HTML_EXTENSIONS = {'.html', '.htm'}

    def __init__(self, exclude_dirs: List[str] = None):
        self.exclude_dirs = set(exclude_dirs or [])
        self.violations: List[Violation] = []

    def should_scan_file(self, file_path: Path) -> bool:
        """Check if file should be scanned"""
        # Check if in excluded directory
        for part in file_path.parts:
            if part in self.exclude_dirs:
                return False

        # Check extension
        ext = file_path.suffix.lower()
        return ext in self.JS_EXTENSIONS or ext in self.HTML_EXTENSIONS

    def extract_js_from_html(self, content: str) -> List[Tuple[int, str]]:
        """Extract JavaScript from HTML files"""
        js_blocks = []

        # Find <script> blocks
        script_pattern = r'<script[^>]*>(.*?)</script>'
        for match in re.finditer(script_pattern, content, re.DOTALL | re.IGNORECASE):
            script_content = match.group(1)
            # Find line number (approximate)
            line_num = content[:match.start()].count('\n') + 1
            js_blocks.append((line_num, script_content))

        # Also check inline event handlers and data attributes
        inline_pattern = r'on\w+\s*=\s*["\']([^"\']+)["\']'
        for match in re.finditer(inline_pattern, content, re.IGNORECASE):
            line_num = content[:match.start()].count('\n') + 1
            js_blocks.append((line_num, match.group(1)))

        return js_blocks

    def check_patterns(self, content: str, file_path: str, line_offset: int = 0) -> List[Violation]:
        """Check content for violation patterns"""
        violations = []
        lines = content.split('\n')

        for violation_type, patterns in self.PATTERNS.items():
            for pattern in patterns:
                regex = re.compile(pattern, re.IGNORECASE | re.MULTILINE)

                for match in regex.finditer(content):
                    # Find line number
                    line_num = content[:match.start()].count('\n') + 1 + line_offset

                    # Get context (3 lines before and after)
                    start_line = max(0, line_num - 4)
                    end_line = min(len(lines), line_num + 3)
                    context_lines = lines[start_line:end_line]
                    context = '\n'.join(
                        f"{start_line + i + 1:4d} | {line}"
                        for i, line in enumerate(context_lines)
                    )

                    # Determine severity
                    severity = self._determine_severity(violation_type, match.group(0))

                    violation = Violation(
                        file_path=file_path,
                        line_number=line_num,
                        violation_type=violation_type,
                        pattern=match.group(0),
                        context=context,
                        severity=severity
                    )
                    violations.append(violation)

        return violations

    def _determine_severity(self, violation_type: ViolationType, pattern: str) -> str:
        """Determine severity of violation"""
        if violation_type == ViolationType.ENVIRONMENT_AWARE_COMMENT:
            return "low"  # Comment is just documentation
        elif violation_type == ViolationType.HOSTNAME_CHECK:
            return "high"  # Direct hostname checking is a clear violation
        elif violation_type == ViolationType.CONDITIONAL_BASEURL:
            return "high"  # Conditional URL construction is a violation
        elif violation_type == ViolationType.URL_CONSTRUCTION:
            # Check if it's conditional
            if 'if' in pattern.lower() or '?' in pattern:
                return "high"
            return "medium"
        elif violation_type == ViolationType.HARDCODED_DOMAIN:
            return "medium"
        else:
            return "medium"

    def scan_file(self, file_path: Path) -> List[Violation]:
        """Scan a single file for violations"""
        violations = []

        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()

            # For HTML files, extract JavaScript
            if file_path.suffix.lower() in self.HTML_EXTENSIONS:
                js_blocks = self.extract_js_from_html(content)
                for line_offset, js_content in js_blocks:
                    file_violations = self.check_patterns(
                        js_content,
                        str(file_path),
                        line_offset=line_offset
                    )
                    violations.extend(file_violations)
            else:
                # Direct JavaScript file
                violations = self.check_patterns(content, str(file_path))

        except Exception as e:
            print(f"Error scanning {file_path}: {e}", file=sys.stderr)

        return violations

    def scan_directory(self, root_path: Path) -> List[Violation]:
        """Recursively scan directory for violations"""
        violations = []

        for root, dirs, files in os.walk(root_path):
            # Filter out excluded directories
            dirs[:] = [d for d in dirs if d not in self.exclude_dirs]

            for file in files:
                file_path = Path(root) / file
                if self.should_scan_file(file_path):
                    file_violations = self.scan_file(file_path)
                    violations.extend(file_violations)

        return violations

    def generate_report(self, violations: List[Violation], output_format: str = "text") -> str:
        """Generate a report of violations"""
        if output_format == "text":
            return self._generate_text_report(violations)
        elif output_format == "json":
            return self._generate_json_report(violations)
        else:
            raise ValueError(f"Unknown output format: {output_format}")

    def _generate_text_report(self, violations: List[Violation]) -> str:
        """Generate text report"""
        if not violations:
            return "✅ No routing violations found!\n"

        # Group by file
        by_file: Dict[str, List[Violation]] = {}
        for v in violations:
            if v.file_path not in by_file:
                by_file[v.file_path] = []
            by_file[v.file_path].append(v)

        # Sort by severity
        severity_order = {"high": 0, "medium": 1, "low": 2}
        for file_violations in by_file.values():
            file_violations.sort(key=lambda v: (severity_order.get(v.severity, 3), v.line_number))

        # Generate report
        lines = []
        lines.append("=" * 80)
        lines.append("ROUTING VIOLATIONS REPORT")
        lines.append("=" * 80)
        lines.append(f"\nTotal violations found: {len(violations)}")
        lines.append(f"Files affected: {len(by_file)}")
        lines.append("")

        # Count by type
        by_type = {}
        by_severity = {}
        for v in violations:
            by_type[v.violation_type] = by_type.get(v.violation_type, 0) + 1
            by_severity[v.severity] = by_severity.get(v.severity, 0) + 1

        lines.append("Summary by Type:")
        for vtype, count in sorted(by_type.items(), key=lambda x: x[1], reverse=True):
            lines.append(f"  {vtype.value:30s} {count:3d}")
        lines.append("")

        lines.append("Summary by Severity:")
        for severity in ["high", "medium", "low"]:
            count = by_severity.get(severity, 0)
            if count > 0:
                lines.append(f"  {severity.upper():10s} {count:3d}")
        lines.append("")
        lines.append("=" * 80)
        lines.append("")

        # Detailed violations (limit to first 20 files to avoid overwhelming output)
        file_list = sorted(by_file.items())[:20]
        if len(by_file) > 20:
            lines.append(f"\n⚠️  Showing first 20 files (of {len(by_file)} total)")
            lines.append("   Use --format json for complete report\n")

        for file_path, file_violations in file_list:
            lines.append(f"\n📄 {file_path}")
            lines.append("-" * 80)

            # Limit violations per file to avoid overwhelming output
            display_violations = file_violations[:10]
            if len(file_violations) > 10:
                lines.append(f"\n⚠️  Showing first 10 violations (of {len(file_violations)} total in this file)")

            for v in display_violations:
                severity_icon = {
                    "high": "🔴",
                    "medium": "🟡",
                    "low": "🟢"
                }.get(v.severity, "⚪")

                lines.append(f"\n{severity_icon} Line {v.line_number}: {v.violation_type.value}")
                lines.append(f"   Pattern: {v.pattern[:60]}")
                if v.context:
                    lines.append(f"   Context:")
                    lines.append(v.context)
                lines.append("")

        return "\n".join(lines)

    def _generate_json_report(self, violations: List[Violation]) -> str:
        """Generate JSON report"""
        import json

        report = {
            "total_violations": len(violations),
            "files_affected": len(set(v.file_path for v in violations)),
            "violations": [
                {
                    "file": v.file_path,
                    "line": v.line_number,
                    "type": v.violation_type.value,
                    "pattern": v.pattern,
                    "severity": v.severity,
                    "context": v.context
                }
                for v in violations
            ]
        }

        return json.dumps(report, indent=2)


def main():
    parser = argparse.ArgumentParser(
        description="Check for environment-aware routing violations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check current directory
  python3 check-routing-violations.py .

  # Check specific directory
  python3 check-routing-violations.py labs/

  # Exclude directories
  python3 check-routing-violations.py . --exclude node_modules --exclude .git

  # JSON output
  python3 check-routing-violations.py . --format json > violations.json
        """
    )

    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Path to scan (default: current directory)"
    )

    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Directories to exclude (can be specified multiple times)"
    )

    parser.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        help="Output format (default: text)"
    )

    parser.add_argument(
        "--exit-code",
        action="store_true",
        help="Exit with non-zero code if violations found"
    )

    args = parser.parse_args()

    # Default exclusions
    exclude_dirs = set(args.exclude)
    exclude_dirs.update([".git", "node_modules", ".venv", "venv", "__pycache__", ".pytest_cache"])

    # Create checker
    checker = RoutingViolationChecker(exclude_dirs=list(exclude_dirs))

    # Scan
    scan_path = Path(args.path)
    if not scan_path.exists():
        print(f"Error: Path does not exist: {scan_path}", file=sys.stderr)
        sys.exit(1)

    if scan_path.is_file():
        violations = checker.scan_file(scan_path)
    else:
        violations = checker.scan_directory(scan_path)

    # Generate report
    report = checker.generate_report(violations, args.format)
    print(report)

    # Exit code
    if args.exit_code and violations:
        sys.exit(1)
    elif args.exit_code:
        sys.exit(0)


if __name__ == "__main__":
    main()
