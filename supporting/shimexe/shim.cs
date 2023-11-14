using System;
using System.ComponentModel;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Runtime.InteropServices;

namespace Scoop
{

    class Program
    {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        static extern bool CreateProcess(string lpApplicationName,
            string lpCommandLine, IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes, bool bInheritHandles,
            uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory,
            [In] ref STARTUPINFO lpStartupInfo,
            out PROCESS_INFORMATION lpProcessInformation);
        const int ERROR_ELEVATION_REQUIRED = 740;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct STARTUPINFO
        {
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
        internal struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern UInt32 WaitForSingleObject(IntPtr hHandle, UInt32 dwMilliseconds);
        const UInt32 INFINITE = 0xFFFFFFFF;

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool CloseHandle(IntPtr hObject);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool GetExitCodeProcess(IntPtr hProcess, out uint lpExitCode);

        static int Main(string[] args)
        {
            var exe = Assembly.GetExecutingAssembly().Location;
            var dir = Path.GetDirectoryName(exe);
            var name = Path.GetFileNameWithoutExtension(exe);

            var configPath = Path.Combine(dir, name + ".shim");
            if (!File.Exists(configPath))
            {
                Console.Error.WriteLine("Couldn't find " + Path.GetFileName(configPath) + " in " + dir);
                return 1;
            }

            var config = Config(configPath);
            var path = Get(config, "path").Trim('"');
            var add_args = Get(config, "args");

            ExeTypeResult exeType = ExeType(path);

            var si = new STARTUPINFO();
            var pi = new PROCESS_INFORMATION();

            // create command line
            var cmd_args = add_args ?? "";
            var pass_args = GetArgs(Environment.CommandLine);
            if (!string.IsNullOrEmpty(pass_args))
            {
                if (!string.IsNullOrEmpty(cmd_args)) cmd_args += " ";
                cmd_args += pass_args;
            }
            if (!string.IsNullOrEmpty(cmd_args)) cmd_args = " " + cmd_args;
            var cmd = "\"" + path + "\"" + cmd_args;

            if (!CreateProcess(null, cmd, IntPtr.Zero, IntPtr.Zero,
                bInheritHandles: true,
                dwCreationFlags: 0,
                lpEnvironment: IntPtr.Zero, // inherit parent
                lpCurrentDirectory: null, // inherit parent
                lpStartupInfo: ref si,
                lpProcessInformation: out pi))
            {
                var error = Marshal.GetLastWin32Error();
                Console.WriteLine("error {0}", error);
                if (error == ERROR_ELEVATION_REQUIRED)
                {
                    // Unfortunately, ShellExecute() does not allow us to run program without
                    // CREATE_NEW_CONSOLE, so we can not replace CreateProcess() completely.
                    // The good news is we are okay with CREATE_NEW_CONSOLE when we run program with elevation.
                    Process process = new Process();
                    process.StartInfo = new ProcessStartInfo(path, cmd_args);
                    process.StartInfo.UseShellExecute = true;
                    try
                    {
                        process.Start();
                    }
                    catch (Win32Exception exception)
                    {
                        return exception.ErrorCode;
                    }
                    process.WaitForExit();
                    return process.ExitCode;
                }
                return error;
            }

            uint exit_code = 0;

            // Don't wait on GUI apps, as we don't want to block the console.
            // Can set environment variable "SCOOP_SHIM_GUI_WAIT" to force the shim to wait.
            if (exeType != ExeTypeResult.IMAGE_SUBSYSTEM_WINDOWS_GUI || System.Environment.GetEnvironmentVariable("SCOOP_SHIM_GUI_WAIT") != null)
            {
                WaitForSingleObject(pi.hProcess, INFINITE);
                GetExitCodeProcess(pi.hProcess, out exit_code);
            }

            // Close process and thread handles.
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);

            return (int)exit_code;
        }

        // now uses GetArgs instead
        static string Serialize(string[] args)
        {
            return string.Join(" ", args.Select(a => a.Contains(' ') ? '"' + a + '"' : a));
        }

        // strips the program name from the command line, returns just the arguments
        static string GetArgs(string cmdLine)
        {
            if (cmdLine.StartsWith("\""))
            {
                var endQuote = cmdLine.IndexOf("\" ", 1);
                if (endQuote < 0) return "";
                return cmdLine.Substring(endQuote + 1);
            }
            var space = cmdLine.IndexOf(' ');
            if (space < 0 || space == cmdLine.Length - 1) return "";
            return cmdLine.Substring(space + 1);
        }

        static string Get(Dictionary<string, string> dic, string key)
        {
            string value = null;
            dic.TryGetValue(key, out value);
            return value;
        }

        static Dictionary<string, string> Config(string path)
        {
            var config = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var line in File.ReadAllLines(path))
            {
                var m = Regex.Match(line, @"([^=]+)=(.*)");
                if (m.Success)
                {
                    config[m.Groups[1].Value.Trim()] = m.Groups[2].Value.Trim();
                }
            }
            return config;
        }

