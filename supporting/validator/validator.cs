using System;
using System.IO;

namespace Scoop
{
    public class Program
    {
        public static int Main(string[] args)
        {
            bool ci = (args.Length == 3 && args[2] == "-ci");
            bool valid = false;

            if (args.Length < 2)
            {
                Console.WriteLine("Usage: validator.exe schema.json manifest.json");
                return 1;
            }

            Scoop.Validator validator = new Scoop.Validator(args[0], ci);
            valid = validator.Validate(args[1]);

            if (valid)
            {
                Console.WriteLine("Yay! {0} validates against the schema!", Path.GetFileName(args[1]));
            }
            else
            {
                foreach (var error in validator.Errors)
                {
                    Console.WriteLine(error);
                }
            }

            return valid ? 0 : 1;
        }
    }
}
