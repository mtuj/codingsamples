using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Net.Mail;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Principal;
using Common.Extensions;
using Common.Utilities;
using iTextSharp.text;
using iTextSharp.text.pdf;
using Microsoft.Office.Interop.Word;
using Vision.Api.DotNet.ApplicationServices.Emails;
using Vision.Api.DotNet.Common.Configuration;
using Vision.Api.DotNet.Domain.Documents;
using Image = iTextSharp.text.Image;
using Document = Vision.Api.DotNet.Domain.Documents.Document;
using Type = Vision.Api.DotNet.Domain.Documents.Type;

namespace Vision.Api.DotNet.ApplicationServices.FileSystem
{
    public class FileSystemServices : ServicesBase, IFileSystemServices
    {
        private readonly IEmailServices _emailServices;
        private readonly IConfigurationManager _configurationManager;

        const int Logon32ProviderDefault = 0;
        const int Logon32LogonInteractive = 2;

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        static extern bool LogonUser(string userName, string domain, string password, int logonType, int logonProvider, ref IntPtr accessToken);

        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="emailServices"></param>
        /// <param name="configurationManager"></param>
        /// <param name="servicesContext">The services context</param>
        public FileSystemServices(IServicesContext servicesContext, IEmailServices emailServices, IConfigurationManager configurationManager)
            : base(servicesContext)
        {
            _emailServices = emailServices;
            _configurationManager = configurationManager;
        }

        public static class PlaceHolders
        {
            public const string SerialPartA = "[%serialparta%]";
            public const string SerialPartB = "[%serialpartb%]";
            public const string ComponentNumber = "[%componentnumber%]";
            public const string M0 = "[%m0%]";
            public const string TestSessionTypeName = "[%testsessiontypename%]";
            public const string EquipmentType = "[%equipmenttype%]";
            public const string UnitReference = "[%unitreference%]";
            public const string DateDdMmYy = "[%dateddmmyy%]";
            public const string WoNumber = "[%wonumber%]";
            public const string DocumentType = "[%documenttype%]";
            public const string BranchName = "[%branchname%]";
            public const string DocumentId = "[%documentid%]";
        }

        public static class PdfFormFields
        {
            public const string TesterName = "NameTTT";
            public const string WitnessName = "NameWW";
        }

        /// <summary>
        /// Gets the first directory in the parent directory, whose name matches the search pattern (including wildcards)
        /// If no directory is found, one is created matching the search pattern but without wildcards
        /// </summary>
        /// <param name="parentDirectory">The path of the parent directory to search</param>
        /// <param name="searchPattern">The search pattern to look for in the parent directory's subdirectories</param>
        /// <param name="createIfNotFound">If true, creates a new directory if one is not found matching the search pattern</param>
        /// <param name="domain">The domain of the network credentials to use when connecting to the file system</param>
        /// <param name="userName">The username of the network credentials to use when connecting to the file system</param>
        /// <param name="password">The password of the network credentials to use when connecting to the file system</param>
        /// <returns>The first directory matching the search pattern, or a newly-created one if none was found and the createIfNotFound flag is set</returns>
        public string DirectoryMatchingPattern(string parentDirectory, string searchPattern, bool createIfNotFound, string domain, string userName, string password)
        {
            string directory = null;

            var impersonationContext = CreateImpersonationContext(domain, userName, password);

            // Get all directories matching the search pattern
            var directories = Directory.EnumerateDirectories(parentDirectory, searchPattern, SearchOption.TopDirectoryOnly).ToList();
            if (directories.Count > 0)
                // Return the first directory found
                directory = directories[0];

            if (directory == null && createIfNotFound)
            {
                // If no directories were found, create a new directory using the search pattern with wildcards removed
                // If we end up with an empty string, we just use a new randomly-generated guid instead
                var searchPatternWithoutWildcards = searchPattern.Replace("*", string.Empty).Trim();
                directory = Path.Combine(parentDirectory, searchPatternWithoutWildcards != string.Empty ? searchPatternWithoutWildcards : Guid.NewGuid().ToString());
                Directory.CreateDirectory(directory);
            }

            UndoImpersonationContext(impersonationContext);

            return directory;
        }