        enum ExeTypeResult : ushort
        {
            // It's a GUI app.
            IMAGE_SUBSYSTEM_WINDOWS_GUI,

            // It's a console app.
            IMAGE_SUBSYSTEM_WINDOWS_CUI,

            // Errors
            INVALID_IMAGE_DOS_HEADER_SIGNATURE,
            INVALID_IMAGE_NT_HEADERS64_SIGNATURE,
            INVALID_IMAGE_FILE_HEADER_MACHINE,
            INVALID_IMAGE_FILE_HEADER_OPTIONALHEADER,
            INVALID_IMAGE_OPTIONAL_HEADER_MAGIC,
            INVALID_IMAGE_OPTIONAL_HEADER_SUBSYSTEM,
            UNHANDLED_EXCEPTION
        }

        static ExeTypeResult ExeType(string path)
        {
            try
            {
                using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read))
                {
                    using (var reader = new BinaryReader(stream))
                    {
                        //
                        // IMAGE_DOS_HEADER
                        //

                        byte[] e_magic = reader.ReadBytes(2);
                        // Signature should be "MZ"
                        if (e_magic.Length != 2 || e_magic[0] != 'M' || e_magic[1] != 'Z')
                        {
                            return ExeTypeResult.INVALID_IMAGE_DOS_HEADER_SIGNATURE;
                        }

                        stream.Seek(0x3c, SeekOrigin.Begin);
                        uint e_lfanew = reader.ReadUInt32();

                        //
                        // IMAGE_NT_HEADERS64
                        //

                        stream.Seek(e_lfanew, SeekOrigin.Begin);

                        long headers_pos = reader.BaseStream.Position;

                        byte[] signature = reader.ReadBytes(4);
                        // Signature should be "PE\0\0"
                        if (signature.Length != 4 || signature[0] != 0x50 || signature[1] != 0x45 || signature[2] != 0 || signature[3] != 0)
                        {
                            return ExeTypeResult.INVALID_IMAGE_NT_HEADERS64_SIGNATURE;
                        }

                        //
                        // IMAGE_FILE_HEADER
                        // https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-image_file_header
                        //

                        stream.Seek(headers_pos + 0x4, SeekOrigin.Begin);

                        ushort machine = reader.ReadUInt16();
                        // 0x8664 = IMAGE_FILE_MACHINE_AMD64; 0x014c = IMAGE_FILE_MACHINE_I386
                        if (machine != 0x8664 && machine != 0x014c)
                        {
                            return ExeTypeResult.INVALID_IMAGE_FILE_HEADER_MACHINE;
                        }

                        // 0x04 [sizeof(Signature)] + 0x10 [offset_of(SizeOfOptionalHeader)]
                        stream.Seek(headers_pos + 0x04 + 0x10, SeekOrigin.Begin);

                        ushort sizeOfOptionalHeader = reader.ReadUInt16();
                        if (sizeOfOptionalHeader == 0)
                        {
                            return ExeTypeResult.INVALID_IMAGE_FILE_HEADER_OPTIONALHEADER;
                        }

                        //
                        // IMAGE_OPTIONAL_HEADER64
                        // https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-image_optional_header32
                        //

                        // 0x04 [sizeof(Signature)] + 0x14 [sizeof(IMAGE_FILE_HEADER]
                        stream.Seek(headers_pos + 0x04 + 0x14, SeekOrigin.Begin);

                        // 0X20B = IMAGE_NT_OPTIONAL_HDR64_MAGIC; 0x10b=IMAGE_NT_OPTIONAL_HDR32_MAGIC
                        ushort magic = reader.ReadUInt16();
                        if (magic != 0x020b && magic != 0x010b)
                        {
                            return ExeTypeResult.INVALID_IMAGE_OPTIONAL_HEADER_MAGIC;
                        }

                        // 0x04 [sizeof(Signature)] + 0x14 [sizeof(IMAGE_FILE_HEADER] + 0x44 [offset_of(Subsystem)]
                        stream.Seek(headers_pos + 0x04 + 0x14 + 0x44, SeekOrigin.Begin);

                        ushort subsystem = reader.ReadUInt16();
                        switch (subsystem)
                        {
                            case 0x02:
                                return ExeTypeResult.IMAGE_SUBSYSTEM_WINDOWS_GUI;
                            case 0x03:
                                return ExeTypeResult.IMAGE_SUBSYSTEM_WINDOWS_CUI;
                            default:
                                return ExeTypeResult.INVALID_IMAGE_OPTIONAL_HEADER_SUBSYSTEM;
                        }
                    } // using var reader
                } // using var stream
            }
            catch (Exception)
            {
                return ExeTypeResult.UNHANDLED_EXCEPTION;
            }
        }
    } // class Program
} // namespace Scoop
