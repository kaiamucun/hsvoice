using System.Reflection;

namespace HSVoice.Core.Tests;

/// <summary>xunit互換の最小Assert。オフライン環境でもテストを回すための自前実装。</summary>
public static class Assert
{
    public static void Equal(string expected, string actual)
    {
        if (!string.Equals(expected, actual, StringComparison.Ordinal))
        {
            throw new AssertFailedException(
                $"expected: {Printable(expected)}\n  actual:   {Printable(actual)}");
        }
    }

    public static void True(bool condition, string message = "expected true")
    {
        if (!condition) throw new AssertFailedException(message);
    }

    private static string Printable(string value) =>
        "\"" + value.Replace("\n", "\\n").Replace("\t", "\\t") + "\"";
}

public sealed class AssertFailedException : Exception
{
    public AssertFailedException(string message) : base(message) { }
}

[AttributeUsage(AttributeTargets.Method)]
public sealed class FactAttribute : Attribute { }

public static class TestRunner
{
    public static int Main()
    {
        var passed = 0;
        var failed = 0;

        var testClasses = Assembly.GetExecutingAssembly()
            .GetTypes()
            .Where(type => type.IsClass && type.Name.EndsWith("Tests", StringComparison.Ordinal));

        foreach (var testClass in testClasses)
        {
            var instance = Activator.CreateInstance(testClass);
            var methods = testClass
                .GetMethods(BindingFlags.Public | BindingFlags.Instance)
                .Where(method => method.GetCustomAttribute<FactAttribute>() is not null);

            foreach (var method in methods)
            {
                try
                {
                    method.Invoke(instance, null);
                    passed++;
                    Console.WriteLine($"  PASS {testClass.Name}.{method.Name}");
                }
                catch (TargetInvocationException error)
                {
                    failed++;
                    Console.WriteLine($"  FAIL {testClass.Name}.{method.Name}");
                    Console.WriteLine($"       {error.InnerException?.Message}");
                }
            }
        }

        Console.WriteLine($"\n{passed} passed, {failed} failed");
        return failed == 0 ? 0 : 1;
    }
}