        /// <summary>
        /// Loads the file data from the file at the specified file path
        /// </summary>
        /// <param name="filePath">The file path from which to load the data</param>
        /// <param name="domain">The domain of the network credentials to use when connecting to the file system</param>
        /// <param name="userName">The username of the network credentials to use when connecting to the file system</param>
        /// <param name="password">The password of the network credentials to use when connecting to the file system</param>
        /// <returns>The memory stream containing the file data</returns>
        public MemoryStream LoadFileData(string filePath, string domain, string userName, string password)
        {
            var impersonationContext = CreateImpersonationContext(domain, userName, password);

            // Read the file data to a memory stream
            var memoryStream = new MemoryStream(); 
            using (var fileStream = File.OpenRead(filePath))
            {
                fileStream.CopyTo(memoryStream);
            }
            
            UndoImpersonationContext(impersonationContext);

            return memoryStream;
        }

        /// <summary>
        /// Saves the file data to the specified file path
        /// </summary>
        /// <param name="fileData">The file data to save</param>
        /// <param name="filePath">The file path to save to</param>
        /// <param name="createDirectories">If true, creates the directories in the path if they do not exist</param>
        /// <param name="domain">The domain of the network credentials to use when connecting to the file system</param>
        /// <param name="userName">The username of the network credentials to use when connecting to the file system</param>
        /// <param name="password">The password of the network credentials to use when connecting to the file system</param>
        /// <returns>The file path that the data was saved to</returns>
        public string SaveFileData(MemoryStream fileData, string filePath, bool createDirectories, string domain, string userName, string password)
        {
            var impersonationContext = CreateImpersonationContext(domain, userName, password);
            var path = "";

            // Get the directory path, and create it if it does not already exist
            try
            {
                path = Path.GetDirectoryName(filePath);
                if (path != null && !Directory.Exists(path) && createDirectories)
                    Directory.CreateDirectory(path);

                // Save the file data
                var file = new FileStream(filePath, FileMode.Create, FileAccess.Write);
                var bytes = fileData.ToArray();
                file.Write(bytes, 0, bytes.Length);
                file.Close();
                fileData.Close();
            }
            catch (PathTooLongException)
            {
                // If the file path is too long, generate an e-mail warning
                EmailFilePathTooLongWarning(filePath);
            }
            finally
            {
                UndoImpersonationContext(impersonationContext);
            }

            return path;
        }

        /// <summary>
        /// Deletes the file at the specified file path
        /// </summary>
        /// <param name="filePath">The file path to delete</param>
        public void DeleteFile(string filePath)
        {
            if(FileExists(filePath))
                File.Delete(filePath);
        }

	    /// <summary>
	    /// Renames the file at the specified file path, to the new file path. 
	    /// </summary>
	    /// <param name="currentFilePath">The file path to rename</param>
	    /// <param name="newFilePath">The file path to rename to</param>
	    /// <param name="domain">The domain of the network credentials to use when connecting to the file system</param>
	    /// <param name="userName">The username of the network credentials to use when connecting to the file system</param>
	    /// <param name="password">The password of the network credentials to use when connecting to the file system</param>
	    /// <exception cref="FileNotFoundException">Thrown when the current file does not exist.</exception>
	    public bool RenameFile(string currentFilePath, string newFilePath, string domain, string userName, string password)
		{
			if (!FileExists(currentFilePath, domain, userName, password)) throw new FileNotFoundException();

			var impersonationContext = CreateImpersonationContext(domain, userName, password);
		    File.Move(currentFilePath, newFilePath);
			UndoImpersonationContext(impersonationContext);

		    return true;
		}

	    /// <summary>
        /// Deletes the file at the specified file path
        /// </summary>
        /// <param name="filePath">The file path to delete</param>
        /// <param name="domain">The domain of the network credentials to use when connecting to the file system</param>
        /// <param name="userName">The username of the network credentials to use when connecting to the file system</param>
        /// <param name="password">The password of the network credentials to use when connecting to the file system</param>
        public void DeleteFile(string filePath, string domain, string userName, string password)
        {
            if (!FileExists(filePath, domain, userName, password)) return;

            var impersonationContext = CreateImpersonationContext(domain, userName, password);
            File.Delete(filePath);
            UndoImpersonationContext(impersonationContext);            
        }

