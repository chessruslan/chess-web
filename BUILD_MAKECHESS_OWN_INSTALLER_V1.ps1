$ErrorActionPreference = "Stop"

$Version = if ($env:MAKECHESS_RELEASE_VERSION) { $env:MAKECHESS_RELEASE_VERSION } else { "1.0.0" }
$Root = (Get-Location).Path
$ReleaseDir = Join-Path $Root "build\windows\x64\runner\Release"
$MainExe = Join-Path $ReleaseDir "MakeChess.exe"
$Icon = Join-Path $Root "windows\runner\resources\app_icon.ico"
$DistDir = Join-Path $Root "dist"
$OutExe = Join-Path $DistDir ("MakeChess_Setup_" + $Version + ".exe")

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " MAKECHESS - OWN WINDOWS INSTALLER $Version" -ForegroundColor Cyan
Write-Host " NO INNO SETUP. NO THIRD-PARTY INSTALLER." -ForegroundColor Cyan
Write-Host " EXISTING RELEASE IS PACKAGED AS-IS." -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path (Join-Path $Root ".git"))) {
    Fail "Run this script from the MakeChess project root."
}
if (-not (Test-Path $MainExe)) {
    Fail "MakeChess.exe not found. Expected: build\windows\x64\runner\Release\MakeChess.exe"
}
if (-not (Test-Path (Join-Path $ReleaseDir "flutter_windows.dll"))) {
    Fail "flutter_windows.dll not found in Release folder."
}
if (-not (Test-Path (Join-Path $ReleaseDir "data"))) {
    Fail "Flutter data folder not found in Release folder."
}
if (-not (Test-Path $Icon)) {
    $Icon = Join-Path $Root "installer\MakeChess.ico"
}
if (-not (Test-Path $Icon)) {
    Fail "MakeChess icon not found."
}

