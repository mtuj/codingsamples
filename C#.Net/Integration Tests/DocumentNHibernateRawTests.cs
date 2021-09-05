using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using NHibernate.Linq;
using NUnit.Framework;
using Vision.Api.DotNet.ApplicationServices.Documents;
using Vision.Api.DotNet.ApplicationServices.DocumentTypes;
using Vision.Api.DotNet.ApplicationServices.Employees;
using Vision.Api.DotNet.ApplicationServices.Equipments;
using Vision.Api.DotNet.ApplicationServices.FileSystem;
using Vision.Api.DotNet.ApplicationServices.SiteVisitReports;
using Vision.Api.DotNet.Domain.Documents;
using Vision.Api.DotNet.Domain.Employees;
using Vision.Api.DotNet.Domain.SiteVisitReports;
using Vision.Api.DotNet.Tests.Common.DataExtractor;
using Document = Vision.Api.DotNet.Domain.Documents.Document;
using Equipment = Vision.Api.DotNet.Domain.Equipments.Equipment;
using SiteVisitReport = Vision.Api.DotNet.Tests.Common.DataGenerator.SiteVisitReport;
using Test = Vision.Api.DotNet.Domain.TestDocuments.Test;
using TestDocumentTemplate = Vision.Api.DotNet.Domain.TestDocuments.TestDocumentTemplate;

namespace Vision.Api.DotNet.Tests.Integration.Builder.Documents
{
    public class RawTests : OAuthBuilderTestBase
    {
        private IDocumentServices _documentServices;
        private IDocumentTypeServices _documentTypeServices;
        private IEquipmentServices _equipmentServices;
        private IEmployeeServices _employeeServices;
        private ISiteVisitReportStatusServices _siteVisitReportStatusServices;
        private IFileSystemServices _fileSystemServices;

        private List<EquipmentDocument> _equipmentDocuments;
        private List<SiteVisitReportEquipment> _siteVisitReportEquipment;
        private List<SiteVisitReportDocument> _siteVisitReportDocuments;
        private List<Report> _siteVisitReports;
        private List<TestDocumentTemplate> _testDocumentTemplates;
        private List<Test> _tests;
        private List<Document> _documents;

        [SetUp]
        protected override void SetUpForEachTest()
        {
            base.SetUpForEachTest();

            _documentServices = WindsorContainer.Resolve<IDocumentServices>();
            _documentTypeServices = WindsorContainer.Resolve<IDocumentTypeServices>();
            _equipmentServices = WindsorContainer.Resolve<IEquipmentServices>();
            _employeeServices = WindsorContainer.Resolve<IEmployeeServices>();
            _siteVisitReportStatusServices = WindsorContainer.Resolve<ISiteVisitReportStatusServices>();
            _fileSystemServices = WindsorContainer.Resolve<IFileSystemServices>();

            _equipmentDocuments = new List<EquipmentDocument>();
            _siteVisitReportEquipment = new List<SiteVisitReportEquipment>();
            _siteVisitReportDocuments = new List<SiteVisitReportDocument>();
            _siteVisitReports = new List<Report>();
            _testDocumentTemplates = new List<TestDocumentTemplate>();
            _tests = new List<Test>();
            _documents = new List<Document>();
        }

        [TearDown]
        protected void TearDownAfterEachTest()
        {
            var documentRevisionContents = new List<DocumentRevisionContent>();

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Delete all the equipment documents created for this session
                foreach (var equipmentDocument in _equipmentDocuments)
                {
                    var entity = session.Load<Equipment>(equipmentDocument.Equipment.Id);
                    var documentsToRemove = entity.Documents.Where(d => d.Id == equipmentDocument.Document.Id).ToList();
                    //entity.Documents.RemoveAll(documentsToRemove);
                    documentsToRemove.ForEach(e => entity.Documents.Remove(e));
                    session.SaveOrUpdate(entity);
                }
                session.Flush();

                // Delete all the site visit report documents for this session
                foreach (var siteVisitReportDocument in _siteVisitReportDocuments)
                {
                    var entity = session.Load<Report>(siteVisitReportDocument.Report.Id);
                    var documentsToRemove = entity.Documents.Where(sd => sd.Document.Id == siteVisitReportDocument.Document.Id).ToList();
                    //entity.Documents.RemoveAll(documentsToRemove);
                    documentsToRemove.ForEach(e => entity.Documents.Remove(e));
                    session.SaveOrUpdate(entity);
                }
                session.Flush();

                // Delete all the site visit report equipment created for this session
                foreach (var siteVisitReportEquipment in _siteVisitReportEquipment)
                {
                    var entity = session.Load<Report>(siteVisitReportEquipment.Report.Id);
                    var equipmentToRemove = entity.Equipment.Where(sa => sa.Equipment.Id == siteVisitReportEquipment.Equipment.Id).ToList();
                    //entity.Equipment.RemoveAll(equipmentToRemove);
                    equipmentToRemove.ForEach(e => entity.Equipment.Remove(e));
                    session.SaveOrUpdate(entity);
                }
                session.Flush();

                // Delete all the site visit reports created for this session
                foreach (var siteVisitReport in _siteVisitReports)
                {
                    var entity = session.Load<Report>(siteVisitReport.Id);
                    session.Delete(entity);
                }
                session.Flush();

                // Delete all the test document templates created for this session
                foreach (var testDocumentTemplate in _testDocumentTemplates)
                {
                    var entity = session.Load<TestDocumentTemplate>(testDocumentTemplate.Id);
                    session.Delete(entity);
                }
                session.Flush();

                // Delete all the tests created for this session
                foreach (var test in _tests)
                {
                    var entity = session.Load<Test>(test.Id);
                    session.Delete(entity);
                }
                session.Flush();

                // Delete all the documents created for this session
                foreach (var document in _documents)
                {
                    var entity = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);
                    foreach (var revision in entity.Revisions)
                    {
                        documentRevisionContents.Add(revision.Content);
                        session.Delete(revision);
                    }
                    session.Delete(entity);
                }
                session.Flush();