        /// <summary>
        /// Returns true or false depending on whether or not a file exists at the specified path
        /// </summary>
        /// <param name="filePath">The file path to test</param>
        public bool FileExists(string filePath)
        {
            var fileExists = File.Exists(filePath);
            return fileExists;
        }

        /// <summary>
        /// Returns true or false depending on whether or not a file exists at the specified path
        /// </summary>
        /// <param name="filePath">The file path to test</param>
        /// <param name="domain">The domain of the network credentials to use when connecting to the file system</param>
        /// <param name="userName">The username of the network credentials to use when connecting to the file system</param>
        /// <param name="password">The password of the network credentials to use when connecting to the file system</param>
        public bool FileExists(string filePath, string domain, string userName, string password)
        {
            var impersonationContext = CreateImpersonationContext(domain, userName, password);
            var fileExists = File.Exists(filePath);
            UndoImpersonationContext(impersonationContext);
            return fileExists;
        }

        /// <summary>
        /// Converts the Word document located at the specified file path to its pdf equivalent
        /// </summary>
        /// <param name="document">The Word document to be converted</param>
        /// <param name="workingDirectory">The directory to temporarily save the word and pdf documents to during the conversion process</param>
        /// <param name="domain">The domain of the network credentials to use when connecting to the <paramref name="workingDirectory"/></param>
        /// <param name="userName">The username of the network credentials to use when connecting to the <paramref name="workingDirectory"/></param>
        /// <param name="password">The password of the network credentials to use when connecting to the <paramref name="workingDirectory"/></param>
        /// <returns>The converted pdf document</returns>
        public Document ConvertWordToPdf(Document document, string workingDirectory, string domain, string userName, string password)
        {
            var impersonationContext = CreateImpersonationContext(domain, userName, password);

            // If the working directory does not exist, attempt to create it
            if (!Directory.Exists(workingDirectory))
                Directory.CreateDirectory(workingDirectory);

            // Create a new Microsoft Word application object
            var application = new Application {Visible = false, ScreenUpdating = false};

            // C# doesn't have optional arguments, so we create a dummy value to pass in for these
            object oMissing = System.Reflection.Missing.Value;

            // Ideally this would be done in memory and would not touch the file system,
            // however because we have to use the Microsoft.Word.Interop library we have no choice

            // Construct the full file paths for the temporary Word and pdf documents in the working directory
            var filePathWord = Path.Combine(workingDirectory, document.LatestRevision.FileName);
            var filePathPdf = Path.ChangeExtension(filePathWord, "pdf");
            // Cast the file paths to an object for the Word application Open and SaveAs methods
            var filePathWordObject = (object)filePathWord;
            var filePathPdfObject = (object)filePathPdf;

            // Write the temporary Word document to the working directory
            var tmpFileStream = File.OpenWrite(filePathWord);
            tmpFileStream.Write(document.LatestRevision.Content.Content, 0, document.LatestRevision.Content.Content.Length);
            tmpFileStream.Close();

            // Create the document object in memory by loading the file from the file system
            // Use the dummy value as a placeholder for optional arguments
            var wordDocumentObject = application.Documents.Open(ref filePathWordObject, ref oMissing,
                ref oMissing, ref oMissing, ref oMissing, ref oMissing, ref oMissing,
                ref oMissing, ref oMissing, ref oMissing, ref oMissing, ref oMissing,
                ref oMissing, ref oMissing, ref oMissing, ref oMissing);
            wordDocumentObject.Activate();

            // Save the document in pdf format
            object fileFormat = WdSaveFormat.wdFormatPDF;
            wordDocumentObject.SaveAs(ref filePathPdfObject,
                ref fileFormat, ref oMissing, ref oMissing,
                ref oMissing, ref oMissing, ref oMissing, ref oMissing,
                ref oMissing, ref oMissing, ref oMissing, ref oMissing,
                ref oMissing, ref oMissing, ref oMissing, ref oMissing);

            // Close the Word document, but leave the Word application open
            // The document object has to be cast to type _Document so that it will find the correct Close method
            object saveChanges = WdSaveOptions.wdDoNotSaveChanges;
            ((_Document)wordDocumentObject).Close(ref saveChanges, ref oMissing, ref oMissing);
            wordDocumentObject = null;

            // The Microsoft Word application object has to be cast to type _Application so that it will find the correct Quit method
            ((_Application)application).Quit(ref oMissing, ref oMissing, ref oMissing);
            application = null;

            // Read the converted pdf document data into memory
            byte[] fileData;
            using (var memoryStream = new MemoryStream())
            using (var fileStream = new FileStream(filePathPdf, FileMode.Open, FileAccess.Read))
            {
                fileData = new byte[fileStream.Length];
                fileStream.Read(fileData, 0, (int)fileStream.Length);
                memoryStream.Write(fileData, 0, (int)fileStream.Length);
            }

            // Form the pdf Document domain object to return
            var documentReturn = new Document
            {
                Type = document.Type,
                Description = Path.GetFileNameWithoutExtension(filePathPdf),
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentMetaData = new DocumentRevisionMetaData(documentReturn)
            {
                DisplayName = Path.GetFileNameWithoutExtension(filePathPdf),
                FileName = Path.GetFileName(filePathPdf),
                MimeType = "application/pdf",
                CreatedDateUtc = SystemTime.UtcNow(),
                PublishedDateUtc = SystemTime.UtcNow(),
                Bytes = fileData.Length,
                Content = new DocumentRevisionContent { Content = fileData },
            };
            documentReturn.Revisions.Add(documentMetaData);

            // Finally, clean up any temporary files created in the conversion process
            DeleteFile(filePathWord, domain, userName, password);
            DeleteFile(filePathPdf, domain, userName, password);

            UndoImpersonationContext(impersonationContext);

            return documentReturn;
        }

        /// <summary>
        /// Returns the content of the file to a byte array.
        /// </summary>
        /// <param name="filePath">The file path of the file to content to convert.</param>
        /// <returns>The content of the file as a byte array</returns>
        public byte[] ConvertFileContentToByteArray(string filePath)
        {
            if(!FileExists(filePath)) return new byte[0];

            byte[] fileContent;
            using (var memoryStream = new MemoryStream())
            using (var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read))
            {
                fileContent = new byte[fileStream.Length];
                fileStream.Read(fileContent, 0, (int)fileStream.Length);
                memoryStream.Write(fileContent, 0, (int)fileStream.Length);
            }

            return fileContent;
        }

