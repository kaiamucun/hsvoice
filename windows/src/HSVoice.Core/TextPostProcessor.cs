using System.Text;
using System.Text.RegularExpressions;

namespace HSVoice.Core;

/// <summary>
/// macOS版 TextPostProcessor.swift の忠実な移植。
/// 認識結果の整形(空白正規化・CJK句読点の詰め・音声レイアウトコマンド・文頭大文字化)を行う。
/// 挙動を変える場合は、macOS版と両方を同時に変更すること。
/// </summary>
public static class TextPostProcessor
{
    /// <summary>
    /// スペースがCJK文字の「間」にあるか(=認識エンジンの副産物であり実際の空白ではない)を
    /// 判定するための文字クラス。ラテン語の単語と数字は意図的に除外している:
    /// 日本語文中のそれらの前後のスペースは正しい空白であり、残さなければならない。
    /// .NETの正規表現はスクリプト名(\p{Han})ではなく名前付きブロックを使う。
    /// </summary>
    private const string Cjk =
        @"[\p{IsCJKUnifiedIdeographs}\p{IsCJKUnifiedIdeographsExtensionA}" +
        @"\p{IsCJKCompatibilityIdeographs}\p{IsHiragana}\p{IsKatakana}" +
        "ー々〆〤、。，．！？：；（）「」『』【】〔〕・…〜]";

    /// <summary>スペースとタブのみ — 改行は決して含めない(音声コマンドが入れた改行を守るため)。</summary>
    private const string HorizontalSpace = "[ \t　]";

    private static class Patterns
    {
        public static readonly Regex HorizontalWhitespace = new(@"[ \t]+", RegexOptions.Compiled);
        public static readonly Regex PaddedNewline = new(@" *\n *", RegexOptions.Compiled);
        public static readonly Regex ExcessBlankLines = new(@"\n{3,}", RegexOptions.Compiled);

        // 日本語 / 中国語
        public static readonly Regex SpaceBeforeCJKPunctuation =
            new(HorizontalSpace + "+([、。！？：；，])", RegexOptions.Compiled);
        public static readonly Regex SpaceAfterOpeningBracket =
            new("([（「『【〔])" + HorizontalSpace + "+", RegexOptions.Compiled);
        public static readonly Regex SpaceBeforeClosingBracket =
            new(HorizontalSpace + "+([）」』】〕])", RegexOptions.Compiled);
        public static readonly Regex SpaceBetweenCJK =
            new("(?<=" + Cjk + ")" + HorizontalSpace + "+(?=" + Cjk + ")", RegexOptions.Compiled);
        public static readonly Regex CommaBeforeNewline = new("[、，,][ \t]*\n", RegexOptions.Compiled);
        public static readonly Regex CommaAfterNewline = new("\n[ \t]*[、，,]", RegexOptions.Compiled);

        // ラテン文字圏
        public static readonly Regex SpaceBeforeLatinPunctuation =
            new(HorizontalSpace + @"+([.,!?;:])", RegexOptions.Compiled);

        // 音声レイアウトコマンド
        public static readonly Regex JapaneseParagraph = new("(新しい段落|次の段落|段落を変えて)", RegexOptions.Compiled);
        public static readonly Regex JapaneseNewline = new("(改行して|改行)", RegexOptions.Compiled);
        public static readonly Regex EnglishParagraph =
            new(@"\b(new paragraph|next paragraph)\b", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        public static readonly Regex EnglishNewline =
            new(@"\b(new line|line break)\b", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    }

    public static string Process(
        string input,
        string localeIdentifier,
        bool spokenCommandsEnabled = true)
    {
        var text = input.Replace('\u00a0', ' ').Trim();

        if (spokenCommandsEnabled)
        {
            text = ApplySpokenFormattingCommands(text, localeIdentifier);
        }

        text = Patterns.HorizontalWhitespace.Replace(text, " ");
        text = Patterns.PaddedNewline.Replace(text, "\n");
        text = Patterns.ExcessBlankLines.Replace(text, "\n\n");

        if (UsesCJKSpacing(localeIdentifier))
        {
            text = ApplyCJKSpacing(text);
        }
        else
        {
            text = Patterns.SpaceBeforeLatinPunctuation.Replace(text, "$1");
            text = CapitalizingSentences(text);
        }

        return text.Trim();
    }

    private static bool UsesCJKSpacing(string localeIdentifier) =>
        localeIdentifier.StartsWith("ja", StringComparison.Ordinal)
        || localeIdentifier.StartsWith("zh", StringComparison.Ordinal);

    private static string ApplyCJKSpacing(string source)
    {
        var text = Patterns.SpaceBeforeCJKPunctuation.Replace(source, "$1");
        text = Patterns.SpaceAfterOpeningBracket.Replace(text, "$1");
        text = Patterns.SpaceBeforeClosingBracket.Replace(text, "$1");

        // 認識エンジンは日本語をスペース区切りの塊で返すことがある。CJK文字に両側を挟まれた
        // スペースは決して意図されたものではなく、ラテン語や数字の隣のスペースは意図されたもの。
        text = Patterns.SpaceBetweenCJK.Replace(text, "");

        // 発話中の「改行して」は、話者が残すつもりのない読点の直後に来ることが多い
        // (「〜ですが、改行して〜」)。放置すると行末・行頭に句読点が取り残される。
        text = Patterns.CommaBeforeNewline.Replace(text, "\n");
        text = Patterns.CommaAfterNewline.Replace(text, "\n");
        return text;
    }

    private static string ApplySpokenFormattingCommands(string source, string localeIdentifier)
    {
        var text = source;
        if (localeIdentifier.StartsWith("ja", StringComparison.Ordinal))
        {
            text = Patterns.JapaneseParagraph.Replace(text, "\n\n");
            text = Patterns.JapaneseNewline.Replace(text, "\n");
        }
        else if (localeIdentifier.StartsWith("en", StringComparison.Ordinal))
        {
            text = Patterns.EnglishParagraph.Replace(text, "\n\n");
            text = Patterns.EnglishNewline.Replace(text, "\n");
        }
        return text;
    }

    /// <summary>
    /// すべての行頭と、終止符に続く各文の先頭を大文字化する。
    /// 境界には句読点の後の空白を要求するので、URLや小数("3.5")は無傷で残る。
    /// </summary>
    private static string CapitalizingSentences(string source)
    {
        var result = new StringBuilder(source.Length);
        var startsSentence = true;
        var followsTerminator = false;

        foreach (var rune in source.EnumerateRunes())
        {
            if (startsSentence && Rune.IsLetter(rune) && Rune.IsLower(rune))
            {
                result.Append(Rune.ToUpperInvariant(rune));
                startsSentence = false;
                followsTerminator = false;
                continue;
            }

            if (Rune.IsWhiteSpace(rune))
            {
                if (followsTerminator || rune.Value == '\n' || rune.Value == '\r')
                {
                    startsSentence = true;
                }
            }
            else
            {
                startsSentence = false;
                followsTerminator = rune.Value == '.' || rune.Value == '!' || rune.Value == '?';
            }
            result.Append(rune);
        }

        return result.ToString();
    }
}