$cscCandidates = @(
    (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
    (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
)
$Csc = $cscCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Csc) {
    Fail ".NET Framework C# compiler was not found in Windows."
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

$Work = Join-Path $env:TEMP ("MakeChessOwnInstaller_" + [guid]::NewGuid().ToString("N"))
$PayloadDir = Join-Path $Work "payload"
$ZipPath = Join-Path $Work "MakeChessPayload.zip"
$InstallerCs = Join-Path $Work "MakeChessInstaller.cs"
$UninstallerCs = Join-Path $Work "MakeChessUninstaller.cs"

New-Item -ItemType Directory -Force -Path $PayloadDir | Out-Null

try {
    Write-Host "[1/5] Copy existing Windows Release..." -ForegroundColor Yellow
    Copy-Item (Join-Path $ReleaseDir "*") $PayloadDir -Recurse -Force

    $uninstallerSource = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

namespace MakeChessUninstaller
{
    static class Program
    {
        const string AppName = "MakeChess";

        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            DialogResult result = MessageBox.Show(
                IsRussian()
                    ? "Удалить MakeChess с этого компьютера?\r\n\r\nЛичные данные и настройки в AppData удалены не будут."
                    : "Remove MakeChess from this computer?\r\n\r\nPersonal data and settings stored in AppData will not be deleted.",
                IsRussian() ? "Удаление MakeChess" : "Uninstall MakeChess",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (result != DialogResult.Yes) return;

            try
            {
                foreach (Process p in Process.GetProcessesByName("MakeChess"))
                {
                    try
                    {
                        p.CloseMainWindow();
                        if (!p.WaitForExit(2500)) p.Kill();
                    }
                    catch { }
                }

                string desktopLink = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                    "MakeChess.lnk");
                string startLink = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.Programs),
                    "MakeChess.lnk");

                TryDelete(desktopLink);
                TryDelete(startLink);

                try
                {
                    Registry.CurrentUser.DeleteSubKeyTree(
                        @"Software\Microsoft\Windows\CurrentVersion\Uninstall\MakeChess",
                        false);
                }
                catch { }

                string installDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(
                    Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

                MessageBox.Show(
                    IsRussian()
                        ? "MakeChess удалён.\r\n\r\nВаши личные данные сохранены."
                        : "MakeChess has been removed.\r\n\r\nYour personal data has been preserved.",
                    "MakeChess",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "cmd.exe";
                psi.Arguments = "/C ping 127.0.0.1 -n 3 > nul & rmdir /S /Q \"" +
                                installDir.Replace("\"", "\"\"") + "\"";
                psi.CreateNoWindow = true;
                psi.UseShellExecute = false;
                psi.WindowStyle = ProcessWindowStyle.Hidden;
                Process.Start(psi);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    (IsRussian() ? "Ошибка удаления:\r\n" : "Uninstall error:\r\n") + ex.Message,
                    "MakeChess",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
        }

        static bool IsRussian()
        {
            try
            {
                return System.Globalization.CultureInfo.CurrentUICulture
                    .TwoLetterISOLanguageName.Equals("ru", StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        static void TryDelete(string path)
        {
            try
            {
                if (File.Exists(path)) File.Delete(path);
            }
            catch { }
        }
    }
}
'@

    [System.IO.File]::WriteAllText(
        $UninstallerCs,
        $uninstallerSource,
        (New-Object System.Text.UTF8Encoding($true))
    )

    Write-Host "[2/5] Build our own uninstaller..." -ForegroundColor Yellow
    $uninstallerExe = Join-Path $PayloadDir "MakeChess_Uninstall.exe"
    $unArgs = @(
        "/nologo",
        "/target:winexe",
        "/optimize+",
        "/platform:anycpu",
        "/win32icon:$Icon",
        "/out:$uninstallerExe",
        "/r:System.dll",
        "/r:System.Core.dll",
        "/r:System.Drawing.dll",
        "/r:System.Windows.Forms.dll",
        $UninstallerCs
    )
    & $Csc $unArgs
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $uninstallerExe)) {
        Fail "Own uninstaller compilation failed."
    }

    Write-Host "[3/5] Pack Release files into internal ZIP..." -ForegroundColor Yellow
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $PayloadDir,
        $ZipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    $installerSource = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace MakeChessInstaller
{
    public class InstallerForm : Form
    {
        const string AppName = "MakeChess";
        const string AppVersion = "1.0.0";
        const string ResourceName = "MakeChessPayload";

        readonly bool ru;
        readonly TextBox pathBox;
        readonly CheckBox desktopCheck;
        readonly CheckBox launchCheck;
        readonly ProgressBar progress;
        readonly Label status;
        readonly Button installButton;
        readonly Button browseButton;

        public InstallerForm()
        {
            ru = IsRussian();

            Text = ru ? "Установка MakeChess" : "MakeChess Setup";
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            MinimizeBox = true;
            ClientSize = new Size(660, 430);
            BackColor = Color.FromArgb(246, 248, 252);
            Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

            Panel header = new Panel();
            header.Dock = DockStyle.Top;
            header.Height = 135;
            header.BackColor = Color.FromArgb(24, 38, 62);
            Controls.Add(header);

            PictureBox logo = new PictureBox();
            logo.Left = 28;
            logo.Top = 26;
            logo.Width = 72;
            logo.Height = 72;
            logo.SizeMode = PictureBoxSizeMode.Zoom;
            try { logo.Image = Icon.ToBitmap(); } catch { }
            header.Controls.Add(logo);

            Label title = new Label();
            title.AutoSize = true;
            title.Left = 120;
            title.Top = 28;
            title.ForeColor = Color.White;
            title.Font = new Font("Segoe UI Semibold", 25F, FontStyle.Bold);
            title.Text = "MakeChess";
            header.Controls.Add(title);

            Label subtitle = new Label();
            subtitle.AutoSize = true;
            subtitle.Left = 123;
            subtitle.Top = 79;
            subtitle.ForeColor = Color.FromArgb(210, 220, 234);
            subtitle.Font = new Font("Segoe UI", 10F);
            subtitle.Text = ru
                ? "Шахматная платформа для Windows  •  Версия " + AppVersion
                : "Chess platform for Windows  •  Version " + AppVersion;
            header.Controls.Add(subtitle);

            Label intro = new Label();
            intro.Left = 32;
            intro.Top = 158;
            intro.Width = 595;
            intro.Height = 48;
            intro.ForeColor = Color.FromArgb(42, 50, 62);
            intro.Font = new Font("Segoe UI", 10F);
            intro.Text = ru
                ? "Установщик скопирует готовую программу MakeChess на этот компьютер. Личные данные и настройки при обновлении сохраняются."
                : "Setup will copy the ready MakeChess application to this computer. Personal data and settings are preserved during updates.";
            Controls.Add(intro);

            Label folderLabel = new Label();
            folderLabel.AutoSize = true;
            folderLabel.Left = 32;
            folderLabel.Top = 218;
            folderLabel.Text = ru ? "Папка установки:" : "Install folder:";
            Controls.Add(folderLabel);

            pathBox = new TextBox();
            pathBox.Left = 32;
            pathBox.Top = 242;
            pathBox.Width = 500;
            pathBox.Height = 28;
            pathBox.Text = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "MakeChess");
            Controls.Add(pathBox);

            browseButton = new Button();
            browseButton.Left = 545;
            browseButton.Top = 240;
            browseButton.Width = 82;
            browseButton.Height = 29;
            browseButton.Text = ru ? "Обзор..." : "Browse...";
            browseButton.Click += BrowseClick;
            Controls.Add(browseButton);

            desktopCheck = new CheckBox();
            desktopCheck.AutoSize = true;
            desktopCheck.Left = 32;
            desktopCheck.Top = 286;
            desktopCheck.Checked = true;
            desktopCheck.Text = ru ? "Создать ярлык на рабочем столе" : "Create a desktop shortcut";
            Controls.Add(desktopCheck);

            launchCheck = new CheckBox();
            launchCheck.AutoSize = true;
            launchCheck.Left = 32;
            launchCheck.Top = 316;
            launchCheck.Checked = true;
            launchCheck.Text = ru ? "Запустить MakeChess после установки" : "Launch MakeChess after setup";
            Controls.Add(launchCheck);

            progress = new ProgressBar();
            progress.Left = 32;
            progress.Top = 352;
            progress.Width = 470;
            progress.Height = 19;
            progress.Minimum = 0;
            progress.Maximum = 100;
            progress.Value = 0;
            Controls.Add(progress);

            status = new Label();
            status.Left = 32;
            status.Top = 377;
            status.Width = 470;
            status.Height = 28;
            status.ForeColor = Color.FromArgb(95, 104, 117);
            status.Text = ru ? "Готово к установке." : "Ready to install.";
            Controls.Add(status);

            installButton = new Button();
            installButton.Left = 515;
            installButton.Top = 344;
            installButton.Width = 112;
            installButton.Height = 42;
            installButton.FlatStyle = FlatStyle.Flat;
            installButton.FlatAppearance.BorderSize = 0;
            installButton.BackColor = Color.FromArgb(39, 102, 214);
            installButton.ForeColor = Color.White;
            installButton.Font = new Font("Segoe UI Semibold", 10F, FontStyle.Bold);
            installButton.Text = ru ? "Установить" : "Install";
            installButton.Click += async delegate { await InstallAsync(); };
            Controls.Add(installButton);
        }

        void BrowseClick(object sender, EventArgs e)
        {
            using (FolderBrowserDialog dialog = new FolderBrowserDialog())
            {
                dialog.Description = ru ? "Выберите папку установки MakeChess" : "Choose MakeChess install folder";
                dialog.SelectedPath = pathBox.Text;
                if (dialog.ShowDialog(this) == DialogResult.OK)
                    pathBox.Text = dialog.SelectedPath;
            }
        }

        async Task InstallAsync()
        {
            string installDir = pathBox.Text.Trim();
            if (installDir.Length == 0)
            {
                MessageBox.Show(
                    ru ? "Укажите папку установки." : "Choose an install folder.",
                    "MakeChess",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }

            Process[] running = Process.GetProcessesByName("MakeChess");
            if (running.Length > 0)
            {
                DialogResult close = MessageBox.Show(
                    ru
                        ? "MakeChess сейчас запущен. Закрыть программу и продолжить установку?"
                        : "MakeChess is currently running. Close it and continue setup?",
                    "MakeChess",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Question);

                if (close != DialogResult.Yes) return;

                foreach (Process p in running)
                {
                    try
                    {
                        p.CloseMainWindow();
                        if (!p.WaitForExit(3000)) p.Kill();
                    }
                    catch { }
                }
            }

            installButton.Enabled = false;
            browseButton.Enabled = false;
            pathBox.Enabled = false;
            desktopCheck.Enabled = false;
            launchCheck.Enabled = false;

            string tempRoot = Path.Combine(
                Path.GetTempPath(),
                "MakeChessSetup_" + Guid.NewGuid().ToString("N"));
            string extracted = Path.Combine(tempRoot, "payload");
            string zipFile = Path.Combine(tempRoot, "payload.zip");

            try
            {
                SetProgress(5, ru ? "Подготовка..." : "Preparing...");
                Directory.CreateDirectory(extracted);

                await Task.Run(delegate
                {
                    Assembly asm = Assembly.GetExecutingAssembly();
                    using (Stream input = asm.GetManifestResourceStream(ResourceName))
                    {
                        if (input == null)
                            throw new Exception("Embedded MakeChess payload was not found.");

                        using (FileStream output = new FileStream(
                            zipFile, FileMode.Create, FileAccess.Write, FileShare.None))
                        {
                            input.CopyTo(output);
                        }
                    }
                });

                SetProgress(25, ru ? "Распаковка файлов..." : "Extracting files...");

                await Task.Run(delegate
                {
                    ZipFile.ExtractToDirectory(zipFile, extracted);
                });

                SetProgress(55, ru ? "Установка MakeChess..." : "Installing MakeChess...");

                await Task.Run(delegate
                {
                    if (Directory.Exists(installDir))
                        Directory.Delete(installDir, true);

                    Directory.CreateDirectory(installDir);
                    CopyDirectory(extracted, installDir);
                });

                string exe = Path.Combine(installDir, "MakeChess.exe");
                string uninstall = Path.Combine(installDir, "MakeChess_Uninstall.exe");

                if (!File.Exists(exe))
                    throw new Exception("Installed MakeChess.exe was not found.");

                SetProgress(78, ru ? "Создание ярлыков..." : "Creating shortcuts...");

                string startLink = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.Programs),
                    "MakeChess.lnk");
                CreateShortcut(startLink, exe, installDir, exe);

                string desktopLink = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                    "MakeChess.lnk");

                if (desktopCheck.Checked)
                    CreateShortcut(desktopLink, exe, installDir, exe);
                else
                    TryDelete(desktopLink);

                SetProgress(90, ru ? "Регистрация приложения..." : "Registering application...");
                RegisterUninstall(installDir, exe, uninstall);

                SetProgress(100, ru ? "MakeChess установлен." : "MakeChess installed.");

                MessageBox.Show(
                    ru
                        ? "MakeChess успешно установлен!\r\n\r\nПрограмма готова к работе."
                        : "MakeChess was installed successfully!\r\n\r\nThe application is ready.",
                    "MakeChess",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);

                if (launchCheck.Checked)
                {
                    ProcessStartInfo psi = new ProcessStartInfo();
                    psi.FileName = exe;
                    psi.WorkingDirectory = installDir;
                    psi.UseShellExecute = true;
                    Process.Start(psi);
                }

                Close();
            }
            catch (Exception ex)
            {
                SetProgress(0, ru ? "Установка остановлена." : "Setup stopped.");
                MessageBox.Show(
                    (ru ? "Ошибка установки:\r\n\r\n" : "Setup error:\r\n\r\n") + ex.Message,
                    "MakeChess",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);

                installButton.Enabled = true;
                browseButton.Enabled = true;
                pathBox.Enabled = true;
                desktopCheck.Enabled = true;
                launchCheck.Enabled = true;
            }
            finally
            {
                try
                {
                    if (Directory.Exists(tempRoot))
                        Directory.Delete(tempRoot, true);
                }
                catch { }
            }
        }

        void SetProgress(int value, string text)
        {
            if (value < progress.Minimum) value = progress.Minimum;
            if (value > progress.Maximum) value = progress.Maximum;
            progress.Value = value;
            status.Text = text;
            status.Refresh();
            progress.Refresh();
        }

        static void CopyDirectory(string sourceDir, string targetDir)
        {
            foreach (string dir in Directory.GetDirectories(
                sourceDir, "*", SearchOption.AllDirectories))
            {
                Directory.CreateDirectory(
                    dir.Replace(sourceDir, targetDir));
            }

            foreach (string file in Directory.GetFiles(
                sourceDir, "*", SearchOption.AllDirectories))
            {
                string dest = file.Replace(sourceDir, targetDir);
                string parent = Path.GetDirectoryName(dest);
                if (!Directory.Exists(parent))
                    Directory.CreateDirectory(parent);
                File.Copy(file, dest, true);
            }
        }

        static void CreateShortcut(string shortcutPath, string targetPath, string workingDir, string iconPath)
        {
            string parent = Path.GetDirectoryName(shortcutPath);
            if (!Directory.Exists(parent)) Directory.CreateDirectory(parent);

            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(shellType);
            object shortcut = shellType.InvokeMember(
                "CreateShortcut",
                BindingFlags.InvokeMethod,
                null,
                shell,
                new object[] { shortcutPath });

            Type t = shortcut.GetType();
            t.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { targetPath });
            t.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { workingDir });
            t.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut, new object[] { iconPath + ",0" });
            t.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { "MakeChess" });
            t.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
        }

        static void RegisterUninstall(string installDir, string exe, string uninstall)
        {
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Uninstall\MakeChess"))
            {
                key.SetValue("DisplayName", "MakeChess");
                key.SetValue("DisplayVersion", AppVersion);
                key.SetValue("Publisher", "MakeChess");
                key.SetValue("InstallLocation", installDir);
                key.SetValue("DisplayIcon", exe);
                key.SetValue("URLInfoAbout", "https://makechess.com");
                key.SetValue("UninstallString", "\"" + uninstall + "\"");
                key.SetValue("QuietUninstallString", "\"" + uninstall + "\"");
                key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
            }
        }

        static bool IsRussian()
        {
            try
            {
                return System.Globalization.CultureInfo.CurrentUICulture
                    .TwoLetterISOLanguageName.Equals("ru", StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        static void TryDelete(string path)
        {
            try
            {
                if (File.Exists(path)) File.Delete(path);
            }
            catch { }
        }
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new InstallerForm());
        }
    }
}
'@

    [System.IO.File]::WriteAllText(
        $InstallerCs,
        $installerSource,
        (New-Object System.Text.UTF8Encoding($true))
    )

    Write-Host "[4/5] Build MakeChess_Setup_$Version.exe..." -ForegroundColor Yellow
    if (Test-Path $OutExe) { Remove-Item $OutExe -Force }

    $installArgs = @(
        "/nologo",
        "/target:winexe",
        "/optimize+",
        "/platform:anycpu",
        "/win32icon:$Icon",
        "/out:$OutExe",
        "/resource:$ZipPath,MakeChessPayload",
        "/r:System.dll",
        "/r:System.Core.dll",
        "/r:System.Drawing.dll",
        "/r:System.Windows.Forms.dll",
        "/r:System.IO.Compression.dll",
        "/r:System.IO.Compression.FileSystem.dll",
        $InstallerCs
    )
    & $Csc $installArgs
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $OutExe)) {
        Fail "Own installer compilation failed."
    }

    Write-Host "[5/5] Verify installer file..." -ForegroundColor Yellow
    $file = Get-Item $OutExe
    $hash = (Get-FileHash $OutExe -Algorithm SHA256).Hash

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " OWN MAKECHESS INSTALLER READY" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ("FILE: " + $file.FullName) -ForegroundColor Green
    Write-Host ("SIZE: " + [Math]::Round($file.Length / 1MB, 2) + " MB") -ForegroundColor Green
    Write-Host ("SHA256: " + $hash) -ForegroundColor Green
    Write-Host ""
    Write-Host "MakeChess was NOT rebuilt." -ForegroundColor Green
    Write-Host "Existing Release folder was packaged as-is." -ForegroundColor Green
    Write-Host "Inno Setup was NOT used." -ForegroundColor Green
    Write-Host "PUBLISH_MAKECHESS.cmd was NOT touched." -ForegroundColor Green
    Write-Host "secrets.dart was NOT touched." -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""

    if ($env:MAKECHESS_RELEASE_AUTOMATED -ne "1") { explorer.exe /select,"$OutExe" }
}
finally {
    try {
        if (Test-Path $Work) {
            Remove-Item $Work -Recurse -Force
        }
    } catch { }
}