        /// <summary>
        /// Generates a checksum for the <paramref name="fileContent">file content</paramref>.
        /// </summary>
        /// <param name="fileContent">The file content to generate the checksum for</param>.
        /// <returns>The checksum.</returns>
        public string GenerateFileChecksum(byte[] fileContent)
        {
            string checksum;

            using (var md5 = MD5.Create())
            {
                checksum = BitConverter.ToString(md5.ComputeHash(fileContent)).Replace("-", "").ToLower();
            }
            return checksum;
        }

        /// <summary>
        /// Returns a memory stream for a combined document, comprising all the supplied pdf documents
        /// </summary>
        /// <param name="documents">The documents to combine</param>
        /// <returns>The memory stream for the combined document</returns>
        public MemoryStream PdfDocumentCombinedStream(IList<Document> documents)
        {
            // If we have no documents at all, do not proceed
            if (documents.Count == 0)
                return null;

            // Initialise the new PDF document object to create, the output stream to write its data to, and the PdfSmartCopy writer
            var combinedDocument = new iTextSharp.text.Document();
            var oCombinedDocumentStream = new MemoryStream();
            var pdfWriter = new PdfSmartCopy(combinedDocument, oCombinedDocumentStream);

            // Set compression options
            pdfWriter.SetPdfVersion(PdfWriter.PDF_VERSION_1_7);
            pdfWriter.CompressionLevel = PdfStream.BEST_COMPRESSION;
            pdfWriter.SetFullCompression();

            // Open document object to write to - this is the actual object that gets created and modified in memoey
            // The pdf writer outputs this to the memory stream (if we wanted to, we could just as easily write to a file instead)
            combinedDocument.Open();

            // Iterate through all pdf documents in the collection
            foreach (var document in documents)
            {
                var oStream = new MemoryStream();

                // Read individual document content
                var reader = new PdfReader(document.LatestRevision.Content.Content);
                
                // Create a pdf stamper to modify the content and output it to a memory stream
                // We set it to flatten the form field data in the output, so it cannot be modified
                // Note that text fields are flattened explicitly later in the method
                // so the only form fields that actually get flattened are radio buttons, check boxes etc
                var stamper = new PdfStamper(reader, oStream) { FormFlattening = true };
                var form = stamper.AcroFields;
                var keys = new ArrayList(form.Fields.Keys.ToList());

                // Create an arial base font
                // We use this during flattening of text fields
                var arialFontPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Fonts), "ARIALUNI.TTF");
                var arialBaseFont = BaseFont.CreateFont(arialFontPath, BaseFont.IDENTITY_H, BaseFont.EMBEDDED);

