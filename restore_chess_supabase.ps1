param(
  [string]$ProjectRef = "chmebxirnmqgvdpwskhw",
  [int]$PollSeconds = 15,
  [int]$TimeoutMinutes = 30
)

$ErrorActionPreference = "Stop"

function Get-SupabaseAccessToken {
  if ($env:SUPABASE_ACCESS_TOKEN -and $env:SUPABASE_ACCESS_TOKEN.Trim()) {
    return $env:SUPABASE_ACCESS_TOKEN.Trim()
  }

  $possibleFiles = @(
    (Join-Path $HOME ".supabase\access-token"),
    (Join-Path $env:USERPROFILE ".supabase\access-token"),
    (Join-Path $env:APPDATA "supabase\access-token")
  ) | Select-Object -Unique

  foreach ($file in $possibleFiles) {
    if (Test-Path $file) {
      $value = (Get-Content $file -Raw).Trim()
      if ($value) { return $value }
    }
  }

  # Supabase CLI на Windows обычно хранит токен в Credential Manager
  # под именем "Supabase CLI:supabase".
  $source = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class WinCredReader
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

  try {
    if (-not ("WinCredReader" -as [type])) {
      Add-Type -TypeDefinition $source
    }

    foreach ($target in @(
      "Supabase CLI:supabase",
      "Supabase CLI",
      "supabase"
    )) {
      $token = [WinCredReader]::Read($target)
      if ($token -and $token.Trim()) {
        return $token.Trim()
      }
    }
  }
  catch {
    Write-Host "Не удалось прочитать Windows Credential Manager: $($_.Exception.Message)" -ForegroundColor Yellow
  }

  return $null
}

function Invoke-ManagementApi {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Body
  )

  $headers = @{
    Authorization = "Bearer $script:Token"
    Accept        = "application/json"
  }

  $uri = "https://api.supabase.com$Path"

  if ($Body) {
    return Invoke-RestMethod `
      -Method $Method `
      -Uri $uri `
      -Headers $headers `
      -ContentType "application/json" `
      -Body $Body
  }

  return Invoke-RestMethod `
    -Method $Method `
    -Uri $uri `
    -Headers $headers
}

Write-Host ""
Write-Host "=== ВОССТАНОВЛЕНИЕ SUPABASE ===" -ForegroundColor Cyan
Write-Host "Project ref: $ProjectRef"

$script:Token = Get-SupabaseAccessToken

if (-not $script:Token) {
  Write-Host ""
  Write-Host "ОШИБКА: токен Supabase CLI не найден." -ForegroundColor Red
  Write-Host "Выполни: supabase login"
  Write-Host "Затем снова запусти этот файл."
  exit 1
}

try {
  $project = Invoke-ManagementApi `
    -Method "GET" `
    -Path "/v1/projects/$ProjectRef"

  Write-Host "Текущий статус: $($project.status)" -ForegroundColor Yellow

  if ($project.status -eq "ACTIVE_HEALTHY") {
    Write-Host "Проект уже работает. Восстановление не требуется." -ForegroundColor Green
    exit 0
  }

  Write-Host ""
  Write-Host "Отправляю команду восстановления..." -ForegroundColor Cyan

  try {
    Invoke-ManagementApi `
      -Method "POST" `
      -Path "/v1/projects/$ProjectRef/restore" `
      -Body "{}" | Out-Null

    Write-Host "Команда восстановления принята." -ForegroundColor Green
  }
  catch {
    $message = $_.Exception.Message

    # Иногда повторный запрос возвращает конфликт, если восстановление уже идёт.
    if ($message -match "409|already|restor") {
      Write-Host "Восстановление уже запущено. Продолжаю проверку статуса." -ForegroundColor Yellow
    }
    else {
      throw
    }
  }

  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)

  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds $PollSeconds

    $project = Invoke-ManagementApi `
      -Method "GET" `
      -Path "/v1/projects/$ProjectRef"

    $status = [string]$project.status
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Статус: $status"

    if ($status -eq "ACTIVE_HEALTHY") {
      Write-Host ""
      Write-Host "ГОТОВО: проект восстановлен и работает." -ForegroundColor Green
      Write-Host "Теперь выполни:"
      Write-Host "  dart run tool/check_supabase.dart"
      exit 0
    }

    if ($status -match "FAILED|ERROR|UNHEALTHY") {
      Write-Host ""
      Write-Host "Восстановление завершилось ошибкой: $status" -ForegroundColor Red
      exit 2
    }
  }

  Write-Host ""
  Write-Host "Время ожидания закончилось, но восстановление может продолжаться на сервере." -ForegroundColor Yellow
  Write-Host "Повтори через несколько минут:"
  Write-Host "  supabase projects list --output json"
  exit 3
}
catch {
  Write-Host ""
  Write-Host "ОШИБКА MANAGEMENT API:" -ForegroundColor Red
  Write-Host $_.Exception.Message
  if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
    Write-Host $_.ErrorDetails.Message
  }
  exit 1
}
