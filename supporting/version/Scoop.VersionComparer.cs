using System;
using System.Collections.Generic;

namespace Scoop
{
    /// <summary>
    /// Orders the version strings Scoop manifests carry.
    /// <para>
    /// Not SemVer 2.0, on purpose: manifests contain versions like "4.15_BETA2",
    /// "25.0.0-36.0.LTS" and "2019-01-01", and the app cache is already ordered by
    /// these rules.
    /// </para>
    /// </summary>
    public static class VersionComparer
    {
        private readonly struct Part
        {
            public readonly bool IsNum;
            public readonly long Num;
            public readonly string Text;

            public Part(string text)
            {
                Text = text;
                IsNum = false;
                Num = 0;

                long num = 0;
                for (int i = 0; i < text.Length; i++)
                {
                    char digit = text[i];
                    if (digit < '0' || digit > '9')
                    {
                        return;
                    }
                    // An out-of-range number is not a number, the same as long.TryParse.
                    if (num > (long.MaxValue - (digit - '0')) / 10)
                    {
                        return;
                    }
                    num = num * 10 + (digit - '0');
                }
                if (text.Length > 0)
                {
                    IsNum = true;
                    Num = num;
                }
            }
        }

        /// <summary>Positive when <paramref name="difference"/> is newer, negative when older.</summary>
        public static int Compare(string reference, string difference)
        {
            return CompareVersion(reference, difference, false);
        }

        /// <summary>
        /// Same, with the UPDATE_NIGHTLY rule: when both versions start with
        /// "nightly", a bare one means the newest build and two dated ones compare by
        /// date. Without it a nightly pair is equal.
        /// </summary>
        public static int Compare(string reference, string difference, bool updateNightly)
        {
            return CompareVersion(reference, difference, updateNightly);
        }

        private static int CompareVersion(string reference, string difference, bool updateNightly)
        {
            // PowerShell binds $null to '' for a [String] parameter, so a missing value must not throw.
            reference ??= string.Empty;
            difference ??= string.Empty;

            // Use '+' sign as post-release, see https://github.com/ScoopInstaller/Scoop/pull/3721#issuecomment-553718093
            string referenceText = reference.IndexOf('+') >= 0 ? reference.Replace('+', '-') : reference;
            string differenceText = difference.IndexOf('+') >= 0 ? difference.Replace('+', '-') : difference;

            if (differenceText == referenceText)
            {
                return 0;
            }

            List<Part> referenceParts = Split(referenceText, '-');
            List<Part> differenceParts = Split(differenceText, '-');

            // Nightly is a rule about the whole version, decided once here and never inside the recursion.
            if (referenceParts.Count > 0 && differenceParts.Count > 0
                && string.Equals(referenceParts[0].Text, "nightly", StringComparison.OrdinalIgnoreCase)
                && string.Equals(differenceParts[0].Text, "nightly", StringComparison.OrdinalIgnoreCase))
            {
                if (!updateNightly)
                {
                    return 0;
                }
                string referenceDate = referenceParts.Count > 1 ? referenceParts[1].Text : null;
                string differenceDate = differenceParts.Count > 1 ? differenceParts[1].Text : null;
                if (referenceDate == null && differenceDate == null)
                {
                    return 0;
                }
                if (referenceDate == null)
                {
                    return -1;
                }
                if (differenceDate == null)
                {
                    return 1;
                }
                return Math.Sign(CompareDates(referenceDate, differenceDate));
            }

            return CompareSegments(referenceParts, differenceParts);
        }

        private static int CompareSegments(List<Part> reference, List<Part> difference)
        {
            int count = Math.Max(reference.Count, difference.Count);
            for (int i = 0; i < count; i++)
            {
                // '1.1-alpha' is less then '1.1'
                if (i >= reference.Count)
                {
                    return IsPreRelease(difference[i].Text) ? -1 : 1;
                }
                // '1.1' is greater then '1.1-beta'
                if (i >= difference.Count)
                {
                    return IsPreRelease(reference[i].Text) ? 1 : -1;
                }

                if (reference[i].Text.IndexOf('.') >= 0 || difference[i].Text.IndexOf('.') >= 0)
                {
                    int result = CompareSplit(reference[i].Text, difference[i].Text, '.');
                    if (result != 0)
                    {
                        return result;
                    }
                    continue;
                }
                if (reference[i].Text.IndexOf('_') >= 0 || difference[i].Text.IndexOf('_') >= 0)
                {
                    int result = CompareSplit(reference[i].Text, difference[i].Text, '_');
                    if (result != 0)
                    {
                        return result;
                    }
                    continue;
                }

                int compared = PartCompare(reference[i], difference[i]);
                if (compared != 0)
                {
                    return compared;
                }
            }
            return 0;
        }

        private static int CompareSplit(string reference, string difference, char delimiter)
        {
            return CompareSegments(Split(reference, delimiter), Split(difference, delimiter));
        }

        private static bool IsPreRelease(string part)
        {
            return ContainsIgnoreCase(part, "alpha") || ContainsIgnoreCase(part, "beta")
                || ContainsIgnoreCase(part, "rc") || ContainsIgnoreCase(part, "pre");
        }

        private static bool ContainsIgnoreCase(string text, string value)
        {
            return text.IndexOf(value, StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static int PartCompare(Part reference, Part difference)
        {
            if (reference.IsNum && difference.IsNum)
            {
                return difference.Num.CompareTo(reference.Num);
            }
            // Matches PowerShell comparing a [String] to a [Long]: the number becomes text.
            return string.Compare(difference.Text, reference.Text, StringComparison.InvariantCultureIgnoreCase);
        }

        private static int CompareDates(string referenceDate, string differenceDate)
        {
            if (long.TryParse(referenceDate, out long reference) && long.TryParse(differenceDate, out long difference))
            {
                return difference.CompareTo(reference);
            }
            return string.CompareOrdinal(differenceDate, referenceDate);
        }

        private static List<Part> Split(string version, char delimiter)
        {
            var parts = new List<Part>(6);
            int length = version.Length;
            int i = 0;
            while (i < length)
            {
                if (version[i] == delimiter)
                {
                    i++;
                    continue;
                }
                int start = i;
                if (IsAsciiLetter(version[i]))
                {
                    while (i < length && IsAsciiLetter(version[i]))
                    {
                        i++;
                    }
                }
                else
                {
                    while (i < length && !IsAsciiLetter(version[i]) && version[i] != delimiter)
                    {
                        i++;
                    }
                }
                parts.Add(new Part(version.Substring(start, i - start)));
            }
            return parts;
        }

        private static bool IsAsciiLetter(char c)
        {
            return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
        }
    }
}