                foreach (var key in keys)
                {
                    if (form.GetFieldType(key.ToString()) == 4)
                    {
                        // Text field

                        // Render the form field content as a replacement text (Phrase) object
                        // We do this here as the built-in FormFlattening option causes a font error in the final pdf

                        const float fontSize = 8.0f;
                        const float leading = 8.0f;
                        const float minimumHeight = 12.5f;
                        const float adjustmentY = 1.5f;

                        // Get field positioning information
                        var fieldPositions = form.GetFieldPositions(key.ToString());
                        if (fieldPositions.Count == 0) break;
                        var fieldPosition = fieldPositions[0];
                        var height = fieldPosition.position.Top - fieldPosition.position.Bottom;
                        var width = fieldPosition.position.Right - fieldPosition.position.Left;
                        var heightAdjustment = height < minimumHeight ? minimumHeight - height : 0.0f;

                        // Generate the Phrase object which holds the rendered text, and populate it using the contents of the form field
                        var phrase = new Phrase(leading, form.GetField(key.ToString()), new iTextSharp.text.Font(arialBaseFont, fontSize));

                        // Table object to hold the Phrase
                        // This allows us to set the vertical and horizontal alignment of each rendered Phrase
                        var table = new PdfPTable(1) {
                            WidthPercentage = 100
                        };
                        table.SetWidths(new[] { width });

                        // Table cell object in which the Phrase will be positioned
                        var cell = new PdfPCell {
                            FixedHeight = height + heightAdjustment,
                            Border = iTextSharp.text.Rectangle.NO_BORDER,
                            VerticalAlignment = Element.ALIGN_MIDDLE,
                            HorizontalAlignment = Element.ALIGN_LEFT
                        };
                        cell.AddElement(phrase);
                        table.AddCell(cell);

                        // We now create our ColumnText wrapper, which allows us to position the table in the same place as the original form field
                        var columnText = new ColumnText(stamper.GetOverContent(fieldPosition.page));
                        columnText.SetSimpleColumn(fieldPosition.position.Left, fieldPosition.position.Bottom + adjustmentY - heightAdjustment, fieldPosition.position.Right, fieldPosition.position.Top + adjustmentY);
                        columnText.AddElement(table);
                        columnText.Go();

                        // Finally, all that is left to do is to remove the original form field
                        form.RemoveField(key.ToString());
                    }
                    else
                    {
                        // Non-text field

                        // Append each form field name to have a unique suffix
                        // This is so that when we join all the documents together, all the form field names are unique and therefore still rendered correctly
                        form.RenameField(key.ToString(), string.Format("{0}{1}", key, documents.IndexOf(document)));
                    }
                }

                // We now compress all images in the pdf
                // http://cjhaas.com/blog/2012/01/06/how-to-recompress-images-in-a-pdf-using-itextsharp/

                const int physicalSizePercentage = 90;
                const int compressionPercentage = 85;

