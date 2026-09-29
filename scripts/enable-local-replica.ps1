$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from PowerShell opened as Administrator.'
}
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$configPath = 'C:\Program Files\MongoDB\Server\6.0\bin\mongod.cfg'
$config = [IO.File]::ReadAllText($configPath)
if ($config -notmatch '(?m)^replication:') {
    if ($config -notmatch '(?m)^#replication:') { throw 'Expected replication placeholder not found; inspect mongod.cfg.' }
    Copy-Item -LiteralPath $configPath -Destination ($configPath + '.backup-' + (Get-Date -Format yyyyMMddHHmmss))
    $config = $config.Replace('#replication:', "replication:`r`n  replSetName: a2local")
    [IO.File]::WriteAllText($configPath, $config)
    Restart-Service MongoDB
}
@'
import time
from pathlib import Path
from pymongo import MongoClient
from pymongo.errors import OperationFailure
from dotenv import set_key
client = MongoClient('mongodb://127.0.0.1:27017/?directConnection=true', serverSelectionTimeoutMS=10000)
hello = client.admin.command('hello')
if hello.get('setName') not in (None, 'a2local'):
    raise RuntimeError('Unexpected replica set; configuration unchanged')
try:
    client.admin.command('replSetGetStatus')
except OperationFailure as error:
    if error.code != 94:
        raise
    client.admin.command('replSetInitiate', {'_id':'a2local','members':[{'_id':0,'host':'localhost:27017'}]})
for _ in range(60):
    hello = client.admin.command('hello')
    if (hello.get('setName') == 'a2local'
            and hello.get('isWritablePrimary')
            and hello.get('logicalSessionTimeoutMinutes') is not None):
        break
    time.sleep(1)
else:
    raise RuntimeError('Replica set did not become ready for sessions')
# The initialization connection can retain pre-replica-set session metadata.
# Discover the ready replica set with a fresh client before testing transactions.
client.close()
client = MongoClient('mongodb://localhost:27017/?replicaSet=a2local', serverSelectionTimeoutMS=10000)
client.admin.command('ping')
with client.start_session() as session:
    session.start_transaction()
    client['a2_setup_check']['probe'].find_one({}, session=session)
    session.abort_transaction()
client.close()
set_key(str(Path.cwd() / '.env'), 'MONGODB_URI', 'mongodb://localhost:27017/?replicaSet=a2local', quote_mode='never')
print('Replica set ready; transaction check passed; .env updated.')
'@ | & "$projectRoot\.venv\Scripts\python.exe" -
if ($LASTEXITCODE -ne 0) { throw 'Replica set initialization failed.' }
