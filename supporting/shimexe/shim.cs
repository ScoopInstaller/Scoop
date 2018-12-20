using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace Scoop {

    class Program {
        [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
        static extern bool CreateProcess(string lpApplicationName,
            string lpCommandLine, IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes, bool bInheritHandles,
            uint dwCreationFlags,
            [In, MarshalAs(UnmanagedType.LPStr)] StringBuilder lpEnvironment,
            string lpCurrentDirectory,
            [In] ref STARTUPINFO lpStartupInfo,
            out PROCESS_INFORMATION lpProcessInformation);
        const int ERROR_ELEVATION_REQUIRED = 740;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct STARTUPINFO {
            public Int32 cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public Int32 dwX;
            public Int32 dwY;
            public Int32 dwXSize;
            public Int32 dwYSize;
            public Int32 dwXCountChars;
            public Int32 dwYCountChars;
            public Int32 dwFillAttribute;
            public Int32 dwFlags;
            public Int16 wShowWindow;
            public Int16 cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct PROCESS_INFORMATION {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }

        [DllImport("kernel32.dll", SetLastError=true)]
        static extern UInt32 WaitForSingleObject(IntPtr hHandle, UInt32 dwMilliseconds);
        const UInt32 INFINITE = 0xFFFFFFFF;

        [DllImport("kernel32.dll", SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool CloseHandle(IntPtr hObject);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool GetExitCodeProcess(IntPtr hProcess, out uint lpExitCode);

        static int Main(string[] args) {
            var exe = Assembly.GetExecutingAssembly().Location;
            var dir = Path.GetDirectoryName(exe);
            var name = Path.GetFileNameWithoutExtension(exe);

            var configPath = Path.Combine(dir, name + ".shim");
            if(!File.Exists(configPath)) {
                Console.Error.WriteLine("Couldn't find " + Path.GetFileName(configPath) + " in " + dir);
                return 1;
            }

            var config = Config(configPath);
            var path = Get(config, "path");
            var add_args = Get(config, "args");

            var si = new STARTUPINFO();
            var pi = new PROCESS_INFORMATION();

            // create command line
            var cmd_args = add_args ?? "";
            var pass_args = GetArgs(Environment.CommandLine);
            if(!string.IsNullOrEmpty(pass_args)) {
                if(!string.IsNullOrEmpty(cmd_args)) cmd_args += " ";
                cmd_args += pass_args;
            }
            if(!string.IsNullOrEmpty(cmd_args)) cmd_args = " " + cmd_args;
            var cmd = "\"" + path + "\"" + cmd_args;

            var environment_dictionary = Environment.GetEnvironmentVariables();
            foreach (KeyValuePair<string, string> entry in config) {
                if (entry.Key.StartsWith("env::")) {
                    environment_dictionary[entry.Key.Substring(5)] = ExpandEnvironmentVariables(environment_dictionary, entry.Value);
                }
            }
            var environment = new StringBuilder();
            foreach (DictionaryEntry entry in environment_dictionary) {
                environment.Append(entry.Key);
                environment.Append("=");
                environment.Append(entry.Value);
                environment.Length += 1;
            }
            environment.Length += 1;

            if(!CreateProcess(null, cmd, IntPtr.Zero, IntPtr.Zero,
                bInheritHandles: true,
                dwCreationFlags: 0,
                lpEnvironment: environment,
                lpCurrentDirectory: null, // inherit parent
                lpStartupInfo: ref si,
                lpProcessInformation: out pi)) {

                var error = Marshal.GetLastWin32Error();
                if(error == ERROR_ELEVATION_REQUIRED) {
                    // Unfortunately, ShellExecute() does not allow us to run program without
                    // CREATE_NEW_CONSOLE, so we can not replace CreateProcess() completely.
                    // The good news is we are okay with CREATE_NEW_CONSOLE when we run program with elevation.
                    Process process = new Process();
                    process.StartInfo = new ProcessStartInfo(path, cmd_args);
                    process.StartInfo.UseShellExecute = true;
                    try {
                        process.Start();
                    }
                    catch(Win32Exception exception) {
                        return exception.ErrorCode;
                    }
                    process.WaitForExit();
                    return process.ExitCode;
                }
                return error;
            }

            WaitForSingleObject(pi.hProcess, INFINITE);

            uint exit_code = 0;
            GetExitCodeProcess(pi.hProcess, out exit_code);

            // Close process and thread handles.
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);

            return (int)exit_code;
        }

        // now uses GetArgs instead
        static string Serialize(string[] args) {
            return string.Join(" ", args.Select(a => a.Contains(' ') ? '"' + a + '"' : a));
        }

        // strips the program name from the command line, returns just the arguments
        static string GetArgs(string cmdLine) {
            if(cmdLine.StartsWith("\"")) {
                var endQuote = cmdLine.IndexOf("\" ", 1);
                if(endQuote < 0) return "";
                return cmdLine.Substring(endQuote + 1);
            }
            var space = cmdLine.IndexOf(' ');
            if(space < 0 || space == cmdLine.Length - 1) return "";
            return cmdLine.Substring(space + 1);
        }

        static string Get(Dictionary<string, string> dic, string key) {
            string value = null;
            dic.TryGetValue(key, out value);
            return value;
        }

        static Dictionary<string, string> Config(string path) {
            var config = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach(var line in File.ReadAllLines(path)) {
                var m = Regex.Match(line, @"([^=]+)=(.*)");
                if(m.Success) {
                    config[m.Groups[1].Value.Trim()] = m.Groups[2].Value.Trim();
                }
            }
            return config;
        }

        private static string ExpandEnvironmentVariables(IDictionary environment_dictionary, string name)
        {
            StringBuilder result = new StringBuilder();

            int lastPos = 0, pos;
            while (lastPos < name.Length && (pos = name.IndexOf('%', lastPos + 1)) >= 0)
            {
                if (name[lastPos] == '%')
                {
                    string key = name.Substring(lastPos + 1, pos - lastPos - 1);
                    object value = environment_dictionary[key];
                    if (value != null)
                    {
                        result.Append((string)value);
                        lastPos = pos + 1;
                        continue;
                    }
                }
                result.Append(name.Substring(lastPos, pos - lastPos));
                lastPos = pos;
            }
            result.Append(name.Substring(lastPos));

            return result.ToString();
        }
    }
}