                var numberOfPages = reader.NumberOfPages;
                for (var currentPageIndex = 1; currentPageIndex <= numberOfPages; currentPageIndex++)
                {
                    // Get the XObject structure
                    var resources = (PdfDictionary)PdfReader.GetPdfObject(reader.GetPageN(currentPageIndex).Get(PdfName.RESOURCES));
                    var xObjects = (PdfDictionary)PdfReader.GetPdfObject(resources.Get(PdfName.XOBJECT));
                    if (xObjects != null)
                    {
                        // Loop through each XObject key
                        foreach (var key in xObjects.Keys)
                        {
                            var xObject = xObjects.Get(key);
                            if (xObject.IsIndirect())
                            {
                                // Get the current key as a pdf object
                                var imgObject = (PdfDictionary)PdfReader.GetPdfObject(xObject);
                                
                                // Is the object an image?
                                if (imgObject != null && imgObject.Get(PdfName.SUBTYPE).Equals(PdfName.IMAGE))
                                {
                                    // Note: There are several different types of filters we're only handing the simplest one here which is basically raw jpeg
                                    if (imgObject.Get(PdfName.FILTER).Equals(PdfName.DCTDECODE))
                                    {
                                        // Get the raw bytes of the image
                                        var oldBytes = PdfReader.GetStreamBytesRaw((PRStream)imgObject);
                                        byte[] newBytes;
                                
                                        // Wrap a stream around our original image
                                        using (var memoryStream = new MemoryStream(oldBytes))
                                        {
                                            // Convert the bytes into a .NET image
                                            using (var oldImage = System.Drawing.Image.FromStream(memoryStream))
                                            {
                                                // Shrink the source image to a percentage of its original size
                                                using (var newImage = ShrinkImage(oldImage, physicalSizePercentage / 100.0f))
                                                {
                                                    // Convert the image to bytes using jpeg
                                                    newBytes = ConvertImageToBytes(newImage, compressionPercentage);
                                                }
                                            }
                                        }
                                        
                                        // Create a new iTextSharp image from our bytes
                                        var compressedImage = Image.GetInstance(newBytes);
                                        
                                        // Kill off the old image
                                        PdfReader.KillIndirect(xObject);
                                        
                                        // Add our image in its place
                                        stamper.Writer.AddDirectImageSimple(compressedImage, (PRIndirectReference)xObject);
                                    }
                                }
                            }
                        }
                    }
                }
                
                stamper.Writer.CloseStream = false;
                stamper.Close();

                // Read modified document content from the pdf stamper's output stream
                reader = new PdfReader(oStream.ToArray());
                numberOfPages = reader.NumberOfPages;

                // Add each modified page to our combined document object
                for (var currentPageIndex = 1; currentPageIndex <= numberOfPages; currentPageIndex++)
                {
                    var page = pdfWriter.GetImportedPage(reader, currentPageIndex);
                    pdfWriter.AddPage(page);
                }
            }

            // Close the pdf writer and the combined document object
            // This will flush the output memory stream, and give us our completed document data
            pdfWriter.CloseStream = false;
            pdfWriter.Close();
            combinedDocument.Close();

            // Move the stream position to the beginning then return it
            oCombinedDocumentStream.Seek(0, SeekOrigin.Begin);

