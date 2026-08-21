param(
  [string]$ProjectRoot = "C:\SUPER_Makechess_Video_NEW_DISINE_4_Ocenka"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$Path = Join-Path $ProjectRoot "lib\ui\dialogs\admin_management_panel.dart"

if (-not (Test-Path -LiteralPath $Path)) {
  throw "SAFETY STOP: admin_management_panel.dart not found."
}

$text = [IO.File]::ReadAllText($Path)

if (-not $text.Contains("MAKECHESS_ADMIN_DELETE_V8_3_20260808")) {
  throw "SAFETY STOP: V8.3 marker not found. Nothing changed."
}

$bad = @"
  List<AdminTarget> _targets = <AdminTarget>[];
  List<AdminCaseRecord> _cases = <AdminCaseRecord>[];
  String? _archiveDeleteConfirmId;
  List<MakeChessMessage> _caseReplies = <MakeChessMessage>[];
"@

$good = @"
  List<AdminTarget> _targets = <AdminTarget>[];
  List<AdminCaseRecord> _cases = <AdminCaseRecord>[];
  List<MakeChessMessage> _caseReplies = <MakeChessMessage>[];
"@

$archiveOld = @"
class _AdminArchivePanelState extends State<AdminArchivePanel> {
  int _tab = 0;
  bool _showSettings = false;
  bool _loading = true;
  Map<String, bool> _settings = <String, bool>{};
  List<AdminCaseRecord> _cases = <AdminCaseRecord>[];

  String _t(String source) => MakeChessLocalization.phrase(source);
"@

$archiveNew = @"
class _AdminArchivePanelState extends State<AdminArchivePanel> {
  int _tab = 0;
  bool _showSettings = false;
  bool _loading = true;
  Map<String, bool> _settings = <String, bool>{};
  List<AdminCaseRecord> _cases = <AdminCaseRecord>[];
  String? _archiveDeleteConfirmId;

  String _t(String source) => MakeChessLocalization.phrase(source);
"@

if ($text.Contains("MAKECHESS_ADMIN_DELETE_FIELD_FIX_V8_3_1_20260808")) {
  Write-Host "ALREADY FIXED: V8.3.1" -ForegroundColor Green
  exit 0
}

if (-not $text.Contains($bad)) {
  throw "SAFETY STOP: expected misplaced field block was not found. Nothing changed."
}
if (-not $text.Contains($archiveOld)) {
  throw "SAFETY STOP: archive state anchor was not found. Nothing changed."
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = "$Path.ADMIN_DELETE_V8_3_1_$stamp.bak"
Copy-Item -LiteralPath $Path -Destination $backup -Force

try {
  Write-Host "[1/3] Moving archive confirmation field to the correct State class..." -ForegroundColor Cyan
  $text = $text.Replace($bad, $good)
  $text = $text.Replace(
    $archiveOld,
    "// MAKECHESS_ADMIN_DELETE_FIELD_FIX_V8_3_1_20260808`r`n" + $archiveNew
  )
  [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($false))

  Write-Host "[2/3] Running Dart formatter..." -ForegroundColor Cyan
  $dart = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -ne $dart) {
    & $dart.Source format $Path | Out-Host
    if ($LASTEXITCODE -ne 0) {
      throw "dart format failed."
    }
  }

  Write-Host "[3/3] Verifying declaration scope..." -ForegroundColor Cyan
  $check = [IO.File]::ReadAllText($Path)
  $archiveStart = $check.IndexOf("class _AdminArchivePanelState extends State<AdminArchivePanel>")
  if ($archiveStart -lt 0) { throw "Archive State class not found after patch." }
  $archiveTail = $check.Substring($archiveStart)
  $nextClass = $archiveTail.IndexOf("`nclass ", 10)
  if ($nextClass -gt 0) { $archiveTail = $archiveTail.Substring(0, $nextClass) }

  if (-not $archiveTail.Contains("String? _archiveDeleteConfirmId;")) {
    throw "Field is still missing inside _AdminArchivePanelState."
  }

  $managementStart = $check.IndexOf("class _AdminManagementPanelState extends State<AdminManagementPanel>")
  $archiveStart2 = $check.IndexOf("class _AdminArchivePanelState extends State<AdminArchivePanel>")
  $managementPart = $check.Substring($managementStart, $archiveStart2 - $managementStart)
  if ($managementPart.Contains("String? _archiveDeleteConfirmId;")) {
    throw "Field is still incorrectly declared inside _AdminManagementPanelState."
  }
}
catch {
  Write-Host "ERROR: restoring backup..." -ForegroundColor Red
  Copy-Item -LiteralPath $backup -Destination $Path -Force
  throw
}

Write-Host ""
Write-Host "DONE: ADMIN DELETE FIELD FIX V8.3.1 installed." -ForegroundColor Green
Write-Host "The field now belongs to _AdminArchivePanelState." -ForegroundColor Green
Write-Host "No publication was performed." -ForegroundColor Green
