using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace shim {
	
	class Program {
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
			if(!string.IsNullOrEmpty(add_args)) {
				add_args += " ";
			} else {
				add_args = "";
			}

			var p = new Process();
			p.StartInfo.FileName = path;
			p.StartInfo.Arguments = add_args + Serialize(args);

			p.StartInfo.UseShellExecute = false;
			p.StartInfo.RedirectStandardError = true;
			p.StartInfo.RedirectStandardOutput = true;
			
			p.Start();

			ReadChars(p.StandardOutput, Console.Out);
			ReadChars(p.StandardError, Console.Error);

			p.WaitForExit();

			Console.Write(p.StandardOutput.ReadToEnd());
			Console.Error.Write(p.StandardError.ReadToEnd());
			
			return p.ExitCode;
		}

		// Once stdout or stderr starts sending, keep forwarding the stream to the console
		// until it stops sending. Otherwise the output from both streams is mixed up.
		static object sync = new object();
		static async void ReadChars(StreamReader r, TextWriter sendTo) {
			var buffer = new char[100];
			while(true) {
				var read = await r.ReadAsync(buffer, 0, buffer.Length);
				lock(sync) { // prevent other streams from writing
					while(true) {
						sendTo.Write(buffer, 0, read);

						if(read < buffer.Length) break; // release lock
						read = r.Read(buffer, 0, buffer.Length);	
					}
					if(read == 0) return; // EOF
				}
			}
		}

		static string Serialize(string[] args) {
			return string.Join(" ", args.Select(a => a.Contains(' ') ? '"' + a + '"' : a));
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
	}
}
