using HSVoice.Core;

namespace HSVoice.Core.Tests;

/// <summary>macOS版 TextPostProcessorTests.swift から移植。両OSで同じ挙動を保証する。</summary>
public class TextPostProcessorTests
{
    [Fact]
    public void NormalizesWhitespaceAndPreservesParagraphs()
    {
        var result = TextPostProcessor.Process(
            "  hello    world  \n\n\n  second line  ", "en-US");
        Assert.Equal("Hello world\n\nSecond line", result);
    }

    [Fact]
    public void RemovesWhitespaceBeforeJapanesePunctuation()
    {
        var result = TextPostProcessor.Process("これは テストです 。 次です ！", "ja-JP");
        Assert.Equal("これはテストです。次です！", result);
    }

    [Fact]
    public void KeepsSpacingAroundLatinWordsAndNumbersInJapanese()
    {
        var result = TextPostProcessor.Process("今日 の 会議 は Zoom で 15 時 から です", "ja-JP");
        Assert.Equal("今日の会議は Zoom で 15 時からです", result);
    }

    [Fact]
    public void TightensJapaneseBrackets()
    {
        var result = TextPostProcessor.Process("彼は 「 これ 」 と 言った 。", "ja-JP");
        Assert.Equal("彼は「これ」と言った。", result);
    }

    [Fact]
    public void DropsCommaStrandedByASpokenLineBreak()
    {
        var result = TextPostProcessor.Process("これはテストですが、改行して次の話です", "ja-JP");
        Assert.Equal("これはテストですが\n次の話です", result);
    }

    [Fact]
    public void KeepsTheLineBreakWhenTheCommaFollowsTheSpokenCommand()
    {
        var result = TextPostProcessor.Process("これはテストですが改行して、次の話です", "ja-JP");
        Assert.Equal("これはテストですが\n次の話です", result);
    }

    [Fact]
    public void CapitalizesSentencesAfterAFullStop()
    {
        var result = TextPostProcessor.Process("hello world . next one !", "en-US");
        Assert.Equal("Hello world. Next one!", result);
    }

    [Fact]
    public void LeavesDecimalsAndDomainsIntact()
    {
        Assert.Equal(
            "The file is 3.5 inches wide. It fits",
            TextPostProcessor.Process("the file is 3.5 inches wide. it fits", "en-US"));
        Assert.Equal(
            "Visit www.example.com for details",
            TextPostProcessor.Process("visit www.example.com for details", "en-US"));
    }

    [Fact]
    public void EmptyInputRemainsEmpty()
    {
        Assert.Equal("", TextPostProcessor.Process("   \n ", "ja-JP"));
    }

    [Fact]
    public void JapaneseSpokenLayoutCommands()
    {
        var result = TextPostProcessor.Process("最初です新しい段落次です改行最後です", "ja-JP");
        Assert.Equal("最初です\n\n次です\n最後です", result);
    }

    [Fact]
    public void EnglishSpokenLayoutCommands()
    {
        var result = TextPostProcessor.Process(
            "first paragraph new paragraph second line new line final thought", "en-US");
        Assert.Equal("First paragraph\n\nSecond line\nFinal thought", result);
    }

    [Fact]
    public void SpokenLayoutCommandsCanBeDisabled()
    {
        var input = "新しい段落について説明します";
        var result = TextPostProcessor.Process(input, "ja-JP", spokenCommandsEnabled: false);
        Assert.Equal(input, result);
    }
}