                // Delete all the document contents created for this session
                foreach (var documentRevisionContent in documentRevisionContents)
                {
                    var otherRevisions = session.Query<DocumentRevisionMetaData>().Where(m => m.Content.Id == documentRevisionContent.Id).ToList();
                    if (otherRevisions.Count == 0)
                        session.Delete(documentRevisionContent);
                }
                session.Flush();
            }
        }

        #region Documents

        /// <summary>
        /// Test to see if a document can be created with a single revision.
        /// </summary>
        [Test]
        public void CanCreateDocumentWithSingleRevision()
        {
            var originalDocument = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());

            // Create document
            var document = new Document
            {
                Type = originalDocument.Type,
                Description = "Document Refactor - Raw Document Test 1",
                Comments = "Document Refactor - Raw Document Test 1 Comments",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            // Add revision
            var documentRevisionMetaData = GiveMeADocumentRevisionMetaData(document, originalDocument); // Add revision
            document.Revisions.Add(documentRevisionMetaData);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Verify document
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                // Add persisted document to collection for tear-down
                _documents.Add(persistedDocument);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(1, persistedDocument.Revisions.Count);

                // Check properties of latest revision
                Assert.AreEqual(document.Type.Id, persistedDocument.Type.Id);
                Assert.AreEqual(document.Description, persistedDocument.Description);
                Assert.AreEqual(document.Comments, persistedDocument.Comments);
                Assert.AreEqual(document.LatestRevision.DisplayName, persistedDocument.LatestRevision.DisplayName);
                Assert.AreEqual(document.LatestRevision.FileName, persistedDocument.LatestRevision.FileName);
                Assert.AreEqual(document.LatestRevision.MimeType, persistedDocument.LatestRevision.MimeType);
                Assert.AreEqual(document.LatestRevision.Bytes, persistedDocument.LatestRevision.Bytes);
                Assert.AreEqual(document.LatestRevision.Content.FileChecksum, persistedDocument.LatestRevision.Content.FileChecksum);
                Assert.AreEqual(document.LatestRevision.Content.Content.Length, persistedDocument.LatestRevision.Content.Content.Length);
            }
        }

        /// <summary>
        /// Test to see if a document can be created with multiple revisions.
        /// </summary>
        [Test]
        public void CanCreateDocumentWithMultipleRevisions()
        {
            var originalDocument1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            Document originalDocument2;
            do originalDocument2 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { originalDocument1 });
            while (originalDocument2.LatestRevision.PublishedDateUtc == originalDocument1.LatestRevision.PublishedDateUtc);     // Ensure we have documents with different published dates

            // Create document
            var document = new Document
            {
                Type = originalDocument1.Type,
                Description = "Document Refactor - Raw Document Test 2",
                Comments = "Document Refactor - Raw Document Test 2 Comments",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentRevisionMetaData1 = GiveMeADocumentRevisionMetaData(document, originalDocument1);   // Add revision 1
            var documentRevisionMetaData2 = GiveMeADocumentRevisionMetaData(document, originalDocument2);   // Add revision 2
            document.Revisions.Add(documentRevisionMetaData1);
            document.Revisions.Add(documentRevisionMetaData2);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            var allRevisions = new List<DocumentRevisionMetaData> { documentRevisionMetaData1, documentRevisionMetaData2 };
            var latestRevision = allRevisions.FirstOrDefault(r => r.PublishedDateUtc == allRevisions.Max(rm => rm.PublishedDateUtc));

            // Verify document
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                // Add persisted document to collection for tear-down
                _documents.Add(persistedDocument);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(2, persistedDocument.Revisions.Count);

                // Check each revision exists in the database
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.FileName == documentRevisionMetaData1.FileName));
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.Content.Content.Length == documentRevisionMetaData1.Content.Content.Length));
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.FileName == documentRevisionMetaData2.FileName));
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.Content.Content.Length == documentRevisionMetaData2.Content.Content.Length));

                // Check properties of latest revision
                Assert.IsNotNull(latestRevision);
                Assert.AreEqual(document.Type.Id, persistedDocument.Type.Id);
                Assert.AreEqual(document.Description, persistedDocument.Description);
                Assert.AreEqual(document.Comments, persistedDocument.Comments);
                Assert.AreEqual(latestRevision.DisplayName, persistedDocument.LatestRevision.DisplayName);
                Assert.AreEqual(latestRevision.FileName, persistedDocument.LatestRevision.FileName);
                Assert.AreEqual(latestRevision.MimeType, persistedDocument.LatestRevision.MimeType);
                Assert.AreEqual(latestRevision.Bytes, persistedDocument.LatestRevision.Bytes);
                Assert.AreEqual(latestRevision.Content.FileChecksum, persistedDocument.LatestRevision.Content.FileChecksum);
                Assert.AreEqual(latestRevision.Content.Content.Length, persistedDocument.LatestRevision.Content.Content.Length);
            }
        }

        /// <summary>
        /// Test to see if a document revision can be added to an existing document.
        /// </summary>
        [Test]
        public void CanAddDocumentRevision()
        {
            var originalDocument1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            Document originalDocument2;
            do originalDocument2 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { originalDocument1 });
            while (originalDocument2.LatestRevision.PublishedDateUtc == originalDocument1.LatestRevision.PublishedDateUtc);     // Ensure we have documents with different published dates

            // Create document
            var document = new Document
            {
                Type = originalDocument1.Type,
                Description = "Document Refactor - Raw Document Test 3",
                Comments = "Document Refactor - Raw Document Test 3 Comments",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentRevisionMetaData1 = GiveMeADocumentRevisionMetaData(document, originalDocument1);   // Add revision 1
            document.Revisions.Add(documentRevisionMetaData1);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Verify document and add new revision
            DocumentRevisionMetaData documentRevisionMetaData2;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(1, persistedDocument.Revisions.Count);

                // Check properties of latest revision
                Assert.AreEqual(document.Type.Id, persistedDocument.Type.Id);
                Assert.AreEqual(document.Description, persistedDocument.Description);
                Assert.AreEqual(document.Comments, persistedDocument.Comments);
                Assert.AreEqual(documentRevisionMetaData1.DisplayName, persistedDocument.LatestRevision.DisplayName);
                Assert.AreEqual(documentRevisionMetaData1.FileName, persistedDocument.LatestRevision.FileName);
                Assert.AreEqual(documentRevisionMetaData1.MimeType, persistedDocument.LatestRevision.MimeType);
                Assert.AreEqual(documentRevisionMetaData1.Bytes, persistedDocument.LatestRevision.Bytes);
                Assert.AreEqual(documentRevisionMetaData1.Content.FileChecksum, persistedDocument.LatestRevision.Content.FileChecksum);
                Assert.AreEqual(documentRevisionMetaData1.Content.Content.Length, persistedDocument.LatestRevision.Content.Content.Length);

                // Create new revision
                documentRevisionMetaData2 = GiveMeADocumentRevisionMetaData(persistedDocument, originalDocument2);
                persistedDocument.Revisions.Add(documentRevisionMetaData2);
                session.SaveOrUpdate(persistedDocument);
                session.Flush();
            }

            var allRevisions = new List<DocumentRevisionMetaData> { documentRevisionMetaData1, documentRevisionMetaData2 };
            var latestRevision = allRevisions.FirstOrDefault(r => r.PublishedDateUtc == allRevisions.Max(rm => rm.PublishedDateUtc));

            // Verify document
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                // Add persisted document to collection for tear-down
                _documents.Add(persistedDocument);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(2, persistedDocument.Revisions.Count);

                // Check each revision exists in the database
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.FileName == documentRevisionMetaData1.FileName));
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.Content.Content.Length == documentRevisionMetaData1.Content.Content.Length));
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.FileName == documentRevisionMetaData2.FileName));
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.Content.Content.Length == documentRevisionMetaData2.Content.Content.Length));

                // Check properties of latest revision
                Assert.IsNotNull(latestRevision);
                Assert.AreEqual(document.Type.Id, persistedDocument.Type.Id);
                Assert.AreEqual(document.Description, persistedDocument.Description);
                Assert.AreEqual(document.Comments, persistedDocument.Comments);
                Assert.AreEqual(latestRevision.DisplayName, persistedDocument.LatestRevision.DisplayName);
                Assert.AreEqual(latestRevision.FileName, persistedDocument.LatestRevision.FileName);
                Assert.AreEqual(latestRevision.MimeType, persistedDocument.LatestRevision.MimeType);
                Assert.AreEqual(latestRevision.Bytes, persistedDocument.LatestRevision.Bytes);
                Assert.AreEqual(latestRevision.Content.FileChecksum, persistedDocument.LatestRevision.Content.FileChecksum);
                Assert.AreEqual(latestRevision.Content.Content.Length, persistedDocument.LatestRevision.Content.Content.Length);
            }
        }

        /// <summary>
        /// Test to see if a document revision can be removed from an existing document.
        /// </summary>
        [Test]
        public void CanRemoveDocumentRevision()
        {
            var originalDocument1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            var originalDocument2 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());

            // Create document
            var document = new Document
            {
                Type = originalDocument1.Type,
                Description = "Document Refactor - Raw Document Test 4",
                Comments = "Document Refactor - Raw Document Test 4 Comments",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentRevisionMetaData1 = GiveMeADocumentRevisionMetaData(document, originalDocument1);   // Add revision 1
            var documentRevisionMetaData2 = GiveMeADocumentRevisionMetaData(document, originalDocument2);   // Add revision 2
            document.Revisions.Add(documentRevisionMetaData1);
            document.Revisions.Add(documentRevisionMetaData2);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Delete one revision
            Guid contentId;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(2, persistedDocument.Revisions.Count);

                var revisionToDelete = persistedDocument.Revisions.First();
                contentId = revisionToDelete.Content.Id;
                persistedDocument.Revisions.Remove(revisionToDelete);
                session.SaveOrUpdate(persistedDocument);
                session.Flush();
            }

            // Verify document
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                // Add persisted document to collection for tear-down
                _documents.Add(persistedDocument);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(1, persistedDocument.Revisions.Count);
            }

            // Verify and delete content
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedContent = session.Query<DocumentRevisionContent>().FirstOrDefault(c => c.Id == contentId);

                // Confirm content has not been deleted
                Assert.IsNotNull(persistedContent);

                // Delete content
                session.Delete(persistedContent);
                session.Flush();
            }
        }

        /// <summary>
        /// Test to see if a document revision can be created explicitly.
        /// </summary>
        [Test]
        public void CanCreateDocumentRevisionExplicitly()
        {
            var originalDocument1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            Document originalDocument2;
            do originalDocument2 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { originalDocument1 });
            while (originalDocument2.LatestRevision.PublishedDateUtc == originalDocument1.LatestRevision.PublishedDateUtc);     // Ensure we have documents with different published dates

            // Create document
            var document = new Document
            {
                Type = originalDocument1.Type,
                Description = "Document Refactor - Raw Document Test 5",
                Comments = "Document Refactor - Raw Document Test 5 Comments",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentRevisionMetaData1 = GiveMeADocumentRevisionMetaData(document, originalDocument1);   // Add revision 1
            document.Revisions.Add(documentRevisionMetaData1);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Verify document and create new revision
            DocumentRevisionMetaData documentRevisionMetaData2;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(1, persistedDocument.Revisions.Count);

                // Check properties of latest revision
                Assert.AreEqual(document.Type.Id, persistedDocument.Type.Id);
                Assert.AreEqual(document.Description, persistedDocument.Description);
                Assert.AreEqual(document.Comments, persistedDocument.Comments);
                Assert.AreEqual(documentRevisionMetaData1.DisplayName, persistedDocument.LatestRevision.DisplayName);
                Assert.AreEqual(documentRevisionMetaData1.FileName, persistedDocument.LatestRevision.FileName);
                Assert.AreEqual(documentRevisionMetaData1.MimeType, persistedDocument.LatestRevision.MimeType);
                Assert.AreEqual(documentRevisionMetaData1.Bytes, persistedDocument.LatestRevision.Bytes);
                Assert.AreEqual(documentRevisionMetaData1.Content.FileChecksum, persistedDocument.LatestRevision.Content.FileChecksum);
                Assert.AreEqual(documentRevisionMetaData1.Content.Content.Length, persistedDocument.LatestRevision.Content.Content.Length);

                // Create new revision
                documentRevisionMetaData2 = GiveMeADocumentRevisionMetaData(persistedDocument, originalDocument2);
                session.SaveOrUpdate(documentRevisionMetaData2);
                session.Flush();
            }

            var allRevisions = new List<DocumentRevisionMetaData> { documentRevisionMetaData1, documentRevisionMetaData2 };
            var latestRevision = allRevisions.FirstOrDefault(r => r.PublishedDateUtc == allRevisions.Max(rm => rm.PublishedDateUtc));

            // Verify document
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                // Add persisted document to collection for tear-down
                _documents.Add(persistedDocument);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(2, persistedDocument.Revisions.Count);

                // Check each revision exists in the database
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.FileName == documentRevisionMetaData1.FileName));
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.Content.Content.Length == documentRevisionMetaData1.Content.Content.Length));
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.FileName == documentRevisionMetaData2.FileName));
                Assert.IsTrue(persistedDocument.Revisions.Any(r => r.Content.Content.Length == documentRevisionMetaData2.Content.Content.Length));

                // Check properties of latest revision
                Assert.IsNotNull(latestRevision);
                Assert.AreEqual(document.Type.Id, persistedDocument.Type.Id);
                Assert.AreEqual(document.Description, persistedDocument.Description);
                Assert.AreEqual(document.Comments, persistedDocument.Comments);
                Assert.AreEqual(latestRevision.DisplayName, persistedDocument.LatestRevision.DisplayName);
                Assert.AreEqual(latestRevision.FileName, persistedDocument.LatestRevision.FileName);
                Assert.AreEqual(latestRevision.MimeType, persistedDocument.LatestRevision.MimeType);
                Assert.AreEqual(latestRevision.Bytes, persistedDocument.LatestRevision.Bytes);
                Assert.AreEqual(latestRevision.Content.FileChecksum, persistedDocument.LatestRevision.Content.FileChecksum);
                Assert.AreEqual(latestRevision.Content.Content.Length, persistedDocument.LatestRevision.Content.Content.Length);
            }
        }

        /// <summary>
        /// Test to see if a document revision can be deleted explicitly.
        /// </summary>
        [Test]
        public void CanDeleteDocumentRevisionExplicitly()
        {
            var originalDocument1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            var originalDocument2 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());

            // Create document
            var document = new Document
            {
                Type = originalDocument1.Type,
                Description = "Document Refactor - Raw Document Test 6",
                Comments = "Document Refactor - Raw Document Test 6 Comments",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentRevisionMetaData1 = GiveMeADocumentRevisionMetaData(document, originalDocument1);   // Add revision 1
            var documentRevisionMetaData2 = GiveMeADocumentRevisionMetaData(document, originalDocument2);   // Add revision 2
            document.Revisions.Add(documentRevisionMetaData1);
            document.Revisions.Add(documentRevisionMetaData2);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Delete one revision
            DocumentRevisionMetaData revisionToDelete;
            Guid contentId;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(2, persistedDocument.Revisions.Count);

                revisionToDelete = persistedDocument.Revisions.First();
                contentId = revisionToDelete.Content.Id;
            }
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.Delete(revisionToDelete);
                session.Flush();
            }

            // Verify document
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);

                // Add persisted document to collection for tear-down
                _documents.Add(persistedDocument);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(1, persistedDocument.Revisions.Count);
            }

            // Verify and delete content
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedContent = session.Query<DocumentRevisionContent>().FirstOrDefault(c => c.Id == contentId);

                // Confirm content has not been deleted
                Assert.IsNotNull(persistedContent);

                // Delete content
                session.Delete(persistedContent);
                session.Flush();
            }
        }

        /// <summary>
        /// Test to see if deleting a document also deletes its revision.
        /// </summary>
        [Test]
        public void DeletingDocumentAlsoDeletesRevision()
        {
            var originalDocument = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());

            // Create document
            var document = new Document
            {
                Type = originalDocument.Type,
                Description = "Document Refactor - Raw Document Test 7",
                Comments = "Document Refactor - Raw Document Test 7 Comments",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentRevisionMetaData = GiveMeADocumentRevisionMetaData(document, originalDocument);   // Add revision
            document.Revisions.Add(documentRevisionMetaData);

            Guid contentId;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();

                var persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);
                var persistedRevision = session.Query<DocumentRevisionMetaData>().FirstOrDefault(r => r.Id == persistedDocument.LatestRevision.Id);

                Assert.IsNotNull(persistedRevision);
                var revisionId = persistedRevision.Id;
                contentId = persistedRevision.Content.Id;

                // Delete document
                session.Delete(persistedDocument);
                session.Flush();

                // Confirm the document and revision have both been deleted
                persistedDocument = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id);
                persistedRevision = session.Query<DocumentRevisionMetaData>().FirstOrDefault(r => r.Id == revisionId);

                Assert.IsNull(persistedDocument);
                Assert.IsNull(persistedRevision);
            }

            // Verify and delete content
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedContent = session.Query<DocumentRevisionContent>().FirstOrDefault(c => c.Id == contentId);

                // Confirm content has not been deleted
                Assert.IsNotNull(persistedContent);

                // Delete content
                session.Delete(persistedContent);
                session.Flush();
            }
        }

        #endregion

        #region Test Documents

        /// <summary>
        /// Test to see if a test document template can be created.
        /// </summary>
        [Test]
        public void CanCreateTestDocumentTemplate()
        {
            var originalDocument = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());

            // Create document and test document template
            var document = new Document
            {
                Type = originalDocument.Type,
                Description = "Document Refactor - Raw Document Test 8",
                Comments = "Document Refactor - Raw Document Test 8 Comments",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentRevisionMetaData = GiveMeADocumentRevisionMetaData(document, originalDocument); // Add revision
            document.Revisions.Add(documentRevisionMetaData);
            var testDocumentTemplate = new TestDocumentTemplate
            {
                Document = document,
                WoNumber = 12345,
                M0 = "M0Test"
            };

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.SaveOrUpdate(testDocumentTemplate);
                session.Flush();
            }

            // Verify test document template and document
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedTestDocumentTemplate = session.Query<TestDocumentTemplate>().FirstOrDefault(t => t.Id == testDocumentTemplate.Id);

                // Check properties of test document template
                Assert.IsNotNull(persistedTestDocumentTemplate);
                Assert.AreEqual(12345, persistedTestDocumentTemplate.WoNumber);
                Assert.AreEqual("M0Test", persistedTestDocumentTemplate.M0);

                var persistedDocument = persistedTestDocumentTemplate.Document;

                // Add persisted document to collection for tear-down
                _testDocumentTemplates.Add(persistedTestDocumentTemplate);
                _documents.Add(persistedDocument);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(1, persistedDocument.Revisions.Count);

                // Check properties of latest revision
                Assert.AreEqual(document.Type.Id, persistedDocument.Type.Id);
                Assert.AreEqual(document.Description, persistedDocument.Description);
                Assert.AreEqual(document.Comments, persistedDocument.Comments);
                Assert.AreEqual(document.LatestRevision.DisplayName, persistedDocument.LatestRevision.DisplayName);
                Assert.AreEqual(document.LatestRevision.FileName, persistedDocument.LatestRevision.FileName);
                Assert.AreEqual(document.LatestRevision.MimeType, persistedDocument.LatestRevision.MimeType);
                Assert.AreEqual(document.LatestRevision.Bytes, persistedDocument.LatestRevision.Bytes);
                Assert.AreEqual(document.LatestRevision.Content.FileChecksum, persistedDocument.LatestRevision.Content.FileChecksum);
                Assert.AreEqual(document.LatestRevision.Content.Content.Length, persistedDocument.LatestRevision.Content.Content.Length);
            }

            // Clean up
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.Delete(testDocumentTemplate);
            }
        }

        /// <summary>
        /// Test to see if a test session test can be created.
        /// </summary>
        [Test]
        public void CanCreateTestSessionTest()
        {
            var originalDocument = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());

            // Create document and test document template
            var document = new Document
            {
                Type = originalDocument.Type,
                Description = "Document Refactor - Raw Document Test 9",
                Comments = "Document Refactor - Raw Document Test 9 Comments",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentRevisionMetaData = GiveMeADocumentRevisionMetaData(document, originalDocument); // Add revision
            document.Revisions.Add(documentRevisionMetaData);
            var test = new Test
            {
                Document = document,
                InstrumentReference = "InstrumentReferenceTest",
                Voltage = "VoltageTest",
                CircuitBreakerReference = "CircuitBreakerReferenceTest",
            };

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.SaveOrUpdate(test);
                session.Flush();
            }

            // Verify test document template and document
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedTest = session.Query<Test>().FirstOrDefault(t => t.Id == test.Id);

                // Check properties of test document template
                Assert.IsNotNull(persistedTest);
                Assert.AreEqual("InstrumentReferenceTest", persistedTest.InstrumentReference);
                Assert.AreEqual("VoltageTest", persistedTest.Voltage);
                Assert.AreEqual("CircuitBreakerReferenceTest", persistedTest.CircuitBreakerReference);

                var persistedDocument = persistedTest.Document;

                // Add persisted document to collection for tear-down
                _tests.Add(persistedTest);
                _documents.Add(persistedDocument);

                Assert.IsNotNull(persistedDocument);
                Assert.AreEqual(1, persistedDocument.Revisions.Count);

                // Check properties of latest revision
                Assert.AreEqual(document.Type.Id, persistedDocument.Type.Id);
                Assert.AreEqual(document.Description, persistedDocument.Description);
                Assert.AreEqual(document.Comments, persistedDocument.Comments);
                Assert.AreEqual(document.LatestRevision.DisplayName, persistedDocument.LatestRevision.DisplayName);
                Assert.AreEqual(document.LatestRevision.FileName, persistedDocument.LatestRevision.FileName);
                Assert.AreEqual(document.LatestRevision.MimeType, persistedDocument.LatestRevision.MimeType);
                Assert.AreEqual(document.LatestRevision.Bytes, persistedDocument.LatestRevision.Bytes);
                Assert.AreEqual(document.LatestRevision.Content.FileChecksum, persistedDocument.LatestRevision.Content.FileChecksum);
                Assert.AreEqual(document.LatestRevision.Content.Content.Length, persistedDocument.LatestRevision.Content.Content.Length);
            }

            // Clean up
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.Delete(test);
            }
        }

        #endregion

        #region Equipment Documents

        /// <summary>
        /// Test to see if an equipment can be updated to add a document to the Documents collection
        /// </summary>
        /// <remarks>Equipment retrieved from domain should include added document</remarks>
        [Test]
        public void CanUpdateEquipmentToAddDocument()
        {
            // Create document
            var document = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Get an equipment and add the document to its Documents collection
            var equipment = GiveMeSomeEquipment(1)[0];
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id);
                equipment.Documents.Add(document);
                session.SaveOrUpdate(equipment);
                session.Flush();
            }

            // Verify equipment
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedEquipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id);
                Assert.Greater(persistedEquipment.Documents.Count, 0);
                Assert.IsTrue(persistedEquipment.Documents.Any(d => d.Id == document.Id));
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                _documents.Add(document);
                _equipmentDocuments.AddRange(session.Query<EquipmentDocument>().Where(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document.Id));
            }
        }

        /// <summary>
        /// Test to see if an equipment can be updated to remove a document from the Documents collection
        /// </summary>
        /// <remarks>Equipment retrieved from domain should not include removed document</remarks>
        /// <remarks>Equipment documents retrieved from domain should not exist</remarks>
        /// <remarks>Document retrieved from domain should still exist</remarks>
        [Test]
        public void CanUpdateEquipmentToRemoveDocument()
        {
            // Create some documents
            var document1 = GiveMeADocument();
            var document2 = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.SaveOrUpdate(document2);
                session.Flush();
            }

            // Get an equipment and add the documents to its Documents collection
            var equipment = GiveMeSomeEquipment(1)[0];
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var equipmentDocument1 = new EquipmentDocument
                {
                    Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id)
                };
                var equipmentDocument2 = new EquipmentDocument
                {
                    Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id)
                };
                session.SaveOrUpdate(equipmentDocument1);
                session.SaveOrUpdate(equipmentDocument2);
                session.Flush();
            }

            // Remove one document from the equipment's Documents collection
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedEquipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id);
                var documentToRemove = persistedEquipment.Documents.FirstOrDefault(d => d.Id == document1.Id);
                persistedEquipment.Documents.Remove(documentToRemove);
                session.SaveOrUpdate(persistedEquipment);
                session.Flush();
            }

            // Verify equipment
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedEquipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id);
                var persistedEquipmentDocument1 = session.Query<EquipmentDocument>().FirstOrDefault(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document1.Id);
                var persistedEquipmentDocument2 = session.Query<EquipmentDocument>().FirstOrDefault(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document2.Id);
                var persistedDocument1 = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id);
                var persistedDocument2 = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id);
                Assert.Greater(persistedEquipment.Documents.Count, 0);
                Assert.IsFalse(persistedEquipment.Documents.Any(d => d.Id == document1.Id));
                Assert.IsTrue(persistedEquipment.Documents.Any(d => d.Id == document2.Id));
                Assert.IsNull(persistedEquipmentDocument1);
                Assert.IsNotNull(persistedEquipmentDocument2);
                Assert.IsNotNull(persistedDocument1);
                Assert.IsNotNull(persistedDocument2);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                _documents.Add(document1);
                _documents.Add(document2);
                _equipmentDocuments.AddRange(session.Query<EquipmentDocument>().Where(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document1.Id));
                _equipmentDocuments.AddRange(session.Query<EquipmentDocument>().Where(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document2.Id));
            }
        }

        /// <summary>
        /// Test to see if an equipment document can be added to the domain directly
        /// </summary>
        /// <remarks>Equipment retrieved from domain should include added document</remarks>
        [Test]
        public void CanAddEquipmentDocumentExplicitly()
        {
            // Create document
            var document = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Get an equipment and add the document to its Documents collection
            var equipment = GiveMeSomeEquipment(1)[0];
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var equipmentDocument = new EquipmentDocument
                {
                    Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id)
                };
                session.SaveOrUpdate(equipmentDocument);
                session.Flush();
            }

            // Verify equipment
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedEquipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id);
                Assert.Greater(persistedEquipment.Documents.Count, 0);
                Assert.IsTrue(persistedEquipment.Documents.Any(d => d.Id == document.Id));
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                _documents.Add(document);
                _equipmentDocuments.AddRange(session.Query<EquipmentDocument>().Where(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document.Id));
            }
        }

        /// <summary>
        /// Test to see if an equipment document can be deleted from the domain directly
        /// </summary>
        /// <remarks>Equipment retrieved from domain should not include removed document</remarks>
        /// <remarks>Equipment documents retrieved from domain should not exist</remarks>
        /// <remarks>Document retrieved from domain should still exist</remarks>
        [Test]
        public void CanRemoveEquipmentDocumentExplicitly()
        {
            // Create some documents
            var document1 = GiveMeADocument();
            var document2 = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.SaveOrUpdate(document2);
                session.Flush();
            }

            // Get an equipment and add the documents to its Documents collection
            var equipment = GiveMeSomeEquipment(1)[0];
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var equipmentDocument1 = new EquipmentDocument
                {
                    Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id)
                };
                var equipmentDocument2 = new EquipmentDocument
                {
                    Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id)
                };
                session.SaveOrUpdate(equipmentDocument1);
                session.SaveOrUpdate(equipmentDocument2);
                session.Flush();
            }

            // Remove one document from the equipment's Documents collection
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var equipmentDocumentToRemove = session.Query<EquipmentDocument>().FirstOrDefault(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document1.Id);
                session.Delete(equipmentDocumentToRemove);
                session.Flush();
            }

            // Verify equipment
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedEquipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id);
                var persistedEquipmentDocument1 = session.Query<EquipmentDocument>().FirstOrDefault(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document1.Id);
                var persistedEquipmentDocument2 = session.Query<EquipmentDocument>().FirstOrDefault(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document2.Id);
                var persistedDocument1 = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id);
                var persistedDocument2 = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id);
                Assert.Greater(persistedEquipment.Documents.Count, 0);
                Assert.IsFalse(persistedEquipment.Documents.Any(d => d.Id == document1.Id));
                Assert.IsTrue(persistedEquipment.Documents.Any(d => d.Id == document2.Id));
                Assert.IsNull(persistedEquipmentDocument1);
                Assert.IsNotNull(persistedEquipmentDocument2);
                Assert.IsNotNull(persistedDocument1);
                Assert.IsNotNull(persistedDocument2);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                _documents.Add(document1);
                _documents.Add(document2);
                _equipmentDocuments.AddRange(session.Query<EquipmentDocument>().Where(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document1.Id));
                _equipmentDocuments.AddRange(session.Query<EquipmentDocument>().Where(ad => ad.Equipment.Id == equipment.Id && ad.Document.Id == document2.Id));
            }
        }

        #endregion

        #region Site Visit Report Equipment

        /// <summary>
        /// Test to see if a site visit report can be updated to add an equipment to the Equipment collection
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should include added equipment</remarks>
        [Test]
        public void CanUpdateSiteVisitReportToAddEquipment()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Get some equipment and add them to the site visit report's Equipment collection
            var equipments = GiveMeSomeEquipment(3);
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                foreach (var equipment in equipments)
                {
                    persistedSiteVisitReport.Equipment.Add(new SiteVisitReportEquipment { Equipment = equipment, Report = persistedSiteVisitReport });
                }
                session.SaveOrUpdate(persistedSiteVisitReport);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                Assert.Greater(persistedSiteVisitReport.Equipment.Count, 0);
                foreach (var siteVisitReportEquipment in persistedSiteVisitReport.Equipment)
                {
                    Assert.IsTrue(equipments.Any(a => a.Id == siteVisitReportEquipment.Equipment.Id));
                }
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                _siteVisitReports.Add(siteVisitReport);
                foreach (var equipment in equipments)
                {
                    _siteVisitReportEquipment.Add(session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment.Id));
                }
            }
        }

        /// <summary>
        /// Test to see if a site visit report can be updated to remove an equipment from the Equipment collection
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should not include removed equipment</remarks>
        /// <remarks>Site visit report equipment retrieved from domain should not exist</remarks>
        /// <remarks>Equipment retrieved from domain should still exist</remarks>
        [Test]
        public void CanUpdateSiteVisitReportToRemoveEquipment()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Get some equipment and add them to the site visit report's Equipment collection
            var equipments = GiveMeSomeEquipment(3);
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                foreach (var equipment in equipments)
                {
                    var siteVisitReportEquipment = new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    };
                    session.SaveOrUpdate(siteVisitReportEquipment);
                }
                session.Flush();
            }

            // Remove one equipment from the site visit report's Equipment collection
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var equipmentToRemove = persistedSiteVisitReport.Equipment.FirstOrDefault(a => a.Equipment.Id == equipments[0].Id);
                persistedSiteVisitReport.Equipment.Remove(equipmentToRemove);
                session.SaveOrUpdate(persistedSiteVisitReport);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var persistedSiteVisitReportEquipment1 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[0].Id);
                var persistedSiteVisitReportEquipment2 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[1].Id);
                var persistedSiteVisitReportEquipment3 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[2].Id);
                var persistedEquipment1 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipments[0].Id);
                var persistedEquipment2 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipments[1].Id);
                var persistedEquipment3 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipments[2].Id);
                Assert.AreEqual(2, persistedSiteVisitReport.Equipment.Count);
                Assert.IsFalse(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipments[0].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipments[1].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipments[2].Id));
                Assert.IsNull(persistedSiteVisitReportEquipment1);
                Assert.IsNotNull(persistedSiteVisitReportEquipment2);
                Assert.IsNotNull(persistedSiteVisitReportEquipment3);
                Assert.IsNotNull(persistedEquipment1);
                Assert.IsNotNull(persistedEquipment2);
                Assert.IsNotNull(persistedEquipment3);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                _siteVisitReports.Add(siteVisitReport);
                _siteVisitReportEquipment.AddRange(session.Query<SiteVisitReportEquipment>().Where(sa => sa.Report.Id == siteVisitReport.Id));
            }
        }

        /// <summary>
        /// Test to see if a site visit report equipment can be added to the domain directly
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should include added equipment</remarks>
        [Test]
        public void CanAddSiteVisitReportEquipmentExplicitly()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Get some equipment and add them to the site visit report's Equipment collection
            var equipments = GiveMeSomeEquipment(3);
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                foreach (var equipment in equipments)
                {
                    var siteVisitReportEquipment = new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    };
                    session.SaveOrUpdate(siteVisitReportEquipment);
                }
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                Assert.Greater(persistedSiteVisitReport.Equipment.Count, 0);
                foreach (var siteVisitReportEquipment in persistedSiteVisitReport.Equipment)
                {
                    Assert.IsTrue(equipments.Any(a => a.Id == siteVisitReportEquipment.Equipment.Id));
                }
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                _siteVisitReports.Add(siteVisitReport);
                foreach (var equipment in equipments)
                {
                    _siteVisitReportEquipment.Add(session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment.Id));
                }
            }
        }

        /// <summary>
        /// Test to see if a site visit report equipment can be deleted from the domain directly
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should not include removed equipment</remarks>
        /// <remarks>Site visit report equipment retrieved from domain should not exist</remarks>
        /// <remarks>Equipment retrieved from domain should still exist</remarks>
        [Test]
        public void CanRemoveSiteVisitReportEquipmentExplicitly()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Get some equipment and add them to the site visit report's Equipment collection
            var equipments = GiveMeSomeEquipment(3);
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                foreach (var equipment in equipments)
                {
                    var siteVisitReportEquipment = new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    };
                    session.SaveOrUpdate(siteVisitReportEquipment);
                }
                session.Flush();
            }

            // Remove one equipment item from the site vist report's Equipment collection
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportEquipmentToRemove = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[0].Id);
                session.Delete(siteVisitReportEquipmentToRemove);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var persistedSiteVisitReportEquipment1 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[0].Id);
                var persistedSiteVisitReportEquipment2 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[1].Id);
                var persistedSiteVisitReportEquipment3 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[2].Id);
                var persistedEquipment1 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipments[0].Id);
                var persistedEquipment2 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipments[1].Id);
                var persistedEquipment3 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipments[2].Id);
                Assert.AreEqual(2, persistedSiteVisitReport.Equipment.Count);
                Assert.IsFalse(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipments[0].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipments[1].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipments[2].Id));
                Assert.IsNull(persistedSiteVisitReportEquipment1);
                Assert.IsNotNull(persistedSiteVisitReportEquipment2);
                Assert.IsNotNull(persistedSiteVisitReportEquipment3);
                Assert.IsNotNull(persistedEquipment1);
                Assert.IsNotNull(persistedEquipment2);
                Assert.IsNotNull(persistedEquipment3);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                _siteVisitReports.Add(siteVisitReport);
                _siteVisitReportEquipment.AddRange(session.Query<SiteVisitReportEquipment>().Where(sa => sa.Report.Id == siteVisitReport.Id));
            }
        }

        /// <summary>
        /// Test to see if a site visit report with equipment can be deleted
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should not exist</remarks>
        /// <remarks>Site visit report equipment retrieved from domain should not exist</remarks>
        /// <remarks>Equipment retrieved from domain should still exist</remarks>
        [Test]
        public void CanDeleteSiteVisitReportWithEquipment()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Get some equipment and add them to the site visit report's Equipment collection
            var equipments = GiveMeSomeEquipment(3);
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                foreach (var equipment in equipments)
                {
                    var siteVisitReportEquipment = new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    };
                    session.SaveOrUpdate(siteVisitReportEquipment);
                }
                session.Flush();
            }

            // Verify site visit report prior to deletion
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                Assert.AreEqual(3, persistedSiteVisitReport.Equipment.Count);
                session.Flush();
            }

            // Delete site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                session.Delete(persistedSiteVisitReport);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var persistedSiteVisitReportEquipment1 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[0].Id);
                var persistedSiteVisitReportEquipment2 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[1].Id);
                var persistedSiteVisitReportEquipment3 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipments[2].Id);
                var persistedEquipment1 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipments[0].Id);
                var persistedEquipment2 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipments[1].Id);
                var persistedEquipment3 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipments[2].Id);
                Assert.IsNull(persistedSiteVisitReport);
                Assert.IsNull(persistedSiteVisitReportEquipment1);
                Assert.IsNull(persistedSiteVisitReportEquipment2);
                Assert.IsNull(persistedSiteVisitReportEquipment3);
                Assert.IsNotNull(persistedEquipment1);
                Assert.IsNotNull(persistedEquipment2);
                Assert.IsNotNull(persistedEquipment3);
            }
        }

        #endregion

        #region Site Visit Report Documents

        #region Without Site Visit Report Equipment

        /// <summary>
        /// Test to see if a site visit report can be updated to add a document (without equipment) to the Documents collection
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should include added document</remarks>
        [Test]
        public void CanUpdateSiteVisitReportToAddDocumentWithoutEquipment()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create document
            var document = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Add the document to the site visit report's Documents collection
            var engineer = new Engineer(_employeeServices).RandomEngineer();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                persistedSiteVisitReport.Documents.Add(new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(),
                    CreatedBy = engineer
                });
                session.SaveOrUpdate(persistedSiteVisitReport);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                Assert.AreEqual(1, persistedSiteVisitReport.Documents.Count);
                var siteVisitReportDocument = persistedSiteVisitReport.Documents.ToList()[0];
                Assert.AreEqual(document.Id, siteVisitReportDocument.Document.Id);
                Assert.AreEqual(engineer.Id, siteVisitReportDocument.CreatedBy.Id);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                _siteVisitReports.Add(persistedSiteVisitReport);
                _siteVisitReportDocuments.AddRange(persistedSiteVisitReport.Documents);
                _documents.AddRange(persistedSiteVisitReport.Documents.Select(sd => sd.Document));
            }
        }

        /// <summary>
        /// Test to see if a site visit report can be updated to remove a document (without equipment) from the Documents collection
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should not include removed document</remarks>
        /// <remarks>Site visit report documents retrieved from domain should not exist</remarks>
        /// <remarks>Document retrieved from domain should still exist</remarks>
        /// <remarks>Creator retrieved from domain should still exist</remarks>
        [Test]
        public void CanUpdateSiteVisitReportToRemoveDocumentWithoutEquipment()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create some documents
            var document1 = GiveMeADocument();
            var document2 = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.SaveOrUpdate(document2);
                session.Flush();
            }

            // Add the documents to the site visit report's Documents collection
            var engineer1 = new Engineer(_employeeServices).RandomEngineer();
            var engineer2 = new Engineer(_employeeServices).RandomEngineer();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocument1 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(),
                    CreatedBy = engineer1
                };
                var siteVisitReportDocument2 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(),
                    CreatedBy = engineer2
                };
                session.SaveOrUpdate(siteVisitReportDocument1);
                session.SaveOrUpdate(siteVisitReportDocument2);
                session.Flush();
            }

            // Remove one document from the site visit report's Documents collection
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var documentToRemove = persistedSiteVisitReport.Documents.FirstOrDefault(d => d.Document.Id == document1.Id);
                persistedSiteVisitReport.Documents.Remove(documentToRemove);
                session.SaveOrUpdate(persistedSiteVisitReport);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var persistedSiteVisitReportDocument1 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document1.Id);
                var persistedSiteVisitReportDocument2 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document2.Id);
                var persistedDocument1 = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id);
                var persistedDocument2 = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id);
                var persistedEngineer1 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer1.Id);
                var persistedEngineer2 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer2.Id);
                Assert.Greater(persistedSiteVisitReport.Documents.Count, 0);
                Assert.IsFalse(persistedSiteVisitReport.Documents.Any(d => d.Document.Id == document1.Id));
                Assert.IsTrue(persistedSiteVisitReport.Documents.Any(d => d.Document.Id == document2.Id));
                Assert.IsNull(persistedSiteVisitReportDocument1);
                Assert.IsNotNull(persistedSiteVisitReportDocument2);
                Assert.IsNotNull(persistedDocument1);
                Assert.IsNotNull(persistedDocument2);
                Assert.IsNotNull(persistedEngineer1);
                Assert.IsNotNull(persistedEngineer2);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                _siteVisitReports.Add(persistedSiteVisitReport);
                _siteVisitReportDocuments.AddRange(persistedSiteVisitReport.Documents);
                _documents.AddRange(persistedSiteVisitReport.Documents.Select(sd => sd.Document));
            }
        }

        /// <summary>
        /// Test to see if a site visit report document (without equipment) can be added to the domain directly
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should include added document</remarks>
        [Test]
        public void CanAddSiteVisitReportDocumentWithoutEquipmentExplicitly()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create document
            var document = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Add the document to the site visit report's Documents collection
            var engineer = new Engineer(_employeeServices).RandomEngineer();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocument = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(),
                    CreatedBy = engineer
                };
                session.SaveOrUpdate(siteVisitReportDocument);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                Assert.AreEqual(1, persistedSiteVisitReport.Documents.Count);
                var siteVisitReportDocument = persistedSiteVisitReport.Documents.ToList()[0];
                Assert.AreEqual(document.Id, siteVisitReportDocument.Document.Id);
                Assert.AreEqual(engineer.Id, siteVisitReportDocument.CreatedBy.Id);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                _siteVisitReports.Add(persistedSiteVisitReport);
                _siteVisitReportDocuments.AddRange(persistedSiteVisitReport.Documents);
                _documents.AddRange(persistedSiteVisitReport.Documents.Select(sd => sd.Document));
            }
        }

        /// <summary>
        /// Test to see if a site visit report document (without equipment) can be deleted from the domain directly
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should not include removed document</remarks>
        /// <remarks>Site visit report documents retrieved from domain should not exist</remarks>
        /// <remarks>Document retrieved from domain should still exist</remarks>
        /// <remarks>Creator retrieved from domain should still exist</remarks>
        [Test]
        public void CanRemoveSiteVisitReportDocumentWithoutEquipmentExplicitly()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create some documents
            var document1 = GiveMeADocument();
            var document2 = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.SaveOrUpdate(document2);
                session.Flush();
            }

            // Add the documents to the site visit report's Documents collection
            var engineer1 = new Engineer(_employeeServices).RandomEngineer();
            var engineer2 = new Engineer(_employeeServices).RandomEngineer();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocument1 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(),
                    CreatedBy = engineer1
                };
                var siteVisitReportDocument2 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(),
                    CreatedBy = engineer2
                };
                session.SaveOrUpdate(siteVisitReportDocument1);
                session.SaveOrUpdate(siteVisitReportDocument2);
                session.Flush();
            }

            // Remove one document from the site visit report's Documents collection
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocumentToRemove = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document1.Id);
                session.Delete(siteVisitReportDocumentToRemove);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var persistedSiteVisitReportDocument1 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document1.Id);
                var persistedSiteVisitReportDocument2 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document2.Id);
                var persistedDocument1 = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id);
                var persistedDocument2 = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id);
                var persistedEngineer1 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer1.Id);
                var persistedEngineer2 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer2.Id);
                Assert.Greater(persistedSiteVisitReport.Documents.Count, 0);
                Assert.IsFalse(persistedSiteVisitReport.Documents.Any(d => d.Document.Id == document1.Id));
                Assert.IsTrue(persistedSiteVisitReport.Documents.Any(d => d.Document.Id == document2.Id));
                Assert.IsNull(persistedSiteVisitReportDocument1);
                Assert.IsNotNull(persistedSiteVisitReportDocument2);
                Assert.IsNotNull(persistedDocument1);
                Assert.IsNotNull(persistedDocument2);
                Assert.IsNotNull(persistedEngineer1);
                Assert.IsNotNull(persistedEngineer2);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                _siteVisitReports.Add(persistedSiteVisitReport);
                _siteVisitReportDocuments.AddRange(persistedSiteVisitReport.Documents);
                _documents.AddRange(persistedSiteVisitReport.Documents.Select(sd => sd.Document));
            }
        }

        /// <summary>
        /// Test to see if a site visit report with document (without equipment) can be deleted
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should not exist</remarks>
        /// <remarks>Site visit report document retrieved from domain should not exist</remarks>
        /// <remarks>Document retrieved from domain should still exist</remarks>
        /// <remarks>Creator retrieved from domain should still exist</remarks>
        [Test]
        public void CanDeleteSiteVisitReportWithDocumentWithoutEquipment()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create some documents
            var document1 = GiveMeADocument();
            var document2 = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.SaveOrUpdate(document2);
                session.Flush();
            }

            // Add the documents to the site visit report's Documents collection
            var engineer1 = new Engineer(_employeeServices).RandomEngineer();
            var engineer2 = new Engineer(_employeeServices).RandomEngineer();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocument1 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(),
                    CreatedBy = engineer1
                };
                var siteVisitReportDocument2 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(),
                    CreatedBy = engineer2
                };
                session.SaveOrUpdate(siteVisitReportDocument1);
                session.SaveOrUpdate(siteVisitReportDocument2);
                session.Flush();
            }

            // Delete site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                session.Delete(persistedSiteVisitReport);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var persistedSiteVisitReportDocument1 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document1.Id);
                var persistedSiteVisitReportDocument2 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document2.Id);
                var persistedDocument1 = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id);
                var persistedDocument2 = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id);
                var persistedEngineer1 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer1.Id);
                var persistedEngineer2 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer2.Id);
                Assert.IsNull(persistedSiteVisitReport);
                Assert.IsNull(persistedSiteVisitReportDocument1);
                Assert.IsNull(persistedSiteVisitReportDocument2);
                Assert.IsNotNull(persistedDocument1);
                Assert.IsNotNull(persistedDocument2);
                Assert.IsNotNull(persistedEngineer1);
                Assert.IsNotNull(persistedEngineer2);
            }

            // Add persisted objects to collection for tear-down
            _documents.Add(document1);
            _documents.Add(document2);
        }

        #endregion

        #region With Site Visit Report Equipment

        /// <summary>
        /// Test to see if a site visit report can be updated to add a document (with equipment) to the Documents collection
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should include added document, including equipment</remarks>
        [Test]
        public void CanUpdateSiteVisitReportToAddDocumentWithEquipment()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create document
            var document = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Add the document to the site visit report's Documents collection
            var equipment = GiveMeSomeEquipment(3);
            var engineer = new Engineer(_employeeServices).RandomEngineer();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                persistedSiteVisitReport.Documents.Add(new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(equipment.Select(e => new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == e.Id)
                    }).ToList()),
                    CreatedBy = engineer
                });
                session.SaveOrUpdate(persistedSiteVisitReport);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                Assert.AreEqual(1, persistedSiteVisitReport.Documents.Count);
                var siteVisitReportDocument = persistedSiteVisitReport.Documents.ToList()[0];
                Assert.AreEqual(document.Id, siteVisitReportDocument.Document.Id);
                Assert.AreEqual(3, siteVisitReportDocument.SiteVisitReportEquipment.Count);
                foreach (var siteVisitReportEquipment in persistedSiteVisitReport.Documents.SelectMany(sd => sd.SiteVisitReportEquipment))
                {
                    Assert.IsTrue(equipment.Any(a => a.Id == siteVisitReportEquipment.Equipment.Id));
                }
                Assert.AreEqual(engineer.Id, siteVisitReportDocument.CreatedBy.Id);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                _siteVisitReports.Add(persistedSiteVisitReport);
                _siteVisitReportDocuments.AddRange(persistedSiteVisitReport.Documents);
                _siteVisitReportEquipment.AddRange(persistedSiteVisitReport.Documents.SelectMany(sd => sd.SiteVisitReportEquipment));
                _documents.AddRange(persistedSiteVisitReport.Documents.Select(sd => sd.Document));
            }
        }

        /// <summary>
        /// Test to see if a site visit report can be updated to remove a document (with equipment) from the Documents collection
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should not include removed document</remarks>
        /// <remarks>Site visit report documents retrieved from domain should not exist</remarks>
        /// <remarks>Document retrieved from domain should still exist</remarks>
        /// <remarks>Site visit report equipment retrieved from domain should still exist</remarks>
        /// <remarks>Equipment retrieved from domain should still exist</remarks>
        /// <remarks>Creator retrieved from domain should still exist</remarks>
        [Test]
        public void CanUpdateSiteVisitReportToRemoveDocumentWithEquipment()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create some documents
            var document1 = GiveMeADocument();
            var document2 = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.SaveOrUpdate(document2);
                session.Flush();
            }

            // Add the documents to the site visit report's Documents collection
            var engineer1 = new Engineer(_employeeServices).RandomEngineer();
            var engineer2 = new Engineer(_employeeServices).RandomEngineer();
            var equipment1 = GiveMeSomeEquipment(3);
            var equipment2 = GiveMeSomeEquipment(3);
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocument1 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(equipment1.Select(equipment => new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    }).ToList()),
                    CreatedBy = engineer1
                };
                var siteVisitReportDocument2 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(equipment2.Select(equipment => new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    }).ToList()),
                    CreatedBy = engineer2
                };
                session.SaveOrUpdate(siteVisitReportDocument1);
                session.SaveOrUpdate(siteVisitReportDocument2);
                session.Flush();
            }

            // Remove one document from the site visit report's Documents collection
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var documentToRemove = persistedSiteVisitReport.Documents.FirstOrDefault(d => d.Document.Id == document1.Id);
                persistedSiteVisitReport.Documents.Remove(documentToRemove);
                session.SaveOrUpdate(persistedSiteVisitReport);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var persistedSiteVisitReportDocument1 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document1.Id);
                var persistedSiteVisitReportDocument2 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document2.Id);
                var persistedSiteVisitReportEquipment11 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment1[0].Id);
                var persistedSiteVisitReportEquipment12 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment1[1].Id);
                var persistedSiteVisitReportEquipment13 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment1[2].Id);
                var persistedSiteVisitReportEquipment21 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment2[0].Id);
                var persistedSiteVisitReportEquipment22 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment2[1].Id);
                var persistedSiteVisitReportEquipment23 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment2[2].Id);
                var persistedDocument1 = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id);
                var persistedDocument2 = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id);
                var persistedEquipment11 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment1[0].Id);
                var persistedEquipment12 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment1[1].Id);
                var persistedEquipment13 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment1[2].Id);
                var persistedEquipment21 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment2[0].Id);
                var persistedEquipment22 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment2[1].Id);
                var persistedEquipment23 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment2[2].Id);
                var persistedEngineer1 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer1.Id);
                var persistedEngineer2 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer2.Id);
                Assert.Greater(persistedSiteVisitReport.Documents.Count, 0);
                Assert.IsFalse(persistedSiteVisitReport.Documents.Any(d => d.Document.Id == document1.Id));
                Assert.IsTrue(persistedSiteVisitReport.Documents.Any(d => d.Document.Id == document2.Id));
                Assert.IsNull(persistedSiteVisitReportDocument1);
                Assert.IsNotNull(persistedSiteVisitReportDocument2);
                Assert.AreEqual(3, persistedSiteVisitReport.Documents.FirstOrDefault(sd => sd.Document.Id == document2.Id).SiteVisitReportEquipment.Count);
                Assert.AreEqual(6, persistedSiteVisitReport.Equipment.Count);
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment1[0].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment1[1].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment1[2].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment2[0].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment2[1].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment2[2].Id));
                Assert.IsNotNull(persistedSiteVisitReportEquipment11);
                Assert.IsNotNull(persistedSiteVisitReportEquipment12);
                Assert.IsNotNull(persistedSiteVisitReportEquipment13);
                Assert.IsNotNull(persistedSiteVisitReportEquipment21);
                Assert.IsNotNull(persistedSiteVisitReportEquipment22);
                Assert.IsNotNull(persistedSiteVisitReportEquipment23);
                Assert.IsNotNull(persistedDocument1);
                Assert.IsNotNull(persistedDocument2);
                Assert.IsNotNull(persistedEquipment11);
                Assert.IsNotNull(persistedEquipment12);
                Assert.IsNotNull(persistedEquipment13);
                Assert.IsNotNull(persistedEquipment21);
                Assert.IsNotNull(persistedEquipment22);
                Assert.IsNotNull(persistedEquipment23);
                Assert.IsNotNull(persistedEngineer1);
                Assert.IsNotNull(persistedEngineer2);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                _siteVisitReports.Add(persistedSiteVisitReport);
                _siteVisitReportDocuments.AddRange(persistedSiteVisitReport.Documents);
                _siteVisitReportEquipment.AddRange(persistedSiteVisitReport.Documents.SelectMany(sd => sd.SiteVisitReportEquipment));
                _documents.AddRange(persistedSiteVisitReport.Documents.Select(sd => sd.Document));
            }
        }

        /// <summary>
        /// Test to see if a site visit report document (with equipment) can be added to the domain directly
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should include added document, including equipment</remarks>
        [Test]
        public void CanAddSiteVisitReportDocumentWithEquipmentExplicitly()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create document
            var document = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();
            }

            // Add the document to the site visit report's Documents collection
            var equipment = GiveMeSomeEquipment(3);
            var engineer = new Engineer(_employeeServices).RandomEngineer();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocument = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(equipment.Select(e => new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == e.Id)
                    }).ToList()),
                    CreatedBy = engineer
                };
                session.SaveOrUpdate(siteVisitReportDocument);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                Assert.AreEqual(1, persistedSiteVisitReport.Documents.Count);
                var siteVisitReportDocument = persistedSiteVisitReport.Documents.ToList()[0];
                Assert.AreEqual(document.Id, siteVisitReportDocument.Document.Id);
                Assert.AreEqual(3, siteVisitReportDocument.SiteVisitReportEquipment.Count);
                foreach (var siteVisitReportEquipment in persistedSiteVisitReport.Documents.SelectMany(sd => sd.SiteVisitReportEquipment))
                {
                    Assert.IsTrue(equipment.Any(a => a.Id == siteVisitReportEquipment.Equipment.Id));
                }
                Assert.AreEqual(engineer.Id, siteVisitReportDocument.CreatedBy.Id);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                _siteVisitReports.Add(persistedSiteVisitReport);
                _siteVisitReportDocuments.AddRange(persistedSiteVisitReport.Documents);
                _siteVisitReportEquipment.AddRange(persistedSiteVisitReport.Documents.SelectMany(sd => sd.SiteVisitReportEquipment));
                _documents.AddRange(persistedSiteVisitReport.Documents.Select(sd => sd.Document));
            }
        }

        /// <summary>
        /// Test to see if a site visit report document (with equipment) can be deleted from the domain directly
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should not include removed document</remarks>
        /// <remarks>Document retrieved from domain should still exist</remarks>
        /// <remarks>Site visit report equipment retrieved from domain should still exist</remarks>
        /// <remarks>Equipment retrieved from domain should still exist</remarks>
        /// <remarks>Creator retrieved from domain should still exist</remarks>
        [Test]
        public void CanRemoveSiteVisitReportDocumentWithEquipmentExplicitly()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create some documents
            var document1 = GiveMeADocument();
            var document2 = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.SaveOrUpdate(document2);
                session.Flush();
            }

            // Add the documents to the site visit report's Documents collection
            var engineer1 = new Engineer(_employeeServices).RandomEngineer();
            var engineer2 = new Engineer(_employeeServices).RandomEngineer();
            var equipment1 = GiveMeSomeEquipment(3);
            var equipment2 = GiveMeSomeEquipment(3);
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocument1 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(equipment1.Select(equipment => new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    }).ToList()),
                    CreatedBy = engineer1
                };
                var siteVisitReportDocument2 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(equipment2.Select(equipment => new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    }).ToList()),
                    CreatedBy = engineer2
                };
                session.SaveOrUpdate(siteVisitReportDocument1);
                session.SaveOrUpdate(siteVisitReportDocument2);
                session.Flush();
            }

            // Remove one document from the site visit report's Documents collection
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocumentToRemove = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document1.Id);
                session.Delete(siteVisitReportDocumentToRemove);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var persistedSiteVisitReportDocument1 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document1.Id);
                var persistedSiteVisitReportDocument2 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document2.Id);
                var persistedSiteVisitReportEquipment11 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment1[0].Id);
                var persistedSiteVisitReportEquipment12 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment1[1].Id);
                var persistedSiteVisitReportEquipment13 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment1[2].Id);
                var persistedSiteVisitReportEquipment21 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment2[0].Id);
                var persistedSiteVisitReportEquipment22 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment2[1].Id);
                var persistedSiteVisitReportEquipment23 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment2[2].Id);
                var persistedDocument1 = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id);
                var persistedDocument2 = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id);
                var persistedEquipment11 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment1[0].Id);
                var persistedEquipment12 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment1[1].Id);
                var persistedEquipment13 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment1[2].Id);
                var persistedEquipment21 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment2[0].Id);
                var persistedEquipment22 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment2[1].Id);
                var persistedEquipment23 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment2[2].Id);
                var persistedEngineer1 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer1.Id);
                var persistedEngineer2 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer2.Id);
                Assert.Greater(persistedSiteVisitReport.Documents.Count, 0);
                Assert.IsFalse(persistedSiteVisitReport.Documents.Any(d => d.Document.Id == document1.Id));
                Assert.IsTrue(persistedSiteVisitReport.Documents.Any(d => d.Document.Id == document2.Id));
                Assert.IsNull(persistedSiteVisitReportDocument1);
                Assert.IsNotNull(persistedSiteVisitReportDocument2);
                Assert.AreEqual(3, persistedSiteVisitReport.Documents.FirstOrDefault(sd => sd.Document.Id == document2.Id).SiteVisitReportEquipment.Count);
                Assert.AreEqual(6, persistedSiteVisitReport.Equipment.Count);
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment1[0].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment1[1].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment1[2].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment2[0].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment2[1].Id));
                Assert.IsTrue(persistedSiteVisitReport.Equipment.Any(sa => sa.Equipment.Id == equipment2[2].Id));
                Assert.IsNotNull(persistedSiteVisitReportEquipment11);
                Assert.IsNotNull(persistedSiteVisitReportEquipment12);
                Assert.IsNotNull(persistedSiteVisitReportEquipment13);
                Assert.IsNotNull(persistedSiteVisitReportEquipment21);
                Assert.IsNotNull(persistedSiteVisitReportEquipment22);
                Assert.IsNotNull(persistedSiteVisitReportEquipment23);
                Assert.IsNotNull(persistedDocument1);
                Assert.IsNotNull(persistedDocument2);
                Assert.IsNotNull(persistedEquipment11);
                Assert.IsNotNull(persistedEquipment12);
                Assert.IsNotNull(persistedEquipment13);
                Assert.IsNotNull(persistedEquipment21);
                Assert.IsNotNull(persistedEquipment22);
                Assert.IsNotNull(persistedEquipment23);
                Assert.IsNotNull(persistedEngineer1);
                Assert.IsNotNull(persistedEngineer2);
            }

            // Add persisted objects to collection for tear-down
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                _siteVisitReports.Add(persistedSiteVisitReport);
                _siteVisitReportDocuments.AddRange(persistedSiteVisitReport.Documents);
                _siteVisitReportEquipment.AddRange(persistedSiteVisitReport.Documents.SelectMany(sd => sd.SiteVisitReportEquipment));
                _documents.AddRange(persistedSiteVisitReport.Documents.Select(sd => sd.Document));
            }
        }

        /// <summary>
        /// Test to see if a site visit report with document (with equipment) can be deleted
        /// </summary>
        /// <remarks>Site visit report retrieved from domain should not exist</remarks>
        /// <remarks>Site visit report document retrieved from domain should not exist</remarks>
        /// <remarks>Document retrieved from domain should still exist</remarks>
        /// <remarks>Site visit report equipment retrieved from domain should not exist</remarks>
        /// <remarks>Equipment retrieved from domain should still exist</remarks>
        /// <remarks>Creator retrieved from domain should still exist</remarks>
        [Test]
        public void CanDeleteSiteVisitReportWithDocumentWithEquipment()
        {
            // Create site visit report
            var siteVisitReport = new SiteVisitReport(_equipmentServices, _employeeServices, _siteVisitReportStatusServices).Report();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(siteVisitReport);
                session.Flush();
            }

            // Create some documents
            var document1 = GiveMeADocument();
            var document2 = GiveMeADocument();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.SaveOrUpdate(document2);
                session.Flush();
            }

            // Add the documents to the site visit report's Documents collection
            var engineer1 = new Engineer(_employeeServices).RandomEngineer();
            var engineer2 = new Engineer(_employeeServices).RandomEngineer();
            var equipment1 = GiveMeSomeEquipment(3);
            var equipment2 = GiveMeSomeEquipment(3);
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var siteVisitReportDocument1 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(equipment1.Select(equipment => new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    }).ToList()),
                    CreatedBy = engineer1
                };
                var siteVisitReportDocument2 = new SiteVisitReportDocument
                {
                    Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                    Document = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id),
                    SiteVisitReportEquipment = new HashSet<SiteVisitReportEquipment>(equipment2.Select(equipment => new SiteVisitReportEquipment
                    {
                        Report = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id),
                        Equipment = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment.Id)
                    }).ToList()),
                    CreatedBy = engineer2
                };
                session.SaveOrUpdate(siteVisitReportDocument1);
                session.SaveOrUpdate(siteVisitReportDocument2);
                session.Flush();
            }

            // Delete site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                session.Delete(persistedSiteVisitReport);
                session.Flush();
            }

            // Verify site visit report
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var persistedSiteVisitReport = session.Query<Report>().FirstOrDefault(s => s.Id == siteVisitReport.Id);
                var persistedSiteVisitReportDocument1 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document1.Id);
                var persistedSiteVisitReportDocument2 = session.Query<SiteVisitReportDocument>().FirstOrDefault(sd => sd.Report.Id == siteVisitReport.Id && sd.Document.Id == document2.Id);
                var persistedSiteVisitReportEquipment11 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment1[0].Id);
                var persistedSiteVisitReportEquipment12 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment1[1].Id);
                var persistedSiteVisitReportEquipment13 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment1[2].Id);
                var persistedSiteVisitReportEquipment21 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment2[0].Id);
                var persistedSiteVisitReportEquipment22 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment2[1].Id);
                var persistedSiteVisitReportEquipment23 = session.Query<SiteVisitReportEquipment>().FirstOrDefault(sa => sa.Report.Id == siteVisitReport.Id && sa.Equipment.Id == equipment2[2].Id);
                var persistedDocument1 = session.Query<Document>().FirstOrDefault(d => d.Id == document1.Id);
                var persistedDocument2 = session.Query<Document>().FirstOrDefault(d => d.Id == document2.Id);
                var persistedEquipment11 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment1[0].Id);
                var persistedEquipment12 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment1[1].Id);
                var persistedEquipment13 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment1[2].Id);
                var persistedEquipment21 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment2[0].Id);
                var persistedEquipment22 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment2[1].Id);
                var persistedEquipment23 = session.Query<Equipment>().FirstOrDefault(a => a.Id == equipment2[2].Id);
                var persistedEngineer1 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer1.Id);
                var persistedEngineer2 = session.Query<Employee>().FirstOrDefault(e => e.Id == engineer2.Id);
                Assert.IsNull(persistedSiteVisitReport);
                Assert.IsNull(persistedSiteVisitReportDocument1);
                Assert.IsNull(persistedSiteVisitReportDocument2);
                Assert.IsNull(persistedSiteVisitReportEquipment11);
                Assert.IsNull(persistedSiteVisitReportEquipment12);
                Assert.IsNull(persistedSiteVisitReportEquipment13);
                Assert.IsNull(persistedSiteVisitReportEquipment21);
                Assert.IsNull(persistedSiteVisitReportEquipment22);
                Assert.IsNull(persistedSiteVisitReportEquipment23);
                Assert.IsNotNull(persistedDocument1);
                Assert.IsNotNull(persistedDocument2);
                Assert.IsNotNull(persistedEquipment11);
                Assert.IsNotNull(persistedEquipment12);
                Assert.IsNotNull(persistedEquipment13);
                Assert.IsNotNull(persistedEquipment21);
                Assert.IsNotNull(persistedEquipment22);
                Assert.IsNotNull(persistedEquipment23);
                Assert.IsNotNull(persistedEngineer1);
                Assert.IsNotNull(persistedEngineer2);
            }

            // Add persisted objects to collection for tear-down
            _documents.Add(document1);
            _documents.Add(document2);
        }

        #endregion

        #endregion

        /// <summary>
        /// Helper method to create a new document revision metadata object
        /// </summary>
        /// <param name="document">The document to create the revision metadata for</param>
        /// <param name="originalDocument">The original document to base the revision metadata on</param>
        /// <returns>A new document revision metadata object</returns>
        private DocumentRevisionMetaData GiveMeADocumentRevisionMetaData(Document document, Document originalDocument)
        {
            // For the document content, we generate a random byte array the same size as the original content
            // This is to ensure we get a unique checksum
            var bufferSize = (int)(originalDocument.LatestRevision.Bytes);
            var content = new byte[bufferSize];
            new Random().NextBytes(content);

            var documentRevisionMetaData = new DocumentRevisionMetaData(document)
            {
                DisplayName = Path.GetFileNameWithoutExtension(originalDocument.LatestRevision.FileName),
                FileName = originalDocument.LatestRevision.FileName,
                MimeType = originalDocument.LatestRevision.MimeType,
                CreatedDateUtc = DateTime.UtcNow,
                PublishedDateUtc = originalDocument.LatestRevision.PublishedDateUtc,
                Bytes = originalDocument.LatestRevision.Content.Content.Length,
                Content = new DocumentRevisionContent
                {
                    Content = content,
                    FileChecksum = _fileSystemServices.GenerateFileChecksum(content)
                }
            };

            return documentRevisionMetaData;
        }

        /// <summary>
        /// Helper method to create a new document
        /// </summary>
        /// <returns>A new document</returns>
        private Document GiveMeADocument()
        {
            var originalDocument = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());

            // Create document
            var document = new Document
            {
                Type = originalDocument.Type,
                Description = "Document Refactor - Raw Equipment Document Test 1",
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            var documentRevisionMetaData = GiveMeADocumentRevisionMetaData(document, originalDocument); // Add revision
            document.Revisions.Add(documentRevisionMetaData);

            return document;
        }

        /// <summary>
        /// Helper method to return a collection of equipment
        /// </summary>
        /// <param name="number">The number of equipment to extract</param>
        /// <returns>A collection of equipment</returns>
        private List<Equipment> GiveMeSomeEquipment(int number)
        {
            var equipments = new List<Equipment>();
            for (var i = 0; i < number; i++)
            {
                var equipment = new Tests.Common.DataExtractor.Equipment(_equipmentServices).RandomEquipment();
                equipments.Add(equipment);
            }
            return equipments;
        }
    }
}