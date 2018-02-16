using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Schema;

namespace Scoop
{
    public class JsonParserException : Exception
    {
        public string FileName { get; set; }
        public JsonParserException(string file, string message) : base(message) { this.FileName = file; }
        public JsonParserException(string file, string message, Exception inner) : base(message, inner) { this.FileName = file; }
    }

    public class Validator
    {
        private bool CI { get; set; }
        public JSchema Schema { get; private set; }
        public FileInfo SchemaFile { get; private set; }
        public JObject Manifest { get; private set; }
        public FileInfo ManifestFile { get; private set; }
        public IList<string> Errors { get; private set; }
        public string ErrorsAsString
        {
            get
            {
                return String.Join(System.Environment.NewLine, this.Errors);
            }
        }

        private JSchema ParseSchema(string file)
        {
            try
            {
                return JSchema.Parse(File.ReadAllText(file, System.Text.Encoding.UTF8));
            }
            catch (Newtonsoft.Json.JsonReaderException e)
            {
                throw new JsonParserException(Path.GetFileName(file), e.Message, e);
            }
            catch (FileNotFoundException e)
            {
                throw e;
            }
        }

        private JObject ParseManifest(string file)
        {
            try
            {
                return JObject.Parse(File.ReadAllText(file, System.Text.Encoding.UTF8));
            }
            catch (Newtonsoft.Json.JsonReaderException e)
            {
                throw new JsonParserException(Path.GetFileName(file), e.Message, e);
            }
            catch (FileNotFoundException e)
            {
                throw e;
            }
        }

        public Validator(string schemaFile)
        {
            this.SchemaFile = new FileInfo(schemaFile);
            this.Errors = new List<string>();
        }

        public Validator(string schemaFile, bool ci)
        {
            this.SchemaFile = new FileInfo(schemaFile);
            this.Errors = new List<string>();
            this.CI = ci;
        }

        public bool Validate(string file)
        {
            this.ManifestFile = new FileInfo(file);
            return this.Validate();
        }

        public bool Validate()
        {
            if (!this.SchemaFile.Exists)
            {
                Console.WriteLine("ERROR: Please provide schema.json!");
                return false;
            }
            if (!this.ManifestFile.Exists)
            {
                Console.WriteLine("ERROR: Please provide manifest.json!");
                return false;
            }
            this.Errors.Clear();
            try
            {
                if (this.Schema == null)
                {
                    this.Schema = this.ParseSchema(this.SchemaFile.FullName);
                }
                this.Manifest = this.ParseManifest(this.ManifestFile.FullName);
            }
            catch (FileNotFoundException e)
            {
                this.Errors.Add(e.Message);
            }
            catch (JsonParserException e)
            {
                this.Errors.Add(String.Format("{0}{1}: {2}", (this.CI ? "    [*] " : ""), e.FileName, e.Message));
            }

            if (this.Schema == null || this.Manifest == null)
                return false;

            IList<ValidationError> validationErrors = new List<ValidationError>();

            this.Manifest.IsValid(this.Schema, out validationErrors);

            if (validationErrors.Count > 0)
            {
                foreach (ValidationError error in validationErrors)
                {
                    this.Errors.Add(String.Format("{0}{1}: {2}", (this.CI ? "    [*] " : ""), this.ManifestFile.Name, error.Message));
                    foreach (ValidationError childError in error.ChildErrors)
                    {
                        this.Errors.Add(String.Format((this.CI ? "    [^] {0}{1}" : "{0}^ {1}"), new String(' ', this.ManifestFile.Name.Length + 2), childError.Message));
                    }
                }
            }

            return (this.Errors.Count == 0);
        }
    }
}