            return oCombinedDocumentStream;
        }

        /// <summary>
        /// Sets the value of the specified form field in the pdf document
        /// </summary>
        /// <param name="document">The document in which to set the form field</param>
        /// <param name="fieldName">The name of the field to set</param>
        /// <param name="value">The value to set the field to</param>
        /// <returns>The content of the annotated document as a byte array</returns>
        public void SetPdfFormField(Document document, string fieldName, string value)
        {
            // Update content, length and checksum
            var content = SetPdfFormField(document.LatestRevision.Content.Content, fieldName, value);
            document.LatestRevision.Content.Content = content;
            document.LatestRevision.Content.FileChecksum = GenerateFileChecksum(content);
            document.LatestRevision.Bytes = content.Length;
        }

        /// <summary>
        /// Sets the value of the specified form field in the content
        /// </summary>
        /// <param name="content">The content in which to set the form field</param>
        /// <param name="fieldName">The name of the field to set</param>
        /// <param name="value">The value to set the field to</param>
        /// <returns>The updated content</returns>
        public byte[] SetPdfFormField(byte[] content, string fieldName, string value)
        {
            // Create a pdf reader to read the document content, and a pdf stamper to modify it and output to a memory stream
            var reader = new PdfReader(content);
            var oStream = new MemoryStream();
            var stamper = new PdfStamper(reader, oStream);

            // Set the form field
            stamper.AcroFields.SetField(fieldName, value);

            // Close the pdf stamper to flush the output memory stream
            stamper.Writer.CloseStream = false;
            stamper.Close();

            // Move the stream position to the beginning
            oStream.Seek(0, SeekOrigin.Begin);

            // Return updated content
            return oStream.ToArray();
        }

        /// <summary>
        /// Adds the image to the pdf document
        /// </summary>
        /// <param name="document">The document to annotate</param>
        /// <param name="imageDocument">The image document</param>
        public void AddImageToPdfDocument(Document document, Document imageDocument)
        {
            // Get image information
            var documentTypeImageCoOrdinates = document.Type.DocumentTypeImageCoOrdinates.FirstOrDefault(e => e.ImageDocumentType.Id == imageDocument.Type.Id);
            if (documentTypeImageCoOrdinates == null) return;

            // Create a pdf reader to read the document content, and a pdf stamper to modify it and output to a memory stream
            var reader = new PdfReader(document.LatestRevision.Content.Content);
            var oStream = new MemoryStream();
            var stamper = new PdfStamper(reader, oStream);

            // Get the image page of the PDF document object
            var pdfContentByte = stamper.GetOverContent(documentTypeImageCoOrdinates.PageNumber);

            // Create a white rectangle bitmap for the background image
            var bitmap = new Bitmap(documentTypeImageCoOrdinates.MaxWidth, documentTypeImageCoOrdinates.MaxHeight);
            using (var graphics = Graphics.FromImage(bitmap))
            {
                var rectangle = new System.Drawing.Rectangle(0, 0, documentTypeImageCoOrdinates.MaxWidth, documentTypeImageCoOrdinates.MaxHeight);
                graphics.FillRectangle(Brushes.White, rectangle);
            }

            // Draw the background image onto the pdf to clear any previous image
            var image = Image.GetInstance(bitmap, ImageFormat.Bmp);
            image.SetAbsolutePosition(documentTypeImageCoOrdinates.OriginX, documentTypeImageCoOrdinates.OriginY);
            pdfContentByte.AddImage(image);

            // Draw the image onto the pdf
            image = Image.GetInstance(imageDocument.LatestRevision.Content.Content);
            image.ScaleToFit(documentTypeImageCoOrdinates.MaxWidth, documentTypeImageCoOrdinates.MaxHeight);
            var differenceX = documentTypeImageCoOrdinates.MaxWidth - image.ScaledWidth;
            var differenceY = documentTypeImageCoOrdinates.MaxHeight - image.ScaledHeight;
            image.SetAbsolutePosition(
                differenceX > 0 ? documentTypeImageCoOrdinates.OriginX + (differenceX / 2) : documentTypeImageCoOrdinates.OriginX,
                differenceY > 0 ? documentTypeImageCoOrdinates.OriginY + (differenceY / 2) : documentTypeImageCoOrdinates.OriginY
                    );
            pdfContentByte.AddImage(image);

            // Close the pdf stamper to flush the output memory stream
            stamper.Writer.CloseStream = false;
            stamper.Close();

            // Move the stream position to the beginning
            oStream.Seek(0, SeekOrigin.Begin);

            // Update content, length and checksum
            var content = oStream.ToArray();
            document.LatestRevision.Content.Content = content;
            document.LatestRevision.Content.FileChecksum = GenerateFileChecksum(content);
            document.LatestRevision.Bytes = content.Length;
        }

        /// <summary>
        /// Returns a display name in the standard format for the supplied <paramref name="documentType">document type</paramref>.
        /// </summary>
        /// <param name="documentType">The document type to generate the display name for.</param>
        /// <returns>A display name in the standard format for the supplied <paramref name="documentType">document type</paramref>.</returns>
        public string StandardDocumentDisplayName(Type documentType)
        {
            var qmf = documentType.QualityManagementSystemCode == null || documentType.QualityManagementSystemCode.Trim().IsNullOrWhiteSpace()
                ? string.Empty
                : string.Format("{0} ", documentType.QualityManagementSystemCode.Trim());
            return string.Format("{0}{1}", qmf, documentType.Name);
        }

        /// <summary>
        /// Generates an e-mail to alert Mardix personnel that a network file write has failed due to the file path being too long
        /// </summary>
        /// <param name="filePath">The file path</param>
        private void EmailFilePathTooLongWarning(string filePath)
        {
            // Build up subject line
            var subject = Globalisation.Emails.FilePathTooLongSubject;

            // Build up subject body
            var body = Globalisation.Emails.FilePathTooLongBody.Replace(EmailServices.PlaceHolders.FilePath, filePath)
                                                    .Replace(EmailServices.PlaceHolders.FileWriteDateTime, SystemTime.UtcNow().ToLongDateAndTimeString());

            // Build up list of recipients
            var emailTo = new List<string>
            {
                _configurationManager.ServiceDepartment.EmailReportTeam,
                "e.hodkinson@mardix.co.uk",
                "softwaresupport@anordmardix.com"
            };

            try
            {
                emailTo.ForEach(e => _emailServices.Send(e, subject, body));
            }
            catch (Exception ex)
            {
                throw new SmtpException(ex.Message);
            }
        }

        /// <summary>
        /// Converts the <paramref name="image"/> to a byte array.
        /// </summary>
        /// <param name="image">The image to convert.</param>
        /// <param name="compressionLevel">The compression level to use.</param>
        /// <returns>The converted byte array.</returns>
        private static byte[] ConvertImageToBytes(System.Drawing.Image image, long compressionLevel)
        {
            if (compressionLevel < 0) compressionLevel = 0;
            else if (compressionLevel > 100) compressionLevel = 100;

            var imageCodecInfo = GetImageCodecInfo(ImageFormat.Jpeg);
            var encoder = Encoder.Quality;
            var encoderParameters = new EncoderParameters(1);
            var encoderParameter = new EncoderParameter(encoder, compressionLevel);
            encoderParameters.Param[0] = encoderParameter;
            
            using (var memoryStream = new MemoryStream())
            {
                image.Save(memoryStream, imageCodecInfo, encoderParameters);
                return memoryStream.ToArray();
            }
        }

        /// <summary>
        /// Returns the image codec info for the requested <paramref name="format"/>.
        /// </summary>
        /// <param name="format">The format to get the image codec info for.</param>
        /// <returns>The image codec info.</returns>
        private static ImageCodecInfo GetImageCodecInfo(ImageFormat format)
        {
            var codecs = ImageCodecInfo.GetImageDecoders();
            return codecs.FirstOrDefault(codec => codec.FormatID == format.Guid);
        }

        /// <summary>
        /// Returns a high quality shrunken image from the supplied <paramref name="image"/> using the requested <paramref name="scaleFactor">scale factor</paramref>.
        /// </summary>
        /// <param name="image">The image to shrink.</param>
        /// <param name="scaleFactor">The scale factor to use.</param>
        /// <returns>The shrunken image.</returns>
        private static System.Drawing.Image ShrinkImage(System.Drawing.Image image, float scaleFactor)
        {
            // http://weblogs.asp.net/gunnarpeipman/archive/2009/04/02/resizing-images-without-loss-of-quality.aspx

            var width = Convert.ToInt32(image.Width * scaleFactor);
            var height = Convert.ToInt32(image.Height * scaleFactor);

            var shrinkImage = new Bitmap(width, height);
            using (var graphics = Graphics.FromImage(shrinkImage))
            {
                graphics.CompositingQuality = CompositingQuality.HighQuality;
                graphics.SmoothingMode = SmoothingMode.HighQuality;
                graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                
                var rectangle = new System.Drawing.Rectangle(0, 0, width, height);
                graphics.DrawImage(image, rectangle);
            }
            return shrinkImage;
        }
        
        /// <summary>
        /// Creates an impersonation context for the specified network credentials
        /// </summary>
        /// <param name="domain">The domain of the network credentials</param>
        /// <param name="userName">The username of the network credentials</param>
        /// <param name="password">The password of the network credentials</param>
        /// <returns>The impersonation context</returns>
        private static WindowsImpersonationContext CreateImpersonationContext(string domain, string userName, string password)
        {
            var accessToken = IntPtr.Zero;
            var loggedOn = LogonUser(userName, domain, password, Logon32LogonInteractive, Logon32ProviderDefault, ref accessToken);

            // ReSharper disable LocalizableElement
            Console.Write("Impersonation logon attempt successful: {0}", loggedOn);
            // ReSharper restore LocalizableElement
            
            var identity = new WindowsIdentity(accessToken);
            return identity.Impersonate();
        }

        /// <summary>
        /// Reverts the user context to the original Windows user account
        /// <param name="impersonationContext">The active impersonation context from which to revert</param>
        /// </summary>
        private static void UndoImpersonationContext(WindowsImpersonationContext impersonationContext)
        {
            impersonationContext.Undo();
        }
    }
}