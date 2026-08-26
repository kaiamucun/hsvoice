using Microsoft.Win32;

namespace HSVoice.App;

/// <summary>
/// ログイン時起動(HKCU Runキー)。管理者権限不要で、ユーザー単位に設定される。
/// macOS版 SMAppService の対応物。
/// </summary>
public static class StartupManager
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "HS Voice";

    public static bool IsEnabled
    {
        get
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath);
                return key?.GetValue(ValueName) is string;
            }
            catch
            {
                return false;
            }
        }
    }

    public static string? SetEnabled(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath);
            if (enabled)
            {
                var executable = Environment.ProcessPath
                    ?? throw new InvalidOperationException("実行ファイルのパスを取得できません");
                key.SetValue(ValueName, $"\"{executable}\"");
            }
            else
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
            }
            return null;
        }
        catch (Exception error)
        {
            return error.Message;
        }
    }
}
