"""Create or restore the private APK signing identity without printing keys."""
import base64
import json
import os
from pathlib import Path
import secrets
import subprocess

encoded = os.environ.get('WARM_KEYSTORE_B64', '').strip()
password = os.environ.get('WARM_STOREPASS', '').strip()
generated = False
destination = Path('android/warm-ledger.jks')
if encoded:
    if not password:
        raise RuntimeError('Set both WARM_KEYSTORE_B64 and WARM_STOREPASS repository secrets')
    destination.write_bytes(base64.b64decode(encoded, validate=True))
else:
    if os.environ.get('FIRST_BUILD') != 'true':
        raise RuntimeError('No signing key configured. First build: enable first_build. Updates: restore the two signing secrets from your downloaded backup.')
    password = secrets.token_hex(24)
    os.environ['KEYGEN_PASSWORD'] = password
    subprocess.run(['keytool', '-genkeypair', '-keystore', str(destination),
        '-storetype', 'JKS', '-storepass:env', 'KEYGEN_PASSWORD', '-keypass:env', 'KEYGEN_PASSWORD',
        '-alias', 'warmledger', '-dname', 'CN=Warm Ledger Personal',
        '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000'], check=True)
    encoded = base64.b64encode(destination.read_bytes()).decode('ascii')
    backup = Path('signing-backup')
    backup.mkdir(exist_ok=True)
    (backup / 'signing-secrets.json').write_text(json.dumps({
        'WARM_KEYSTORE_B64': encoded, 'WARM_STOREPASS': password,
        'instructions': 'Keep this private. Set these two fields as repository Actions secrets before your next build. Never commit this file.'}, indent=2), encoding='utf-8')
    generated = True
print(f'::add-mask::{password}')
print(f'::add-mask::{encoded}')
with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as env:
    env.write(f'WARM_STOREPASS={password}\nWARM_NEW_KEY={str(generated).lower()}\n')
print('Signing identity prepared; private material is not printed.')
