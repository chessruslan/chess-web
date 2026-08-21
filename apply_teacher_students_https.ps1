param(
  [string]$ProjectRef = "chmebxirnmqgvdpwskhw",
  [string]$MigrationFile = ".\supabase\migrations\20260627135000_create_teacher_students.sql"
)

$ErrorActionPreference = "Stop"

function Get-SupabaseAccessToken {
  if ($env:SUPABASE_ACCESS_TOKEN -and $env:SUPABASE_ACCESS_TOKEN.Trim()) {
    return $env:SUPABASE_ACCESS_TOKEN.Trim()
  }

  $candidateFiles = @(
    (Join-Path $HOME ".supabase\access-token"),
    (Join-Path $env:USERPROFILE ".supabase\access-token"),
    (Join-Path $env:APPDATA "supabase\access-token")
  ) | Select-Object -Unique

  foreach ($file in $candidateFiles) {
    if (Test-Path $file) {
      $value = (Get-Content $file -Raw).Trim()
      if ($value) { return $value }
    }
  }

  $source = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class WinCredReaderHttpsMigration
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL
    {
        public UInt32 Flags;
        public UInt32 Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
    }

    [DllImport("Advapi32.dll", EntryPoint = "CredReadW",
        CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(
        string target,
        int type,
        int reservedFlag,
        out IntPtr credentialPtr);

    [DllImport("Advapi32.dll", SetLastError = true)]
    private static extern void CredFree(IntPtr cred);

    public static string Read(string target)
    {
        IntPtr credPtr;
        if (!CredRead(target, 1, 0, out credPtr))
            return null;

        try
        {
            var cred = (CREDENTIAL)Marshal.PtrToStructure(
                credPtr, typeof(CREDENTIAL));

            if (cred.CredentialBlob == IntPtr.Zero ||
                cred.CredentialBlobSize == 0)
                return null;

            byte[] bytes = new byte[cred.CredentialBlobSize];
            Marshal.Copy(cred.CredentialBlob, bytes, 0, bytes.Length);

            string unicode = Encoding.Unicode.GetString(bytes).TrimEnd('\0');
            if (unicode.StartsWith("sbp_")) return unicode;

            string utf8 = Encoding.UTF8.GetString(bytes).TrimEnd('\0');
            return utf8;
        }
        finally
        {
            CredFree(credPtr);
        }
    }
}
"@

  if (-not ("WinCredReaderHttpsMigration" -as [type])) {
    Add-Type -TypeDefinition $source
  }

  $targets = @(
    "Supabase CLI:supabase",
    "Supabase CLI",
    "supabase"
  )

  foreach ($target in $targets) {
    try {
      $token = [WinCredReaderHttpsMigration]::Read($target)
      if ($token -and $token.Trim()) {
        return $token.Trim()
      }
    }
    catch {}
  }

  return $null
}

function Invoke-SupabaseSql {
  param(
    [Parameter(Mandatory = $true)][string]$Token,
    [Parameter(Mandatory = $true)][string]$Sql
  )

  $headers = @{
    Authorization = "Bearer $Token"
    Accept = "application/json"
  }

  $body = @{
    query = $Sql
    read_only = $false
  } | ConvertTo-Json -Depth 5 -Compress

  return Invoke-RestMethod `
    -Method Post `
    -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/query" `
    -Headers $headers `
    -ContentType "application/json; charset=utf-8" `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
    -TimeoutSec 120
}

Write-Host ""
Write-Host "=== APPLY MIGRATION OVER HTTPS ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectRef"
Write-Host "Migration: $MigrationFile"

if (-not (Test-Path $MigrationFile)) {
  Write-Host "ERROR: migration file not found." -ForegroundColor Red
  exit 1
}

$token = Get-SupabaseAccessToken
if (-not $token) {
  Write-Host "ERROR: Supabase access token was not found." -ForegroundColor Red
  Write-Host "Run: supabase login"
  Write-Host "Then run this script again."
  exit 1
}

$migrationSql = Get-Content $MigrationFile -Raw -Encoding UTF8

try {
  Write-Host ""
  Write-Host "Applying table, policies, grants..." -ForegroundColor Yellow
  Invoke-SupabaseSql -Token $token -Sql $migrationSql | Out-Null
  Write-Host "Schema SQL applied." -ForegroundColor Green

  $historySql = @"
create schema if not exists supabase_migrations;

create table if not exists supabase_migrations.schema_migrations (
  version text not null primary key,
  statements text[],
  name text
);

insert into supabase_migrations.schema_migrations(version, name, statements)
values (
  '20260627135000',
  'create_teacher_students',
  array['Applied over Supabase Management API']
)
on conflict (version) do update
set name = excluded.name,
    statements = excluded.statements;
"@

  Write-Host "Recording migration history..." -ForegroundColor Yellow
  Invoke-SupabaseSql -Token $token -Sql $historySql | Out-Null
  Write-Host "Migration history recorded." -ForegroundColor Green

  $verifySql = @"
select
  to_regclass('public.teacher_students')::text as table_name,
  exists (
    select 1
    from supabase_migrations.schema_migrations
    where version = '20260627135000'
  ) as migration_recorded;
"@

  Write-Host "Verifying..." -ForegroundColor Yellow
  $result = Invoke-SupabaseSql -Token $token -Sql $verifySql

  Write-Host ""
  Write-Host "SUCCESS." -ForegroundColor Green
  $result | ConvertTo-Json -Depth 10
}
catch {
  Write-Host ""
  Write-Host "HTTPS MIGRATION FAILED." -ForegroundColor Red
  Write-Host $_.Exception.Message
  if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
    Write-Host $_.ErrorDetails.Message
  }
  exit 1
}
