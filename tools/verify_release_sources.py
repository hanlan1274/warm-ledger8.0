"""Fail closed if the workflow is building different source files."""
from pathlib import Path
import hashlib
import json

expected = json.loads(Path('release-sources.json').read_text(encoding='utf-8'))
for name, digest in expected.items():
    actual = hashlib.sha256(Path(name).read_bytes()).hexdigest()
    if actual != digest:
        raise SystemExit(f'Release source mismatch: {name}')
source = Path('lib/expense_page.dart').read_text(encoding='utf-8')
assert '是否扣计划剩余额度' in source
assert '是否抵扣代管余额' in source
assert '记支出 · 0.3.0' in source
assert 'ExpensePage(' in Path('lib/main.dart').read_text(encoding='utf-8')
print('Verified 0.3.0 dedicated expense page and all release source hashes.')
