using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using Castle.Core.Internal;
using Common.Utilities;
using NHibernate.Linq;
using NHibernate.Transform;
using NUnit.Framework;
using Vision.Api.DotNet.Builder.REST;
using Vision.Api.DotNet.Builder.REST.TestDocuments;
using Vision.Api.DotNet.Domain.Documents;
using Vision.Api.DotNet.Tests.Common.DataExtractor;
using Vision.Api.DotNet.Tests.Common.DataGenerator;
using Vision.Api.DotNet.Types;
using Document = Vision.Api.DotNet.Domain.Documents.Document;
using Signatory = Vision.Api.DotNet.Domain.SiteVisitReports.Signatory;
using TestSession = Vision.Api.DotNet.Domain.TestDocuments.TestSession;
using TestSessionStatus = Vision.Api.DotNet.Types.TestSessionStatus;
using TestType = Vision.Api.DotNet.Types.TestType;

namespace Vision.Api.DotNet.Tests.Integration.Builder.TestDocuments
{
    public class UpdateTestSessionTests : EngineerAppBuilderTestBase
    {
        [SetUp]
        protected override void SetUpForEachTest()
        {
            base.SetUpForEachTest();

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Create some new test session types
                for (var i = 0; i < new Random().Next(3, 5); i++)
                {
                    var testSessionType = new TestSessionReferenceData(_documentTypeServices).TestTestSessionType();

                    session.SaveOrUpdate(testSessionType);
                    session.Flush();

                    // Add each test session type to the list of persisted test session types
                    // so we can remove them when we have finished
                    _testSessionTypes.Add(testSessionType);
                }

                session.Flush();
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Create some new test session locations
                for (var i = 0; i < new Random().Next(3, 5); i++)
                {
                    var testSessionLocation = new TestSessionReferenceData(_documentTypeServices).TestTestSessionLocation();

                    session.SaveOrUpdate(testSessionLocation);
                    session.Flush();

                    // Add each test session location to the list of persisted test session types
                    // so we can remove them when we have finished
                    _testSessionLocations.Add(testSessionLocation);
                }

                session.Flush();
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Create random test sessions without tests
                for (var i = 0; i < new Random().Next(3, 5); i++)
                {
                    var testSession = _testSessionGenerator.NewTestSessionWithEquipment(session, 99999, "X99", MarketSectorType.Types.LV.Id);
                    _equipment.Add(testSession.Equipment);

                    testSession.TestSessionType = _testSessionTypes[new Random().Next(_testSessionTypes.Count)];

                    session.SaveOrUpdate(testSession);
                    session.Flush();

                    // Add each test session to the list of persisted test sessions
                    // so we can remove them when we have finished
                    _testSessions.Add(testSession);
                }

                session.Flush();
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Create some new client witness signatories
                for (var i = 0; i < new Random().Next(3, 5); i++)
                {
                    foreach (var testSession in _testSessions)
                    {
                        var clientWitnessSignatory = new TestSessionClientWitnessSignatory(_employeeServices, _organisationServices).TestWitnessSignatory();
                        clientWitnessSignatory.Organisation = testSession.Equipment.Branch.Organisation;

                        session.SaveOrUpdate(clientWitnessSignatory);
                        session.Flush();

                        // Add each client witness signatory to the list of persisted client witness signatories
                        // so we can remove them when we have finished
                        _clientWitnessSignatories.Add(clientWitnessSignatory);
                    }

                }

                session.Flush();
            }
        }

        [TearDown]
        protected override void TearDownAfterEachTest()
        {
            // Update the test sessions in the persisted list, so their new documents are also removed during the clean-up
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var testSessionIds = _testSessions.Select(ts => ts.Id).ToList();
                _testSessions = session.QueryOver<TestSession>()
                    .TransformUsing(Transformers.DistinctRootEntity)
                    .WhereRestrictionOn(ts => ts.Id).IsIn(testSessionIds)
                    .Fetch(ts => ts.Tests).Eager.Fetch(ts => ts.Documents).Eager    // Expand child objects that we need to refer to following session closure
                    .Future<TestSession>()
                    .ToList();
            }

            base.TearDownAfterEachTest();
        }

        /// <summary>
        /// Test to see if a test session can be updated
        /// </summary>
        [Test]
        public void CanUpdateTestSession()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                var testSession1 = testSession; // to keep ReSharper happy
                testSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession1.Id)
                    .FetchMany(t => t.Tests).FetchMany(t => t.Documents)    // Expand child objects that we need to refer to following session closure
                    .Fetch(t => t.Equipment).ThenFetch(a => a.Branch)
                    .ToFuture()
                    .FirstOrDefault();
                if (testSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            testSession.Tests.ForEach(_tests.Add);

            // Get the details of the test session before it has been modified
            var testSessionBefore = new TestSession
            {
                Id = testSession.Id,
                Equipment = testSession.Equipment,
                Tester = testSession.Tester,
                LastDeviceUsed = testSession.LastDeviceUsed,
                StartDate = testSession.StartDate,
                EndDate = testSession.EndDate,
                TestSessionType = testSession.TestSessionType,
                TestSessionLocation = testSession.TestSessionLocation,
                TripUnitCheckOutcome = testSession.TripUnitCheckOutcome,
                Comments = testSession.Comments,
                TestedToGeneralArrangementDrawingRevision = testSession.TestedToGeneralArrangementDrawingRevision,
                TestedToElectricalSchematicDrawingRevision = testSession.TestedToElectricalSchematicDrawingRevision,
                MardixSignatory = testSession.MardixSignatory,
                MardixSignOffDate = testSession.MardixSignOffDate,
                MardixWitnessSignatory = testSession.MardixWitnessSignatory,
                ClientWitnessSignatory = testSession.ClientWitnessSignatory,
                WitnessSignOffDate = testSession.WitnessSignOffDate,
                Status = testSession.Status,
                Result = testSession.Result,
                TXSerialNo = testSession.STSSerialNo,
                STSSerialNo = testSession.STSSerialNo,
                AHFSerialNo = testSession.AHFSerialNo,
                UnitRating = testSession.UnitRating,
                TXRating = testSession.TXRating,
                STSRating = testSession.STSRating,
                AHFRating = testSession.AHFRating
            };

            // Modify the test session properties
            var testSessionAfter = UpdateProperties(testSession);

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession.Id);
                if (updatedTestSession == null || updatedTestSession.StartDate == null || updatedTestSession.EndDate == null || updatedTestSession.MardixSignOffDate == null || updatedTestSession.WitnessSignOffDate == null) throw new Exception("Expected data not found in database");
            }

            // Test that persisted test session does not have the original property values (so the properties have definitely changed)
            Assert.AreNotEqual(testSessionBefore.Equipment.Id, updatedTestSession.Equipment.Id);
            Assert.AreNotEqual(testSessionBefore.Tester.Id, updatedTestSession.Tester.Id);
            Assert.AreNotEqual(testSessionBefore.LastDeviceUsed, updatedTestSession.LastDeviceUsed);
            Assert.AreNotEqual(testSessionBefore.StartDate, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.StartDate));
            Assert.AreNotEqual(testSessionBefore.EndDate, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.EndDate));
            Assert.AreNotEqual(testSessionBefore.MardixSignOffDate, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.MardixSignOffDate));
            Assert.AreNotEqual(testSessionBefore.WitnessSignOffDate, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.WitnessSignOffDate));
            Assert.AreNotEqual(testSessionBefore.TestSessionType.Id, updatedTestSession.TestSessionType.Id);
            Assert.AreEqual(testSessionBefore.TestSessionLocation, null);
            Assert.AreEqual(testSessionBefore.ElectricalSupplySystem, null);
            Assert.AreEqual(testSessionBefore.TripUnitCheckOutcome, null);
            Assert.AreNotEqual(testSessionBefore.Comments, updatedTestSession.Comments);
            Assert.AreEqual(testSessionBefore.TestedToGeneralArrangementDrawingRevision, null);
            Assert.AreEqual(testSessionBefore.TestedToElectricalSchematicDrawingRevision, null);
            Assert.AreEqual(testSessionBefore.MardixSignatory, null);
            Assert.AreEqual(testSessionBefore.MardixWitnessSignatory, null);
            Assert.AreEqual(testSessionBefore.ClientWitnessSignatory, null);
            Assert.AreNotEqual(testSessionBefore.Status.Id, updatedTestSession.Status.Id);
            Assert.AreEqual(testSessionBefore.Result, null);
            Assert.AreNotEqual(testSessionBefore.TXSerialNo, updatedTestSession.TXSerialNo);
            Assert.AreNotEqual(testSessionBefore.STSSerialNo, updatedTestSession.STSSerialNo);
            Assert.AreNotEqual(testSessionBefore.AHFSerialNo, updatedTestSession.AHFSerialNo);
            Assert.AreNotEqual(testSessionBefore.UnitRating, updatedTestSession.UnitRating);
            Assert.AreNotEqual(testSessionBefore.TXRating, updatedTestSession.TXRating);
            Assert.AreNotEqual(testSessionBefore.STSRating, updatedTestSession.STSRating);
            Assert.AreNotEqual(testSessionBefore.AHFRating, updatedTestSession.AHFRating);

            // Test that persisted test session has the updated property values
            Assert.AreEqual(testSessionAfter.Equipment.Id, updatedTestSession.Equipment.Id);
            Assert.AreEqual(testSessionAfter.Tester.Id, updatedTestSession.Tester.Id);
            Assert.AreEqual(testSessionAfter.LastDeviceUsed, updatedTestSession.LastDeviceUsed);
            Assert.AreEqual(testSessionAfter.StartDate, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.StartDate));
            Assert.AreEqual(testSessionAfter.EndDate, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.EndDate));
            Assert.AreEqual(testSessionAfter.MardixSignOffDate, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.MardixSignOffDate));
            Assert.AreEqual(testSessionAfter.WitnessSignOffDate, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.WitnessSignOffDate));
            Assert.AreEqual(testSessionAfter.TestSessionType.Id, updatedTestSession.TestSessionType.Id);
            Assert.AreEqual(testSessionAfter.TestSessionLocation.Id, updatedTestSession.TestSessionLocation.Id);
            Assert.AreEqual(testSessionAfter.ElectricalSupplySystem.Id, updatedTestSession.ElectricalSupplySystem.Id);
            Assert.AreEqual(testSessionAfter.TripUnitCheckOutcome.Id, updatedTestSession.TripUnitCheckOutcome.Id);
            Assert.AreEqual(testSessionAfter.Comments, updatedTestSession.Comments);
            Assert.AreEqual(testSessionAfter.TestedToGeneralArrangementDrawingRevision, updatedTestSession.TestedToGeneralArrangementDrawingRevision);
            Assert.AreEqual(testSessionAfter.TestedToElectricalSchematicDrawingRevision, updatedTestSession.TestedToElectricalSchematicDrawingRevision);
            Assert.AreEqual(testSessionAfter.MardixSignatory.Id, updatedTestSession.MardixSignatory.Id);
            Assert.AreEqual(testSessionAfter.MardixWitnessSignatory.Id, updatedTestSession.MardixWitnessSignatory.Id);
            Assert.AreEqual(testSessionAfter.ClientWitnessSignatory.Id, updatedTestSession.ClientWitnessSignatory.Id);
            Assert.AreEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession.Status.Id);   // Status is set automatically by Api
            Assert.AreEqual(testSessionAfter.Result.Id, updatedTestSession.Result.Id);
            Assert.AreEqual(testSessionAfter.TXSerialNo, updatedTestSession.TXSerialNo);
            Assert.AreEqual(testSessionAfter.STSSerialNo, updatedTestSession.STSSerialNo);
            Assert.AreEqual(testSessionAfter.AHFSerialNo, updatedTestSession.AHFSerialNo);
            Assert.AreEqual(testSessionAfter.UnitRating, updatedTestSession.UnitRating);
            Assert.AreEqual(testSessionAfter.TXRating, updatedTestSession.TXRating);
            Assert.AreEqual(testSessionAfter.STSRating, updatedTestSession.STSRating);
            Assert.AreEqual(testSessionAfter.AHFRating, updatedTestSession.AHFRating);
        }

        /// <summary>
        /// Test to confirm that the updated test session has the correct client witness signatory based on the e-mail address sent in
        /// </summary>
        [Test]
        public void UpdatedTestSessionHasCorrectClientWitnessSignatory()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                var testSession1 = testSession; // to keep ReSharper happy
                testSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession1.Id)
                    .FetchMany(t => t.Tests).FetchMany(t => t.Documents)    // Expand child objects that we need to refer to following session closure
                    .Fetch(t => t.Equipment).ThenFetch(a => a.Branch)
                    .ToFuture()
                    .FirstOrDefault();
                if (testSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            testSession.Tests.ForEach(_tests.Add);

            // Set test session's client witness signatory
            var clientWitnessSignatoriesSubset = _clientWitnessSignatories.Where(s => s.Organisation.Id == testSession.Equipment.Branch.Organisation.Id).ToList();
            testSession.ClientWitnessSignatory = clientWitnessSignatoriesSubset[new Random().Next(clientWitnessSignatoriesSubset.Count)];

            // Create dto object and confirm we are sending in the correct e-mail address :)
            var testSessionDto = ToDtoWrite(testSession);
            Assert.AreEqual(testSession.ClientWitnessSignatory.Email, testSessionDto.ClientWitnessSignatoryEmail);

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(testSessionDto).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>().FirstOrDefault(ts => ts.Id == testSession.Id);
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm that the test session has the expected client witness signatory
            Assert.AreEqual(testSession.ClientWitnessSignatory.Id, updatedTestSession.ClientWitnessSignatory.Id);
        }

        /// <summary>
        /// Test to see if an updated test session that previously had no tests, now has those tests added
        /// </summary>
        [Test]
        public void UpdatedTestSessionWithoutTestsHasTestsAdded()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            // Confirm the test session has no tests to begin with
            Assert.AreEqual(0, testSession.Tests.Count);

            // Update test session
            // This should now add all the missing tests
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).FetchMany(t => t.Documents)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            // Confirm we have the correct number of tests
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            // Confirm that all the tests exist
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                Assert.That(updatedTestSession.Tests.Select(t => t.TestType.Id).Contains(testType.Id));
            }
        }

        /// <summary>
        /// Test to see if blank test documents are added where the test session has tests but no required documents
        /// </summary>
        [Test]
        public void UpdatedTestSessionWithTestsButNoDocumentsHasTestDocumentsAdded()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests, and that each one does not have a document
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);
            foreach (var test in updatedTestSession.Tests)
            {
                Assert.IsNull(test.Document);
            }

            // Update two of the existing test associations to include documents
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test8.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test8.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            // Update test session
            // This should now update all the existing tests to add the missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            // Confirm we still have the correct number of tests
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            var testDocumentTemplateStf01 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            var testDocumentTemplateStf03 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test8 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 8);
            if (testDocumentTemplateStf01 == null || testDocumentTemplateStf03 == null || test1 == null || test8 == null) throw new Exception("Expected data not found in database");

            // Confirm the test session has the expected documents
            Assert.AreEqual(testDocumentTemplateStf01.Document.LatestRevision.Content.Content.Length, test1.Document.LatestRevision.Content.Content.Length);
            Assert.AreEqual(testDocumentTemplateStf03.Document.LatestRevision.Content.Content.Length, test8.Document.LatestRevision.Content.Content.Length);

            // Confirm the test documents are of the expected type
            Assert.AreEqual(DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, test1.Document.Type.Id);
            Assert.AreEqual(DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, test8.Document.Type.Id);
            Assert.IsTrue(test1.Document.LatestRevision.Content.Content.Length > 0);
            Assert.IsTrue(test8.Document.LatestRevision.Content.Content.Length > 0);

            // Confirm that all the other tests exists, but have no documents
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero.Where(tt => tt.Id != TestType.Types.Test1.Id && tt.Id != TestType.Types.Test8.Id))
            {
                var test = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == testType.Id);
                if (test == null) throw new Exception("Expected data not found in database");

                Assert.That(updatedTestSession.Tests.Select(t => t.TestType.Id).Contains(testType.Id));
                Assert.IsNull(test.Document);
            }
        }

        /// <summary>
        /// Test to see if the existing test documents for an updated test session are preserved, but other missing documents are automatically added
        /// </summary>
        [Test]
        public void UpdatedTestSessionWithTestsButOnlySomeDocumentsHasDocumentsPreserved()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests, and that each one does not have a document
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            // Update two of the existing test associations to include documents
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test8.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test8.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            var testDocumentTemplateStf01 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            var testDocumentTemplateStf03 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);
            if (testDocumentTemplateStf01 == null || testDocumentTemplateStf03 == null) throw new Exception("Expected data not found in database");
            
            // Get test 1
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test1.Id);
            if (test1 == null) throw new Exception("Expected data not found in database");

            // Give test 1 a document
            var document = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { testDocumentTemplateStf01.Document });

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();

                test1.Document = document;
                session.SaveOrUpdate(test1);
                session.Flush();
            }

            // Get the content length of the three documents - test1's existing docment, and the two templates
            var test1DocumentContentLength = document.LatestRevision.Content.Content.Length;
            var templateTest1DocumentContentLength = testDocumentTemplateStf01.Document.LatestRevision.Content.Content.Length;
            var templateTest8DocumentContentLength = testDocumentTemplateStf03.Document.LatestRevision.Content.Content.Length;

            // Update test session
            // This should now update all the existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test8 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 8);
            if (test1 == null || test8 == null) throw new Exception("Expected data not found in database");

            // Confirm we still have the correct number of tests
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            // Confirm test 8 has the expected new template document with the expected document type
            Assert.AreEqual(templateTest8DocumentContentLength, test8.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test8.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreEqual(DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, test8.Document.Type.Id);

            // Confirm test 1 still has the old document, and not the template version
            Assert.AreEqual(test1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test1.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreNotEqual(templateTest1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);

            // Confirm that all the other tests exists, but have no documents
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero.Where(tt => tt.Id != TestType.Types.Test1.Id && tt.Id != TestType.Types.Test8.Id))
            {
                var test = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == testType.Id);
                if (test == null) throw new Exception("Expected data not found in database");

                Assert.That(updatedTestSession.Tests.Select(t => t.TestType.Id).Contains(testType.Id));
                Assert.IsNull(test.Document);
            }
        }

        /// <summary>
        /// Test to confirm that the existing domain tests for a test session are preserved, when the test session is updated using a Dto object with an empty Tests collection
        /// </summary>
        [Test]
        public void UpdatedTestSessionWithEmptyTestsCollectionHasDomainTestsPreserved()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Update two of the existing test associations to include documents
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test8.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test8.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            var testDocumentTemplateStf01 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            var testDocumentTemplateStf03 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);
            if (testDocumentTemplateStf01 == null || testDocumentTemplateStf03 == null) throw new Exception("Expected data not found in database");

            // Get test 1
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test1.Id);
            if (test1 == null) throw new Exception("Expected data not found in database");

            // Give test 1 a document and some properties
            var document = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { testDocumentTemplateStf01.Document });

            // Generate a random result
            var results = TestResult.Results.All.Where(t => t.Id != (testSession.Result != null ? testSession.Result.Id : Guid.Empty)).ToList();
            var result = results.Skip(new Random().Next(results.Count())).Take(1).FirstOrDefault();
            if (result == null) throw new Exception("Expected data not found in database");

            var randomResult = _resultServices.Single(result.Id);

            // Generate a random instrument reference
            var random = new Random();
            var randomInstrumentReference = new string(Enumerable.Repeat("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", 8)
                                                            .Select(s => s[random.Next(s.Length)]).ToArray());

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document);
                session.Flush();

                test1.Document = document;
                test1.Result = randomResult;
                test1.InstrumentReference = randomInstrumentReference;

                session.SaveOrUpdate(test1);
                session.Flush();
            }

            // Get the content length of test1's existing docment, and the two templates
            var test1DocumentContentLength = document.LatestRevision.Content.Content.Length;
            var templateTest1DocumentContentLength = testDocumentTemplateStf01.Document.LatestRevision.Content.Content.Length;
            var templateTest8DocumentContentLength = testDocumentTemplateStf03.Document.LatestRevision.Content.Content.Length;

            // Clear test session's tests collection
            testSession.Tests.Clear();
            Assert.AreEqual(0, testSession.Tests.Count);

            // Update test session
            // This should now update all the existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test8 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 8);
            if (test1 == null || test8 == null) throw new Exception("Expected data not found in database");

            // Confirm we have the correct number of tests
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            // Confirm test 8 has the expected new template document, and does not have the randomly-generated properties
            Assert.AreEqual(templateTest8DocumentContentLength, test8.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test8.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreEqual(null, test8.Result);
            Assert.AreEqual(DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, test8.Document.Type.Id);
            Assert.AreNotEqual(randomInstrumentReference, test8.InstrumentReference);

            // Confirm test 1 still has the old document, and not the template version, and also that it has the randomly-generated properties
            Assert.AreEqual(test1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);
            Assert.AreNotEqual(templateTest1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test1.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreEqual(randomResult.Id, test1.Result.Id);
            Assert.AreEqual(randomInstrumentReference, test1.InstrumentReference);

            // Confirm that all the other tests exists, but have no documents
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero.Where(tt => tt.Id != TestType.Types.Test1.Id && tt.Id != TestType.Types.Test8.Id))
            {
                var test = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == testType.Id);
                if (test == null) throw new Exception("Expected data not found in database");

                Assert.That(updatedTestSession.Tests.Select(t => t.TestType.Id).Contains(testType.Id));
                Assert.IsNull(test.Document);
            }
        }

        /// <summary>
        /// Test to see if a test session can be updated when it previously had no device set
        /// </summary>
        [Test]
        public void CanUpdateTestSessionWhenNoPreviousDeviceSpecified()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Ensure last device used is not set
                testSession.LastDeviceUsed = null;
                session.SaveOrUpdate(testSession);
                session.Flush();
            }

            // Modify the test session properties
            testSession = UpdateProperties(testSession);

            // Update the last device used
            var newDeviceId = Guid.NewGuid().ToString();
            testSession.LastDeviceUsed = newDeviceId;

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);
            Assert.AreEqual(newDeviceId, putResponse.Data.LastDeviceUsed);
        }

        /// <summary>
        /// Test to see if a test session can be updated when it previously had the same device set
        /// </summary>
        [Test]
        public void CanUpdateTestSessionWhenSamePreviousDeviceSpecified()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            var deviceId = Guid.NewGuid().ToString();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Set last device used
                testSession.LastDeviceUsed = deviceId;
                session.SaveOrUpdate(testSession);
                session.Flush();
            }

            // Modify the test session properties
            testSession = UpdateProperties(testSession);

            // Ensure the last device used is the same
            testSession.LastDeviceUsed = deviceId;

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);
            Assert.AreEqual(deviceId, putResponse.Data.LastDeviceUsed);
        }

        /// <summary>
        /// Test to check that a test session cannot be updated when it previously had a different device set
        /// </summary>
        [Test]
        public void CannotUpdateTestSessionWhenDifferentPreviousDeviceSpecified()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            var deviceId = Guid.NewGuid().ToString();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Set last device used
                testSession.LastDeviceUsed = deviceId;
                session.SaveOrUpdate(testSession);
                session.Flush();
            }

            // Modify the test session properties
            testSession = UpdateProperties(testSession);

            // Set a different device
            var newDeviceId = Guid.NewGuid().ToString();
            testSession.LastDeviceUsed = newDeviceId;

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.Conflict, putResponse.StatusCode);
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add documents to the tests, 
        /// and relevant test mappings exist with different document types, each test is given a separate document
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestDocumentsWithDifferentDocumentTypeMappingsAddsSeparateDocuments()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
            }

            // Update some of the existing test associations to include documents
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test2.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test3.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test3.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            // Update test session
            // This should add all the required tests and documents
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content) // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            // Confirm we still have the correct number of tests
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            // Confirm that the expected tests all have valid documents
            foreach (var test in updatedTestSession.Tests
                .Where(tt => tt.Id == TestType.Types.Test1.Id || tt.Id == TestType.Types.Test2.Id || tt.Id == TestType.Types.Test3.Id))
            {
                Assert.IsNotNull(test.Document);
                Assert.IsTrue(test.Document.LatestRevision.Content.Content.Length > 0);
            }

            // Confirm that all the relevant tests have unique documents
            Assert.That(updatedTestSession.Tests
                .Where(tt => tt.Id == TestType.Types.Test1.Id || tt.Id == TestType.Types.Test2.Id || tt.Id == TestType.Types.Test3.Id)
                .Select(t => t.Document.Id).ToList(), Is.Unique);

            // Confirm that all the other tests exists, but have no documents
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero
                .Where(tt => tt.Id != TestType.Types.Test1.Id && tt.Id != TestType.Types.Test2.Id && tt.Id != TestType.Types.Test3.Id))
            {
                var test = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == testType.Id);
                if (test == null) throw new Exception("Expected data not found in database");

                Assert.That(updatedTestSession.Tests.Select(t => t.TestType.Id).Contains(testType.Id));
                Assert.IsNull(test.Document);
            }
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add documents to the tests, 
        /// and relevant test mappings exist with the same document type, those tests reference the same document
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestDocumentsWithIdenticalDocumentTypeMappingsAddsSharedDocuments()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
            }

            // Update some of the existing test associations to include documents of the same type
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test2.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test3.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test3.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);

            // Create a new test document template
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            // Update test session
            // This should add all the required tests and documents
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content) // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            // Confirm we still have the correct number of tests
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            // Confirm that the expected tests all have valid documents
            foreach (var test in updatedTestSession.Tests
                .Where(tt => tt.Id == TestType.Types.Test1.Id || tt.Id == TestType.Types.Test2.Id || tt.Id == TestType.Types.Test3.Id))
            {
                Assert.IsNotNull(test.Document);
                Assert.IsTrue(test.Document.LatestRevision.Content.Content.Length > 0);
            }

            // Confirm that all the tests have the same document
            var updatedTests = updatedTestSession.Tests
                .Where(t => t.TestType.Id == TestType.Types.Test1.Id || t.TestType.Id == TestType.Types.Test2.Id || t.TestType.Id == TestType.Types.Test3.Id)
                .ToList();
            var firstUpdatedTest = updatedTestSession.Tests.FirstOrDefault();

            Assert.That(updatedTests.Select(t => t.Document.Id).ToList(), Is.Not.Unique);
            Assert.AreEqual(updatedTests.Count, updatedTests.Count(t => firstUpdatedTest != null && t.Document.Id == firstUpdatedTest.Document.Id));

            // Confirm that all the other tests exists, but have no documents
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero
                .Where(tt => tt.Id != TestType.Types.Test1.Id && tt.Id != TestType.Types.Test2.Id && tt.Id != TestType.Types.Test3.Id))
            {
                var test = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == testType.Id);
                if (test == null) throw new Exception("Expected data not found in database");

                Assert.That(updatedTestSession.Tests.Select(t => t.TestType.Id).Contains(testType.Id));
                Assert.IsNull(test.Document);
            }
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add documents to the tests, 
        /// and relevant test mappings exist with no equipment type specified, the expected documents are added
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestDocumentsAddsCorrectDocumentsWhenMappingHasNoEquipmentType()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
            }

            // Update some of the existing test associations to include documents, with no equipment type specified
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test2.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test3.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test3.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            // Update test session
            // This should add all the required tests and documents
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            var testDocumentTemplateStf01 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            var testDocumentTemplateStf02 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            var testDocumentTemplateStf03 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test2 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 2);
            var test3 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 3);
            if (testDocumentTemplateStf01 == null || testDocumentTemplateStf02 == null || testDocumentTemplateStf03 == null || test1 == null || test2 == null || test3 == null) throw new Exception("Expected data not found in database");

            // Confirm we still have the correct number of tests
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            // Confirm the test session has the expected documents
            Assert.AreEqual(testDocumentTemplateStf01.Document.LatestRevision.Content.Content.Length, test1.Document.LatestRevision.Content.Content.Length);
            Assert.AreEqual(testDocumentTemplateStf02.Document.LatestRevision.Content.Content.Length, test2.Document.LatestRevision.Content.Content.Length);
            Assert.AreEqual(testDocumentTemplateStf03.Document.LatestRevision.Content.Content.Length, test3.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test1.Document.LatestRevision.Content.Content.Length > 0);
            Assert.IsTrue(test2.Document.LatestRevision.Content.Content.Length > 0);
            Assert.IsTrue(test3.Document.LatestRevision.Content.Content.Length > 0);

            // Confirm the test documents are of the expected type
            Assert.AreEqual(DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, test1.Document.Type.Id);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, test2.Document.Type.Id);
            Assert.AreEqual(DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, test3.Document.Type.Id);
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add documents to the tests, 
        /// and relevant test mappings exist with the correct equipment type specified, the expected documents are added
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestDocumentsAddsCorrectDocumentsWhenMappingHasEquipmentType()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
            }

            // Update some of the existing test associations to include documents, with the correct equipment type specified
            var equipmentType = testSession.Equipment.EquipmentType;
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test2.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test3.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, equipmentType.Id, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, equipmentType.Id, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test3.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, equipmentType.Id, false);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            // Update test session
            // This should add all the required tests and documents
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            var testDocumentTemplateStf01 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            var testDocumentTemplateStf02 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            var testDocumentTemplateStf03 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test2 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 2);
            var test3 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 3);
            if (testDocumentTemplateStf01 == null || testDocumentTemplateStf02 == null || testDocumentTemplateStf03 == null || test1 == null || test2 == null || test3 == null) throw new Exception("Expected data not found in database");

            // Confirm we still have the correct number of tests
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            // Confirm the test session has the expected documents
            Assert.AreEqual(testDocumentTemplateStf01.Document.LatestRevision.Content.Content.Length, test1.Document.LatestRevision.Content.Content.Length);
            Assert.AreEqual(testDocumentTemplateStf02.Document.LatestRevision.Content.Content.Length, test2.Document.LatestRevision.Content.Content.Length);
            Assert.AreEqual(testDocumentTemplateStf03.Document.LatestRevision.Content.Content.Length, test3.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test1.Document.LatestRevision.Content.Content.Length > 0);
            Assert.IsTrue(test2.Document.LatestRevision.Content.Content.Length > 0);
            Assert.IsTrue(test3.Document.LatestRevision.Content.Content.Length > 0);

            // Confirm the test documents are of the expected type
            Assert.AreEqual(DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, test1.Document.Type.Id);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, test2.Document.Type.Id);
            Assert.AreEqual(DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, test3.Document.Type.Id);
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add documents to the tests, 
        /// and relevant test mappings exist with an invalid equipment type specified, no documents are added
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestDocumentsAddsNoDocumentsWhenMappingHasInvalidEquipmentType()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations
            foreach (var testType in TestType.Types.AllWithNumberGreaterThanZero)
            {
                CreateDocumentAssociation(testSession.TestSessionType.Id, testType.Id, null, null, false);
            }

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
            }

            // Update one of the existing test associations to include documents, with the correct equipment type specified
            var equipmentType = testSession.Equipment.EquipmentType;
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test2.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, equipmentType.Id, false);

            // Update some of the existing test associations to include documents, with an invalid equipment type specified
            Domain.Equipments.EquipmentType otherEquipmentType;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                var otherEquipmentTypes = session.Query<Domain.Equipments.EquipmentType>().Where(et => et.Id != equipmentType.Id).ToList();
                otherEquipmentType = otherEquipmentTypes[new Random().Next(otherEquipmentTypes.Count)];
            }
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test3.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, otherEquipmentType.Id, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test3.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, otherEquipmentType.Id, false);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            // Update test session
            // This should add all the required tests and documents
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            var testDocumentTemplateStf02 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test2 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 2);
            var test3 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 3);
            if (testDocumentTemplateStf02 == null || test1 == null || test2 == null || test3 == null) throw new Exception("Expected data not found in database");

            // Confirm we still have the correct number of tests
            Assert.AreEqual(TestType.Types.AllWithNumberGreaterThanZero.Count, updatedTestSession.Tests.Count);

            // Confirm the test session has the expected document only on the relevant test
            Assert.AreEqual(testDocumentTemplateStf02.Document.LatestRevision.Content.Content.Length, test2.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test2.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, test2.Document.Type.Id);
            Assert.IsNull(test1.Document);
            Assert.IsNull(test3.Document);
        }

        /// <summary>
        /// Test to see if a test session can be updated to add new signatures
        /// </summary>
        [Test]
        public void CanAddNewSignatures()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Give the test session a collection of signatures
            var signatures = new List<Dto.Write.Documents.Document>();
            var documentTypes = new List<DocumentType> {
                    DocumentType.Types.Signatures.TestSessionTesterSignature,
                    DocumentType.Types.Signatures.TestSessionMardixWitnessSignature,
                    DocumentType.Types.Signatures.TestSessionClientWitnessSignature };

            foreach (var documentType in documentTypes)
            {
                var signature = new Dto.Write.Documents.Document
                {
                    FileName = documentType.Name,
                    DocumentContent = Convert.ToBase64String(new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("jpg", new List<Document>()).LatestRevision.Content.Content),
                    MimeType = "image/jpeg",
                    TypeId = documentType.Id
                };
                signatures.Add(signature);
            }
            var testSessionDto = ToDtoWrite(testSession);
            testSessionDto.CoreDocuments = signatures;

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(testSessionDto).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of unique signatures
            Assert.AreEqual(documentTypes.Count, updatedTestSession.Documents.Count(d => documentTypes.Any(dt => dt.Id == d.Type.Id)));
            Assert.That(updatedTestSession.Documents.Where(d => documentTypes.Any(dt => dt.Id == d.Type.Id)).ToList(), Is.Unique);

            // Confirm we have one of each type of signature document
            Assert.That(updatedTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.Signatures.TestSessionTesterSignature.Id));
            Assert.That(updatedTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.Signatures.TestSessionMardixWitnessSignature.Id));
            Assert.That(updatedTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.Signatures.TestSessionClientWitnessSignature.Id));

            // Finally confirm that we have valid document content for each signature
            foreach (var document in updatedTestSession.Documents.Where(d => documentTypes.Any(dt => dt.Id == d.Type.Id)))
            {
                Assert.IsTrue(document.LatestRevision.Content.Content.Length > 0);
            }
        }

        /// <summary>
        /// Test to see if a test session can be updated to modify its existing signatures
        /// </summary>
        [Test]
        public void CanUpdateExistingSignatures()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            var signaturesBefore = new List<Dto.Write.Documents.Document>();
            var signaturesAfter = new List<Dto.Write.Documents.Document>();

            // Give the test session a collection of signatures
            var documentTypes = new List<DocumentType> {
                    DocumentType.Types.Signatures.TestSessionTesterSignature,
                    DocumentType.Types.Signatures.TestSessionMardixWitnessSignature,
                    DocumentType.Types.Signatures.TestSessionClientWitnessSignature };

            foreach (var documentType in documentTypes)
            {
                var signature = new Dto.Write.Documents.Document
                {
                    FileName = documentType.Name,
                    DocumentContent = Convert.ToBase64String(new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("jpg", new List<Document>()).LatestRevision.Content.Content),
                    MimeType = "image/jpeg",
                    TypeId = documentType.Id
                };
                signaturesBefore.Add(signature);
            }
            var testSessionDto = ToDtoWrite(testSession);
            testSessionDto.CoreDocuments = signaturesBefore;

            // Modify the test session's collection of signatures
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(testSessionDto).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            TestSession originalTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                originalTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content) // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (originalTestSession == null) throw new Exception("Expected data not found in database");

                // Confirm we have 3 unique signatures to begin with
                Assert.AreEqual(documentTypes.Count, originalTestSession.Documents.Count(d => documentTypes.Any(dt => dt.Id == d.Type.Id)));
                Assert.That(originalTestSession.Documents.Where(d => documentTypes.Any(dt => dt.Id == d.Type.Id)).ToList(), Is.Unique);

                // Confirm we have one of each type of signature document
                Assert.That(originalTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.Signatures.TestSessionTesterSignature.Id));
                Assert.That(originalTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.Signatures.TestSessionMardixWitnessSignature.Id));
                Assert.That(originalTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.Signatures.TestSessionClientWitnessSignature.Id));
            }

            // Give the test session an updated collection of signatures
            foreach (var documentType in documentTypes)
            {
                var documentType1 = documentType;   // To keep ReSharper happy ...
                var originalDocument = originalTestSession.Documents.FirstOrDefault(d => d.Type.Id == documentType1.Id);

                var signatureAfter = new Dto.Write.Documents.Document
                {
                    FileName = documentType.Name,
                    MimeType = "image/jpeg",
                    TypeId = documentType.Id,
                    DocumentContent = Convert.ToBase64String(new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("jpg", new List<Document>{ originalDocument }).LatestRevision.Content.Content)
                };

                signaturesAfter.Add(signatureAfter);
            }

            testSessionDto.CoreDocuments = signaturesAfter;

            // Update test session
            putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(testSessionDto).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of unique signatures
            Assert.AreEqual(documentTypes.Count, updatedTestSession.Documents.Count(d => documentTypes.Any(dt => dt.Id == d.Type.Id)));
            Assert.That(updatedTestSession.Documents.Where(d => documentTypes.Any(dt => dt.Id == d.Type.Id)).ToList(), Is.Unique);

            // Confirm we have one of each type of signature document
            Assert.That(updatedTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.Signatures.TestSessionTesterSignature.Id));
            Assert.That(updatedTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.Signatures.TestSessionMardixWitnessSignature.Id));
            Assert.That(updatedTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.Signatures.TestSessionClientWitnessSignature.Id));

            // Finally confirm that each document has an updated content length
            foreach (var document in updatedTestSession.Documents.Where(d => documentTypes.Any(dt => dt.Id == d.Type.Id)))
            {
                var originalDocument = originalTestSession.Documents.FirstOrDefault(d => d.Type.Id == document.Type.Id);
                if (originalDocument == null) throw new Exception("Expected data not found in database");
                Assert.AreEqual(1, originalDocument.Revisions.Count);
                Assert.AreEqual(2, document.Revisions.Count);
                Assert.AreNotEqual(originalDocument.LatestRevision.Content.Content.Length, document.LatestRevision.Content.Content.Length);
                Assert.AreNotEqual(originalDocument.LatestRevision.Content.Content.Length, document.Revisions.OrderByDescending(r => r.PublishedDateUtc).First().Content.Content.Length);
                Assert.AreEqual(originalDocument.LatestRevision.Content.Content.Length, document.Revisions.OrderByDescending(r => r.PublishedDateUtc).Last().Content.Content.Length);
            }
        }

        /// <summary>
        /// Test to see if a test session can be updated to modify its existing core documents
        /// </summary>
        [Test]
        public void CanUpdateExistingCoreDocuments()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Give the test session a set of core documents
            var documents = new List<Document>();
            var documentTypes = new List<DocumentType> { DocumentType.Types.TestDocuments.PanelTestCertificate, DocumentType.Types.Uncategorised.ComponentRegister };

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                foreach (var documentType in documentTypes)
                {
                    var document = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
                    document.Type = _documentTypeServices.Single(documentType.Id);

                    session.SaveOrUpdate(document);
                    session.Flush();

                    documents.Add(document);
                }

                testSession.Documents = new HashSet<Document>(documents);
                session.SaveOrUpdate(testSession);
                session.Flush();
            }

            // Get test session data following creation
            TestSession originalTestSession;
            var originalDocuments = new List<Document>();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                originalTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (originalTestSession == null) throw new Exception("Expected data not found in database");
            }
            
            foreach (var originalTestSessionDocument in originalTestSession.Documents)
            {
                var originalDocument = new Document
                {
                    Id = originalTestSessionDocument.Id,
                    Type = originalTestSessionDocument.Type,
                    Description = Path.GetFileNameWithoutExtension(originalTestSessionDocument.LatestRevision.FileName),
                    Revisions = new HashSet<DocumentRevisionMetaData>()
                };
                var documentMetaData = new DocumentRevisionMetaData(originalDocument)
                {
                    DisplayName = Path.GetFileNameWithoutExtension(originalTestSessionDocument.LatestRevision.FileName),
                    FileName = originalTestSessionDocument.LatestRevision.FileName,
                    MimeType = originalTestSessionDocument.LatestRevision.MimeType,
                    CreatedDateUtc = originalTestSessionDocument.LatestRevision.CreatedDateUtc,
                    PublishedDateUtc = originalTestSessionDocument.LatestRevision.PublishedDateUtc,
                    Bytes = originalTestSessionDocument.LatestRevision.Content.Content.Length,
                    Content = new DocumentRevisionContent { Content = originalTestSessionDocument.LatestRevision.Content.Content },
                };
                originalDocument.Revisions.Add(documentMetaData);
                originalDocuments.Add(originalDocument);
            }

            // Confirm test session was created with the expected 2 documents
            Assert.AreEqual(2, originalDocuments.Count);
            Assert.That(originalDocuments.Select(d => d.Type.Id).Contains(DocumentType.Types.TestDocuments.PanelTestCertificate.Id));
            Assert.That(originalDocuments.Select(d => d.Type.Id).Contains(DocumentType.Types.Uncategorised.ComponentRegister.Id));

            // Modify the test session's documents
            var newDocuments = new List<Document>();
            foreach (var originalDocument in originalTestSession.Documents)
            {
                var document = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { originalDocument });
                document.Id = Guid.NewGuid();
                document.Type = originalDocument.Type;
                newDocuments.Add(document);
            }
            originalTestSession.Documents = new HashSet<Document>(newDocuments);

            // Update the test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(originalTestSession)).ExecuteUpdateDelete();

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm test session was updated, and that the existing 2 documents were successfully updated
            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);
            Assert.AreEqual(2, updatedTestSession.Documents.Count);
            foreach (var originalDocument in originalDocuments)
            {
                var updatedDocument = updatedTestSession.Documents.FirstOrDefault(d => d.Type.Id == originalDocument.Type.Id);
                if (updatedDocument == null) throw new Exception("Expected data not found in database");

                Assert.That(originalDocument.Id == updatedDocument.Id);
                Assert.That(originalDocument.LatestRevision.Content.Content.Length != updatedDocument.LatestRevision.Content.Content.Length);
                Assert.IsTrue(updatedDocument.LatestRevision.Content.Content.Length > 0);
            }
        }

        /// <summary>
        /// Test to see if an updated test session has all the required documents when the relevant templates exist
        /// </summary>
        [Test]
        public void UpdatedTestSessionContainsRequiredDocumentsWhenAvailable()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Confirm the test session has no documents to begin with
            Assert.IsEmpty(testSession.Documents);

            // Create new test document template for QMF120
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.PanelTestCertificate.Id);

            // Update the test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has been successfully updated to include the expected documents
            Assert.AreEqual(1, updatedTestSession.Documents.Count);
            Assert.That(updatedTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.TestDocuments.PanelTestCertificate.Id));
            foreach (var document in updatedTestSession.Documents) {
                Assert.IsTrue(document.LatestRevision.Content.Content.Length > 0);
            }
        }

        /// <summary>
        /// Test to see if an updated test session has only those required documents where the relevant templates exist
        /// </summary>
        [Test]
        public void UpdatedTestSessionDoesNotContainRequiredDocumentsWhenUnavailable()
        {
            // TODO: This test will only be relevant when documents other than the QMF120 are required

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Confirm the test session has no documents to begin with
            Assert.IsEmpty(testSession.Documents);

            // Create new test document template for QMF120, but not for component register
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.PanelTestCertificate.Id);

            // Update the test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has been successfully created with only the QMF120 document
            Assert.AreEqual(1, updatedTestSession.Documents.Count);
            Assert.AreEqual(DocumentType.Types.TestDocuments.PanelTestCertificate.Id, updatedTestSession.Documents.Select(d => d.Type.Id).FirstOrDefault());
            foreach (var document in updatedTestSession.Documents) {
                Assert.IsTrue(document.LatestRevision.Content.Content.Length > 0);
            }
        }

        /// <summary>
        /// Test to see if an updated test session has the supplied required document, rather than a new empty version, when this was previously missing
        /// </summary>
        [Test]
        public void UpdatedTestSessionContainsSuppliedDocumentsWhenPreviouslyMissing()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Confirm the test session has no documents to begin with
            Assert.IsEmpty(testSession.Documents);

            // Create new test document template for QMF120
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.PanelTestCertificate.Id);
            var testDocumentTemplate = _testDocumentTemplates.FirstOrDefault(
                tdt => tdt.WoNumber == testSession.Equipment.WorksOrder.WoNumber && tdt.M0 == testSession.Equipment.M0 && tdt.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.PanelTestCertificate.Id
                );
            if (testDocumentTemplate == null) throw new Exception("No test document template found");

            // Give the test session a QMF120 document
            var testSessionDtoWrite = ToDtoWrite(testSession);
            var qmf120Document = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { testDocumentTemplate.Document });
            var qmf120DocumentWrite = new Dto.Write.Documents.Document
            {
                FileName = qmf120Document.LatestRevision.FileName,
                MimeType = qmf120Document.LatestRevision.MimeType,
                DocumentContent = Convert.ToBase64String(qmf120Document.LatestRevision.Content.Content),
                TypeId = DocumentType.Types.TestDocuments.PanelTestCertificate.Id
            };
            testSessionDtoWrite.CoreDocuments = new List<Dto.Write.Documents.Document> { qmf120DocumentWrite };
            
            // Update the test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(testSessionDtoWrite).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has been successfully updated to include the expected document
            Assert.AreEqual(1, updatedTestSession.Documents.Count);
            Assert.That(updatedTestSession.Documents.Select(d => d.Type.Id).Contains(DocumentType.Types.TestDocuments.PanelTestCertificate.Id));

            // Confirm the document is the supplied version and not the template
            foreach (var document in updatedTestSession.Documents.Where(d => d.Type.Id == DocumentType.Types.TestDocuments.PanelTestCertificate.Id))
            {
                Assert.AreEqual(qmf120Document.LatestRevision.Content.Content.Length, document.LatestRevision.Content.Content.Length);
                Assert.AreNotEqual(testDocumentTemplate.Document.LatestRevision.Content.Content.Length, document.LatestRevision.Content.Content.Length);
            }
        }

        /// <summary>
        /// Test to see if an updated test session has no required master document added when it is a test-specific document, exists for the test, and the relevant template exists
        /// </summary>
        [Test]
        public void UpdatedTestSessionContainsRequiredDocumentsWhenMasterDocumentIsTestDocumentPresentAndAvailable()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];
            var testSessionType = testSession.TestSessionType;

            // Create some new document associations
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test3.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                
                // Set the master document type of the test session's type to be the STF02
                testSessionType.MasterDocumentType = _documentTypeServices.Single(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id);
                session.SaveOrUpdate(testSessionType);
                session.Flush();

                // Get the updated test session
                var testSession1 = testSession; // to keep ReSharper happy
                testSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession1.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetch(d => d.Type)    // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
            }
            if (testSession == null) throw new Exception("Expected data not found in database");

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            testSession.Tests.ForEach(_tests.Add);

            // Confirm the test session has no documents to begin with
            Assert.AreEqual(0, testSession.Documents.Count);
            // Confirm that the test session has the expected tests and documents
            Assert.AreEqual(3, testSession.Tests.Count);
            var test = testSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test2.Id);
            if (test == null) throw new Exception("Test not found in database");
            Assert.IsNotNull(test.Document);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, test.Document.Type.Id);
            Assert.IsTrue(test.Document.LatestRevision.Content.Content.Length > 0);

            // Update the test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetch(d => d.Type)    // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has been successfully updated with no additional documents
            Assert.AreEqual(0, updatedTestSession.Documents.Count);
            // Confirm that the test session has the expected tests and documents
            Assert.AreEqual(3, updatedTestSession.Tests.Count);
            var updatedTest = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test2.Id);
            if (updatedTest == null) throw new Exception("Test not found in database");
            Assert.IsNotNull(updatedTest.Document);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, updatedTest.Document.Type.Id);
            Assert.IsTrue(updatedTest.Document.LatestRevision.Content.Content.Length > 0);
        }

        /// <summary>
        /// Test to see if an updated test session has the required master document added to the child test, not the test session, when it is a test-specific document, is missing from the test, and the relevant template exists
        /// </summary>
        [Test]
        public void UpdatedTestSessionContainsRequiredDocumentsOnTestOnlyWhenMasterDocumentIsTestDocumentMissingAndAvailable()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];
            var testSessionType = testSession.TestSessionType;

            // Create some new document associations, but do not create the document templates yet
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test3.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);

                // Set the master document type of the test session's type to be the STF02
                testSessionType.MasterDocumentType = _documentTypeServices.Single(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id);
                session.SaveOrUpdate(testSessionType);
                session.Flush();

                // Get the updated test session
                var testSession1 = testSession; // to keep ReSharper happy
                testSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession1.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetch(d => d.Type)    // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents)
                    .Fetch(t => t.Equipment).ThenFetch(a => a.WorksOrder)
                    .ToFuture()
                    .FirstOrDefault();
            }
            if (testSession == null) throw new Exception("Expected data not found in database");

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            testSession.Tests.ForEach(_tests.Add);

            // Confirm the test session has no documents to begin with
            Assert.AreEqual(0, testSession.Documents.Count);
            // Confirm that the test session has the expected tests and no documents
            var test = testSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test2.Id);
            if (test == null) throw new Exception("Test not found in database");
            Assert.IsNull(test.Document);

            // Create some new test document templates now that the tests have been created without documents
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            // Update the test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);
            
            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetch(d => d.Type)    // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has been successfully updated with no additional documents
            Assert.AreEqual(0, updatedTestSession.Documents.Count);
            // Confirm that the test session has the expected tests and documents
            Assert.AreEqual(3, updatedTestSession.Tests.Count);
            var updatedTest = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test2.Id);
            if (updatedTest == null) throw new Exception("Test not found in database");
            Assert.IsNotNull(updatedTest.Document);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, updatedTest.Document.Type.Id);
            Assert.IsTrue(updatedTest.Document.LatestRevision.Content.Content.Length > 0);
        }

        /// <summary>
        /// Test to see if an updated test session has no required master document added when it is a test-specific document, is missing from the test, and the relevant template does not exist
        /// </summary>
        [Test]
        public void UpdatedTestSessionDoesNotContainRequiredDocumentsWhenWhenMasterDocumentIsTestDocumentMissingAndUnavailable()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];
            var testSessionType = testSession.TestSessionType;

            // Create some new document associations
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test3.Id, DocumentType.Types.TestDocuments.FunctionTestCertificate.Id, null, false);

            // Create some new test document templates, but create STF02 template for a different equipment item
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, "X", DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.FunctionTestCertificate.Id);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);

                // Set the master document type of the test session's type to be the STF02
                testSessionType.MasterDocumentType = _documentTypeServices.Single(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id);
                session.SaveOrUpdate(testSessionType);
                session.Flush();

                // Get the updated test session
                var testSession1 = testSession; // to keep ReSharper happy
                testSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession1.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetch(d => d.Type)    // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
            }
            if (testSession == null) throw new Exception("Expected data not found in database");

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            testSession.Tests.ForEach(_tests.Add);

            // Confirm the test session has no documents to begin with
            Assert.AreEqual(0, testSession.Documents.Count);
            // Confirm that the test session has the expected tests and no documents
            Assert.AreEqual(3, testSession.Tests.Count);
            var test = testSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test2.Id);
            if (test == null) throw new Exception("Test not found in database");
            Assert.IsNull(test.Document);

            // Update the test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetch(d => d.Type)    // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has been successfully updated with no additional documents
            Assert.AreEqual(0, updatedTestSession.Documents.Count);
            // Confirm that the test session has the expected tests and documents
            Assert.AreEqual(3, updatedTestSession.Tests.Count);
            var updatedTest = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test2.Id);
            if (updatedTest == null) throw new Exception("Test not found in database");
            Assert.IsNull(updatedTest.Document);
        }

        /// <summary>
        /// Test to see if an updated test session with an empty core documents collection, has all its existing domain documents preserved
        /// </summary>
        [Test]
        public void UpdatedTestSessionWithEmptyCoreDocumentsCollectionHasAllDomainDocumentsPreserved()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Give the test session a set of core documents and associated documents
            var documents = new List<Document>();
            var documentTypes = new List<DocumentType> { DocumentType.Types.TestDocuments.PanelTestCertificate, DocumentType.Types.Uncategorised.ComponentRegister, DocumentType.Types.TestSessionDocuments.TorqueTestCertificate, DocumentType.Types.TestSessionDocuments.TorqueTestCertificate };

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                foreach (var documentType in documentTypes)
                {
                    var document = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
                    document.Type = _documentTypeServices.Single(documentType.Id);

                    session.SaveOrUpdate(document);
                    session.Flush();

                    documents.Add(document);
                }

                testSession.Documents = new HashSet<Document>(documents);
                session.SaveOrUpdate(testSession);
                session.Flush();
            }

            // Get test session data following update
            TestSession originalTestSession;
            var originalDocuments = new List<Document>();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                originalTestSession = session.Query<TestSession>()
                    .Where(ts => ts.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (originalTestSession == null) throw new Exception("Expected data not found in database");
            }

            foreach (var originalTestSessionDocument in originalTestSession.Documents)
            {
                var originalDocument = new Document
                {
                    Id = originalTestSessionDocument.Id,
                    Type = originalTestSessionDocument.Type,
                    Description = Path.GetFileNameWithoutExtension(originalTestSessionDocument.LatestRevision.FileName),
                    Revisions = new HashSet<DocumentRevisionMetaData>()
                };
                var documentMetaData = new DocumentRevisionMetaData(originalDocument)
                {
                    DisplayName = Path.GetFileNameWithoutExtension(originalTestSessionDocument.LatestRevision.FileName),
                    FileName = originalTestSessionDocument.LatestRevision.FileName,
                    MimeType = originalTestSessionDocument.LatestRevision.MimeType,
                    CreatedDateUtc = originalTestSessionDocument.LatestRevision.CreatedDateUtc,
                    PublishedDateUtc = originalTestSessionDocument.LatestRevision.PublishedDateUtc,
                    Bytes = originalTestSessionDocument.LatestRevision.Content.Content.Length,
                    Content = new DocumentRevisionContent { Content = originalTestSessionDocument.LatestRevision.Content.Content },
                };
                originalDocument.Revisions.Add(documentMetaData);
                originalDocuments.Add(originalDocument);
            }

            // Now clear the object's documents collection, and update the test session
            testSession.Documents.Clear();
            var testSessionWriteWithoutDocuments = ToDtoWrite(testSession);
            Assert.AreEqual(0, testSessionWriteWithoutDocuments.CoreDocuments.Count);

            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(testSessionWriteWithoutDocuments).ExecuteUpdateDelete();
            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has been successfully updated, but that the domain documents have been preserved
            Assert.AreEqual(documentTypes.Count, updatedTestSession.Documents.Count);
            foreach (var originalDocument in originalDocuments)
            {
                Assert.IsTrue(updatedTestSession.Documents.Any(d => d.Id == originalDocument.Id));
            }
            foreach (var updatedDocument in updatedTestSession.Documents)
            {
                Assert.IsTrue(originalDocuments.Any(d => d.Id == updatedDocument.Id));
                var originalDocument = originalDocuments.FirstOrDefault(d => d.Id == updatedDocument.Id);
                if (originalDocument == null) throw new Exception("Expected data not found in database");
                Assert.AreEqual(originalDocument.Type.Id, updatedDocument.Type.Id);
                Assert.AreEqual(originalDocument.LatestRevision.Content.Content.Length, updatedDocument.LatestRevision.Content.Content.Length);
                Assert.Greater(updatedDocument.LatestRevision.Content.Content.Length, 0);
            }
        }

        /// <summary>
        /// Test to see if an updated test session with a partial documents collection, has all its existing domain documents preserved
        /// </summary>
        [Test]
        public void UpdatedTestSessionWithPartialCoreDocumentsCollectionHasAllDomainDocumentsPreserved()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Give the test session a set of core documents and associated documents
            var documents = new List<Document>();
            var documentTypes = new List<DocumentType> { DocumentType.Types.TestDocuments.PanelTestCertificate, DocumentType.Types.Uncategorised.ComponentRegister, DocumentType.Types.TestSessionDocuments.TorqueTestCertificate, DocumentType.Types.TestSessionDocuments.TorqueTestCertificate };

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                foreach (var documentType in documentTypes)
                {
                    var document = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
                    document.Type = _documentTypeServices.Single(documentType.Id);

                    session.SaveOrUpdate(document);
                    session.Flush();

                    documents.Add(document);
                }

                testSession.Documents = new HashSet<Document>(documents);
                session.SaveOrUpdate(testSession);
                session.Flush();
            }

            // Get test session data following update
            TestSession originalTestSession;
            var originalDocuments = new List<Document>();
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                originalTestSession = session.Query<TestSession>()
                    .Where(ts => ts.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (originalTestSession == null) throw new Exception("Expected data not found in database");
            }

            foreach (var originalTestSessionDocument in originalTestSession.Documents)
            {
                var originalDocument = new Document
                {
                    Id = originalTestSessionDocument.Id,
                    Type = originalTestSessionDocument.Type,
                    Description = Path.GetFileNameWithoutExtension(originalTestSessionDocument.LatestRevision.FileName),
                    Revisions = new HashSet<DocumentRevisionMetaData>()
                };
                var documentMetaData = new DocumentRevisionMetaData(originalDocument)
                {
                    DisplayName = Path.GetFileNameWithoutExtension(originalTestSessionDocument.LatestRevision.FileName),
                    FileName = originalTestSessionDocument.LatestRevision.FileName,
                    MimeType = originalTestSessionDocument.LatestRevision.MimeType,
                    CreatedDateUtc = originalTestSessionDocument.LatestRevision.CreatedDateUtc,
                    PublishedDateUtc = originalTestSessionDocument.LatestRevision.PublishedDateUtc,
                    Bytes = originalTestSessionDocument.LatestRevision.Content.Content.Length,
                    Content = new DocumentRevisionContent { Content = originalTestSessionDocument.LatestRevision.Content.Content },
                };
                originalDocument.Revisions.Add(documentMetaData);
                originalDocuments.Add(originalDocument);
            }

            // Now remove all documents but the Component Register, and update that document to a new version
            testSession.Documents.Clear();
            
            var componentRegister = originalTestSession.Documents.FirstOrDefault(d => d.Type.Id == DocumentType.Types.Uncategorised.ComponentRegister.Id);
            if (componentRegister == null) throw new Exception("Expected data not found in database");

            var newDocument = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { componentRegister });
            newDocument.Id = Guid.NewGuid();
            newDocument.Type = _documentTypeServices.Single(DocumentType.Types.Uncategorised.ComponentRegister.Id);
            newDocument.LatestRevision.PublishedDateUtc = componentRegister.LatestRevision.PublishedDateUtc.AddMinutes(1);
            testSession.Documents.Add(newDocument);

            var testSessionWriteWithoutDocuments = ToDtoWrite(testSession);
            Assert.AreEqual(1, testSessionWriteWithoutDocuments.CoreDocuments.Count);

            // Update the test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(testSessionWriteWithoutDocuments).ExecuteUpdateDelete();
            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has been successfully updated, but that the domain documents have been preserved
            Assert.AreEqual(documentTypes.Count, updatedTestSession.Documents.Count);
            foreach (var originalDocument in originalDocuments)
            {
                Assert.IsTrue(updatedTestSession.Documents.Any(d => d.Id == originalDocument.Id));
            }
            foreach (var updatedDocument in updatedTestSession.Documents)
            {
                Assert.IsTrue(originalDocuments.Any(d => d.Id == updatedDocument.Id));
                var originalDocument = originalDocuments.FirstOrDefault(d => d.Id == updatedDocument.Id);
                if (originalDocument == null) throw new Exception("Expected data not found in database");
                Assert.AreEqual(originalDocument.Type.Id, updatedDocument.Type.Id);
                Assert.Greater(updatedDocument.LatestRevision.Content.Content.Length, 0);
                if (updatedDocument.Type.Id == DocumentType.Types.Uncategorised.ComponentRegister.Id)
                    Assert.AreNotEqual(originalDocument.LatestRevision.Content.Content.Length, updatedDocument.LatestRevision.Content.Content.Length);
                else
                    Assert.AreEqual(originalDocument.LatestRevision.Content.Content.Length, updatedDocument.LatestRevision.Content.Content.Length);
            }
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add tests, 
        /// the expected tests are added when the 'hidden and not applicable when no template' flag is not set, and no template exists
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestsAddsTestsWhenHiddenNoTemplateFlagNotSetTemplateDoesNotExist()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test association for test 1
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, null, null, false);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests to begin with
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Create a new test association including a document
            // Hidden/not applicable flag not set in the associations
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, false);

            // Do not create test document templates

            // Update test session
            // This should now update any existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            // Confirm we have the correct updated number of tests
            Assert.AreEqual(2, updatedTestSession.Tests.Count);

            // Confirm the test session contains the expected test numbers, and have no documents
            var expectedTestNumbers = new[] { 1, 2 };
            foreach (var test in updatedTestSession.Tests)
            {
                Assert.Contains(test.TestType.Number, expectedTestNumbers);
                Assert.IsNull(test.Document);
            }

            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test2 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 2);
            if (test1 == null || test2 == null) throw new Exception("Expected data not found in database");
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add tests, 
        /// the expected tests are added when the 'hidden and not applicable when no template' flag is not set, and a template exists
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestsAddsTestsWhenHiddenNoTemplateFlagNotSetTemplateExists()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test association for test 1
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, null, null, false);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests to begin with
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Create a new test association including a document
            // Hidden/not applicable flag not set in the associations
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, false);

            // Create a new test document template
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);

            // Get the content length of the template document
            var testDocumentTemplate = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            if (testDocumentTemplate == null) throw new Exception("Expected data not found in database");
            var templateTest2DocumentContentLength = testDocumentTemplate.Document.LatestRevision.Content.Content.Length;

            // Update test session
            // This should now update any existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            // Confirm we have the correct updated number of tests
            Assert.AreEqual(2, updatedTestSession.Tests.Count);

            // Confirm the test session contains the expected test numbers
            var expectedTestNumbers = new[] { 1, 2 };
            foreach (var test in updatedTestSession.Tests)
                Assert.Contains(test.TestType.Number, expectedTestNumbers);

            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test2 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 2);
            if (test1 == null || test2 == null) throw new Exception("Expected data not found in database");

            // Confirm test 2 has the expected new template document with the expected document type
            Assert.AreEqual(templateTest2DocumentContentLength, test2.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test2.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, test2.Document.Type.Id);

            // Confirm test 1 still has no document
            Assert.IsNull(test1.Document);
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add tests, 
        /// existing tests and documents are preserved when the 'hidden and not applicable when no template' flag is not set, the test has a document, and no template exists
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestsPreservesTestAndDocumentWhenHiddenNoTemplateFlagNotSetDocumentExistsTemplateDoesNotExist()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations for test 1
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, null, null, false);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests to begin with
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Update two test associations to include documents
            // Hidden/not applicable flag not set in the associations
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, false);

            // Do not create test document templates

            // Give test 1 a document
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test1.Id);
            var document1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            if (test1 == null || document1 == null) throw new Exception("Expected data not found in database");

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.Flush();
                test1.Document = document1;
                session.SaveOrUpdate(test1);
                session.Flush();
            }

            // Get the content length of test 1's document
            var test1DocumentContentLength = document1.LatestRevision.Content.Content.Length;

            // Update test session
            // This should now update any existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            // Confirm we have the correct updated number of tests
            Assert.AreEqual(2, updatedTestSession.Tests.Count);

            // Confirm the test session contains the expected test numbers
            var expectedTestNumbers = new[] { 1, 2 };
            foreach (var test in updatedTestSession.Tests)
                Assert.Contains(test.TestType.Number, expectedTestNumbers);

            test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test2 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 2);
            if (test1 == null || test2 == null) throw new Exception("Expected data not found in database");

            // Confirm test 1 still has the old document
            Assert.IsNotNull(test1.Document);
            Assert.AreEqual(test1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test1.Document.LatestRevision.Content.Content.Length > 0);

            // Confirm test 2 has no document
            Assert.IsNull(test2.Document);
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add test documents, 
        /// existing tests and documents are preserved when the 'hidden and not applicable when no template' flag is not set, the test has a document, and a template exists
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestsPreservesTestAndDocumentWhenHiddenNoTemplateFlagNotSetDocumentExistsTemplateExists()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations for test 1
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, null, null, false);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests to begin with
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Update two test associations to include documents
            // Hidden/not applicable flag not set in the associations
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, false);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, false);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);

            var testDocumentTemplateStf01 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            var testDocumentTemplateStf02 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            if (testDocumentTemplateStf01 == null || testDocumentTemplateStf02 == null) throw new Exception("Expected data not found in database");

            // Give test 1 a document
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test1.Id);
            if (test1 == null) throw new Exception("Expected data not found in database");
            var document1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { testDocumentTemplateStf01.Document });
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.Flush();
                test1.Document = document1;
                session.SaveOrUpdate(test1);
                session.Flush();
            }

            // Get the content length of the four documents - each test's existing docment, and the two templates
            var test1DocumentContentLength = document1.LatestRevision.Content.Content.Length;
            var templateTest1DocumentContentLength = testDocumentTemplateStf01.Document.LatestRevision.Content.Content.Length;
            var templateTest2DocumentContentLength = testDocumentTemplateStf02.Document.LatestRevision.Content.Content.Length;

            // Update test session
            // This should now update any existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test2 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 2);
            if (test1 == null || test2 == null) throw new Exception("Expected data not found in database");

            // Confirm we have the correct updated number of tests
            Assert.AreEqual(2, updatedTestSession.Tests.Count);

            // Confirm the test session contains the expected test numbers
            var expectedTestNumbers = new[] { 1, 2 };
            foreach (var test in updatedTestSession.Tests)
                Assert.Contains(test.TestType.Number, expectedTestNumbers);

            // Confirm test 2 has the expected new template document with the expected document type
            Assert.AreEqual(templateTest2DocumentContentLength, test2.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test2.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, test2.Document.Type.Id);

            // Confirm test 1 still has the old document, and not the template version
            Assert.AreEqual(test1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test1.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreNotEqual(templateTest1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add tests, 
        /// the expected tests are not added when the 'hidden and not applicable when no template' flag is set, and no template exists
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestsDoesNotAddTestsWhenHiddenNoTemplateFlagSetTemplateDoesNotExist()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test association for test 1
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, null, null, false);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests to begin with
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Create a new test association including a document
            // Hidden/not applicable flag set in the associations
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, true);

            // Do not create test document templates

            // Update test session
            // This should now update any existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            if (test1 == null) throw new Exception("Expected data not found in database");
            
            // Confirm we still have the correct number of tests
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Confirm the test session contains the expected test numbers
            var expectedTestNumbers = new[] { 1 };
            foreach (var test in updatedTestSession.Tests)
                Assert.Contains(test.TestType.Number, expectedTestNumbers);
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add tests, 
        /// the expected tests are added when the 'hidden and not applicable when no template' flag is set, and a template exists
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestsAddsTestsWhenHiddenNoTemplateFlagSetTemplateExists()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test association for test 1
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, null, null, false);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests to begin with
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Create a new test association including a document
            // Hidden/not applicable flag set in the associations
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, true);

            // Create a new test document template
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);

            // Get the content length of the template document
            var testDocumentTemplateStf02 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            if (testDocumentTemplateStf02 == null) throw new Exception("Expected data not found in database");
            var templateTest2DocumentContentLength = testDocumentTemplateStf02.Document.LatestRevision.Content.Content.Length;

            // Update test session
            // This should now update any existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test2 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 2);
            if (test1 == null || test2 == null) throw new Exception("Expected data not found in database");

            // Confirm we have the correct updated number of tests
            Assert.AreEqual(2, updatedTestSession.Tests.Count);

            // Confirm the test session contains the expected test numbers
            var expectedTestNumbers = new[] { 1, 2 };
            foreach (var test in updatedTestSession.Tests)
                Assert.Contains(test.TestType.Number, expectedTestNumbers);

            // Confirm test 2 has the expected new template document with the expected document type
            Assert.AreEqual(templateTest2DocumentContentLength, test2.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test2.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, test2.Document.Type.Id);

            // Confirm test 1 still has no document
            Assert.IsNull(test1.Document);
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add tests, 
        /// existing tests and documents are preserved when the 'hidden and not applicable when no template' flag is set, the test has a document, and no template exists
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestsPreservesTestAndDocumentWhenHiddenNoTemplateFlagSetDocumentExistsTemplateDoesNotExist()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations for test 1
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, null, null, false);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests to begin with
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Update two test associations to include documents
            // Hidden/not applicable flag set in the associations
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, true);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, true);

            // Do not create test document templates

            // Give test 1 a document
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test1.Id);
            var document1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            if (test1 == null || document1 == null) throw new Exception("Expected data not found in database");

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.Flush();
                test1.Document = document1;
                session.SaveOrUpdate(test1);
                session.Flush();
            }

            // Get the content length of test 1's document
            var test1DocumentContentLength = document1.LatestRevision.Content.Content.Length;

            // Update test session
            // This should now update any existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            if (test1 == null) throw new Exception("Expected data not found in database");

            // Confirm we still have the correct number of tests
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Confirm the test session contains the expected test numbers
            var expectedTestNumbers = new[] { 1 };
            foreach (var test in updatedTestSession.Tests)
                Assert.Contains(test.TestType.Number, expectedTestNumbers);

            // Confirm test 1 still has the old document
            Assert.IsNotNull(test1.Document);
            Assert.AreEqual(test1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test1.Document.LatestRevision.Content.Content.Length > 0);
        }

        /// <summary>
        /// Test to confirm that when a test session with a test collection is updated to add test documents, 
        /// existing tests and documents are preserved when the 'hidden and not applicable when no template' flag is set, the test has a document, and a template exists
        /// </summary>
        [Test]
        public void UpdatingTestSessionToAddTestsPreservesTestAndDocumentWhenHiddenNoTemplateFlagSetDocumentExistsTemplateExists()
        {
            TestSession updatedTestSession;

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Create test associations for test 1
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, null, null, false);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Generate all tests for the test session
                AddAllTestsToTestSession(session, testSession, _testTypeServices, _resultServices, _fileSystemServices);
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests)    // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm we have the correct number of tests to begin with
            Assert.AreEqual(1, updatedTestSession.Tests.Count);

            // Update two test associations to include documents
            // Hidden/not applicable flag set in the associations
            RemoveDocumentAssociation(_documentAssociations.FirstOrDefault(a => a.TestType.Id == TestType.Types.Test1.Id));
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test1.Id, DocumentType.Types.TestDocuments.VisualInspectionCertificate.Id, null, true);
            CreateDocumentAssociation(testSession.TestSessionType.Id, TestType.Types.Test2.Id, DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, null, true);

            // Create some new test document templates
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            CreateTestDocumentTemplate(testSession.Equipment.WorksOrder.WoNumber, testSession.Equipment.M0, DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);

            var testDocumentTemplateStf01 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.VisualInspectionCertificate.Id);
            var testDocumentTemplateStf02 = _testDocumentTemplates.FirstOrDefault(t => t.Document.Type.Id == DocumentType.Types.TestDocumentTemplates.MechanicalOperationCertificate.Id);
            if (testDocumentTemplateStf01 == null || testDocumentTemplateStf02 == null) throw new Exception("Expected data not found in database");

            // Give test 1 a document
            var test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Id == TestType.Types.Test1.Id);
            if (test1 == null) throw new Exception("Expected data not found in database");

            var document1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document> { testDocumentTemplateStf01.Document }); 
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                session.SaveOrUpdate(document1);
                session.Flush();
                test1.Document = document1;
                session.SaveOrUpdate(test1);
                session.Flush();
            }

            // Get the content length of the four documents - each test's existing docment, and the two templates
            var test1DocumentContentLength = document1.LatestRevision.Content.Content.Length;
            var templateTest1DocumentContentLength = testDocumentTemplateStf01.Document.LatestRevision.Content.Content.Length;
            var templateTest2DocumentContentLength = testDocumentTemplateStf02.Document.LatestRevision.Content.Content.Length;

            // Update test session
            // This should now update any existing tests to add missing documents, now the associations and templates have been added
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.TestType) // Expand child objects that we need to refer to following session closure
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Add each test to the list of persisted tests
            // so we can remove them when we have finished
            updatedTestSession.Tests.ForEach(_tests.Add);

            test1 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 1);
            var test2 = updatedTestSession.Tests.FirstOrDefault(t => t.TestType.Number == 2);
            if (test1 == null || test2 == null) throw new Exception("Expected data not found in database");

            // Confirm we still have the correct number of tests
            Assert.AreEqual(2, updatedTestSession.Tests.Count);

            // Confirm the test session contains the expected test numbers
            var expectedTestNumbers = new[] { 1, 2 };
            foreach (var test in updatedTestSession.Tests)
                Assert.Contains(test.TestType.Number, expectedTestNumbers);

            // Confirm test 2 has the expected new template document with the expected document type
            Assert.AreEqual(templateTest2DocumentContentLength, test2.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test2.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreEqual(DocumentType.Types.TestDocuments.MechanicalOperationCertificate.Id, test2.Document.Type.Id);

            // Confirm test 1 still has the old document, and not the template version
            Assert.AreEqual(test1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);
            Assert.IsTrue(test1.Document.LatestRevision.Content.Content.Length > 0);
            Assert.AreNotEqual(templateTest1DocumentContentLength, test1.Document.LatestRevision.Content.Content.Length);
        }

        /// <summary>
        /// Test to confirm that a new document revision is created when the core document content changes
        /// </summary>
        /// <remarks>
        /// We don't perform a similar check for file name or mime type as these use the existing properties when test session documents are updated
        /// </remarks>
        [Test]
        public void UpdatingTestSessionCoreDocumentCreatesNewRevisionWhenDocumentContentChanges()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            TestSession updatedTestSession;
            Document updatedDocument1;
            Document updatedDocument2;
            Guid latestRevisionId;
            string latestRevisionFileChecksum;

            // Give the test session two documents
            var document1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            document1.Type = _documentTypeServices.Single(DocumentType.Types.TestDocuments.PanelTestCertificate.Id);
            var document2 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            document2.Type = _documentTypeServices.Single(DocumentType.Types.Uncategorised.ComponentRegister.Id);
            testSession.Documents = new HashSet<Document>(new List<Document> { document1, document2 });
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();
            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");

                // Confirm the documents have been created as expected
                Assert.AreEqual(2, updatedTestSession.Documents.Count);
                updatedDocument1 = updatedTestSession.Documents.FirstOrDefault(d => d.Type.Id == document1.Type.Id);
                if (updatedDocument1 == null) throw new Exception("Expected data not found in database");
                updatedDocument2 = updatedTestSession.Documents.FirstOrDefault(d => d.Type.Id == document2.Type.Id);
                if (updatedDocument2 == null) throw new Exception("Expected data not found in database");

                // Confirm the documents have the expected revisions
                Assert.AreEqual(1, document1.Revisions.Count);
                Assert.AreEqual(1, document2.Revisions.Count);

                latestRevisionId = updatedDocument1.LatestRevision.Id;
                latestRevisionFileChecksum = updatedDocument1.LatestRevision.Content.FileChecksum;
            }

            // Modify the first document's document content
            var newDocument = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>{ document1 });
            var newDocumentLatestRevisionFileChecksum = _fileSystemServices.GenerateFileChecksum(newDocument.LatestRevision.Content.Content);
            document1.LatestRevision.Content.Content = newDocument.LatestRevision.Content.Content;

            // Update the test session
            putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();
            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");

                // Confirm we still have 2 documents
                Assert.AreEqual(2, updatedTestSession.Documents.Count);
                updatedDocument1 = updatedTestSession.Documents.FirstOrDefault(d => d.Type.Id == document1.Type.Id);
                if (updatedDocument1 == null) throw new Exception("Expected data not found in database");
                updatedDocument2 = updatedTestSession.Documents.FirstOrDefault(d => d.Type.Id == document2.Type.Id);
                if (updatedDocument2 == null) throw new Exception("Expected data not found in database");

                // Confirm the documents have the expected revisions
                Assert.AreEqual(2, updatedDocument1.Revisions.Count);
                Assert.AreEqual(1, updatedDocument2.Revisions.Count);
                Assert.AreEqual(document1.LatestRevision.FileName, updatedDocument1.LatestRevision.FileName);
                Assert.AreEqual(document1.LatestRevision.MimeType, updatedDocument1.LatestRevision.MimeType);
                Assert.AreNotEqual(latestRevisionId, updatedDocument1.LatestRevision.Id);
                Assert.AreEqual(newDocumentLatestRevisionFileChecksum, updatedDocument1.LatestRevision.Content.FileChecksum);
                Assert.AreNotEqual(latestRevisionFileChecksum, updatedDocument1.LatestRevision.Content.FileChecksum);
            }
        }

        /// <summary>
        /// Test to confirm that a new core document revision is not created when the file name, mime type and document content do not change
        /// </summary>
        [Test]
        public void UpdatingTestSessionCoreDocumentDoesNotCreateNewRevisionWhenDocumentContentDoesNotChange()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            TestSession updatedTestSession;
            Document updatedDocument1;
            Document updatedDocument2;
            Guid latestRevisionId;
            string latestRevisionFileChecksum;

            // Give the test session two documents
            var document1 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            document1.Type = _documentTypeServices.Single(DocumentType.Types.TestDocuments.PanelTestCertificate.Id);
            var document2 = new Tests.Common.DataGenerator.Document(_documentServices, _documentTypeServices, _fileSystemServices).TestDocumentWithExtension("pdf", new List<Document>());
            document2.Type = _documentTypeServices.Single(DocumentType.Types.Uncategorised.ComponentRegister.Id);
            testSession.Documents = new HashSet<Document>(new List<Document> { document1, document2 });
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();
            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");

                // Confirm the documents have been created as expected
                Assert.AreEqual(2, updatedTestSession.Documents.Count);
                updatedDocument1 = updatedTestSession.Documents.FirstOrDefault(d => d.Type.Id == document1.Type.Id);
                if (updatedDocument1 == null) throw new Exception("Expected data not found in database");
                updatedDocument2 = updatedTestSession.Documents.FirstOrDefault(d => d.Type.Id == document2.Type.Id);
                if (updatedDocument2 == null) throw new Exception("Expected data not found in database");

                // Confirm the documents have the expected revisions
                Assert.AreEqual(1, document1.Revisions.Count);
                Assert.AreEqual(1, document2.Revisions.Count);

                latestRevisionId = updatedDocument1.LatestRevision.Id;
                latestRevisionFileChecksum = updatedDocument1.LatestRevision.Content.FileChecksum;
            }

            // Make no changes

            // Update the test session
            putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();
            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession.Id)
                    .FetchMany(t => t.Documents).ThenFetch(d => d.Type) // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Documents).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .ToFuture()
                    .FirstOrDefault();
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");

                // Confirm we still have 2 documents
                Assert.AreEqual(2, updatedTestSession.Documents.Count);
                updatedDocument1 = updatedTestSession.Documents.FirstOrDefault(d => d.Type.Id == document1.Type.Id);
                if (updatedDocument1 == null) throw new Exception("Expected data not found in database");
                updatedDocument2 = updatedTestSession.Documents.FirstOrDefault(d => d.Type.Id == document2.Type.Id);
                if (updatedDocument2 == null) throw new Exception("Expected data not found in database");

                // Confirm the documents have the expected revisions
                Assert.AreEqual(1, updatedDocument1.Revisions.Count);
                Assert.AreEqual(1, updatedDocument2.Revisions.Count);
                Assert.AreEqual(document1.LatestRevision.FileName, updatedDocument1.LatestRevision.FileName);
                Assert.AreEqual(document1.LatestRevision.MimeType, updatedDocument1.LatestRevision.MimeType);
                Assert.AreEqual(latestRevisionId, updatedDocument1.LatestRevision.Id);
                Assert.AreEqual(latestRevisionFileChecksum, updatedDocument1.LatestRevision.Content.FileChecksum);
            }
        }

        /// <summary>
        /// Test to confirm that an updated test session has its status and end date set if both signatories are present, with a Mardix witness sign-off
        /// </summary>
        [Test]
        public void UpdatedTestSessionHasStatusAndEndDateSetWhenBothSignatoriesPresentForMardixSignOff()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Confirm status and end date are not set to begin with
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, testSession.Status.Id);
            Assert.IsNull(testSession.EndDate);

            // Give the test session a Mardix signatory and a Mardix witness signatory
            testSession.MardixSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.MardixWitnessSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.Result = _resultServices.Single(TestResult.Results.Pass.Id);

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession.Id);
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has had its status and end date successfully set
            Assert.AreEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession.Status.Id);
            Assert.IsNotNull(updatedTestSession.EndDate);
        }

        /// <summary>
        /// Test to confirm that an updated test session has its status and end date set if both signatories are present, with a client witness sign-off
        /// </summary>
        [Test]
        public void UpdatedTestSessionHasStatusAndEndDateSetWhenBothSignatoriesPresentForClientSignOff()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Confirm status and end date are not set to begin with
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, testSession.Status.Id);
            Assert.IsNull(testSession.EndDate);

            // Create a new client witness signatory for the test session's equipment organisation
            Signatory clientWitnessSignatory;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                clientWitnessSignatory = new TestSessionClientWitnessSignatory(_employeeServices, _organisationServices).TestWitnessSignatory();
                clientWitnessSignatory.Organisation = testSession.Equipment.Branch.Organisation;

                session.SaveOrUpdate(clientWitnessSignatory);
                session.Flush();

                // Add client witness signatory to the list of persisted client witness signatories
                // so we can remove it when we have finished
                _clientWitnessSignatories.Add(clientWitnessSignatory);

                session.Flush();
            }

            // Give the test session a Mardix signatory and a client witness signatory
            testSession.MardixSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.ClientWitnessSignatory = clientWitnessSignatory;
            testSession.Result = _resultServices.Single(TestResult.Results.Pass.Id);

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession.Id);
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has had its status and end date successfully set
            Assert.AreEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession.Status.Id);
            Assert.IsNotNull(updatedTestSession.EndDate);
        }

        /// <summary>
        /// Test to confirm that an updated test session has its status and end date set if only the Mardix signatory is present, and a witness is not required
        /// </summary>
        [Test]
        public void UpdatedTestSessionHasStatusAndEndDateSetWhenOnlyMardixSignatoryPresentAndDoesNotRequireWitness()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];
            var testSessionType = testSession.TestSessionType;

            // Confirm status and end date are not set to begin with
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, testSession.Status.Id);
            Assert.IsNull(testSession.EndDate);

            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                // Set the requires witness flag of the test session's type
                testSessionType.RequiresWitness = false;
                session.SaveOrUpdate(testSessionType);
                session.Flush();

                // Get the updated test session
                var testSession1 = testSession; // to keep ReSharper happy
                testSession = session.Query<TestSession>()
                    .Where(t => t.Id == testSession1.Id)
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetch(d => d.Type)    // Expand child objects that we need to refer to following session closure
                    .FetchMany(t => t.Tests).ThenFetch(t => t.Document).ThenFetchMany(d => d.Revisions).ThenFetch(r => r.Content)
                    .FetchMany(t => t.Documents)
                    .ToFuture()
                    .FirstOrDefault();
            }
            if (testSession == null) throw new Exception("Expected data not found in database");

            // Give the test session a Mardix signatory only
            testSession.MardixSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.Result = _resultServices.Single(TestResult.Results.Pass.Id);

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession.Id);
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has had its status and end date successfully set
            Assert.AreEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession.Status.Id);
            Assert.IsNotNull(updatedTestSession.EndDate);
        }

        /// <summary>
        /// Test to confirm that an updated test session has the supplied end date set if both signatories are present
        /// </summary>
        [Test]
        public void UpdatedTestSessionHasEndDateSetToSuppliedDateWhenBothSignatoriesPresent()
        {
            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Confirm status and end date are not set to begin with
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, testSession.Status.Id);
            Assert.IsNull(testSession.EndDate);

            // Give the test session a Mardix signatory and a Mardix witness signatory
            testSession.MardixSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.MardixWitnessSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.Result = _resultServices.Single(TestResult.Results.Pass.Id);

            // Give the test session a specific end date
            var date = SystemTime.UtcNow();
            var endDate = new DateTime(date.Year, date.Month, date.Day, new Random().Next(0, 23), new Random().Next(0, 59), 0, 0);
            testSession.EndDate = endDate;

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession.Id);
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has had its status and end date successfully set
            Assert.AreEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession.Status.Id);
            Assert.IsNotNull(updatedTestSession.EndDate);
            Assert.AreEqual(endDate, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.EndDate));
        }

        /// <summary>
        /// Test to confirm that an updated test session has the supplied end date set if both signatories are present and the end date was previously set
        /// </summary>
        [Test]
        public void UpdatedTestSessionHasEndDateSetToSuppliedDateWhenBothSignatoriesPresentAnEndDatePreviouslySet()
        {
            var date = SystemTime.UtcNow();
            var endDate1 = new DateTime(date.Year, date.Month, date.Day, new Random().Next(0, 23), new Random().Next(0, 59), 0, 0);
            var endDate2 = endDate1.AddDays(1);

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Give the test session a specific end date
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                testSession.EndDate = endDate1;

                session.SaveOrUpdate(testSession);
                session.Flush();
            }

            // Confirm status and end date are not set to begin with
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, testSession.Status.Id);
            Assert.IsNotNull(testSession.EndDate);
            Assert.AreEqual(endDate1, (DateTime)testSession.EndDate);
            Assert.AreNotEqual(endDate2, (DateTime)testSession.EndDate);

            // Give the test session a Mardix signatory and a Mardix witness signatory
            testSession.MardixSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.MardixWitnessSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.Result = _resultServices.Single(TestResult.Results.Pass.Id);

            // Give the test session a new end date
            testSession.EndDate = endDate2;

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession.Id);
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has had its status and end date successfully set
            Assert.AreEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession.Status.Id);
            Assert.IsNotNull(updatedTestSession.EndDate);
            Assert.AreNotEqual(endDate1, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.EndDate));
            Assert.AreEqual(endDate2, TimeZone.CurrentTimeZone.ToLocalTime((DateTime)updatedTestSession.EndDate));
        }

        /// <summary>
        /// Test to confirm that an updated test session has its end date preserved if both signatories are present, no end date is supplied, and the end date was previously set
        /// </summary>
        [Test]
        public void UpdatedTestSessionHasEndDatePreservedWhenBothSignatoriesPresentAndEndDatePreviouslySet()
        {
            var date = SystemTime.UtcNow();
            var endDate = new DateTime(date.Year, date.Month, date.Day, new Random().Next(0, 23), new Random().Next(0, 59), 0, 0);

            // Get a random test session
            var testSession = _testSessions[new Random().Next(_testSessions.Count)];

            // Give the test session a specific end date
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                testSession.EndDate = endDate;

                session.SaveOrUpdate(testSession);
                session.Flush();
            }

            // Confirm status is not set to begin with, but that end date is
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, testSession.Status.Id);
            Assert.IsNotNull(testSession.EndDate);
            Assert.AreEqual(endDate, (DateTime)testSession.EndDate);

            // Give the test session a Mardix signatory and a Mardix witness signatory
            testSession.MardixSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.MardixWitnessSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession.Result = _resultServices.Single(TestResult.Results.Pass.Id);

            // Clear the test session end date
            testSession.EndDate = null;

            // Update test session
            var putResponse = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession.Id).WithResource(ToDtoWrite(testSession)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession.Id);
                if (updatedTestSession == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test session has had its status and end date successfully set
            Assert.AreEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession.Status.Id);
            Assert.IsNotNull(updatedTestSession.EndDate);
            Assert.AreEqual(endDate, (DateTime)updatedTestSession.EndDate);
        }

        /// <summary>
        /// Test to confirm that an updated test session does not have its status or end date set if only one signatory is present
        /// </summary>
        [Test]
        public void UpdatedTestSessionDoesNotHaveStatusOrEndDateSetWhenOnlyOneSignatoryPresent()
        {
            // Get some random test sessions
            var testSession1 = _testSessions[0];
            var testSession2 = _testSessions[1];
            var testSession3 = _testSessions[2];

            // Confirm status and end date are not set to begin with
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, testSession1.Status.Id);
            Assert.IsNull(testSession1.EndDate);
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, testSession2.Status.Id);
            Assert.IsNull(testSession2.EndDate);
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, testSession3.Status.Id);
            Assert.IsNull(testSession3.EndDate);

            // Create a new client witness signatory for the test session's equipment organisation
            Signatory clientWitnessSignatory;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                clientWitnessSignatory = new TestSessionClientWitnessSignatory(_employeeServices, _organisationServices).TestWitnessSignatory();
                clientWitnessSignatory.Organisation = testSession3.Equipment.Branch.Organisation;

                session.SaveOrUpdate(clientWitnessSignatory);
                session.Flush();

                // Add client witness signatory to the list of persisted client witness signatories
                // so we can remove it when we have finished
                _clientWitnessSignatories.Add(clientWitnessSignatory);

                session.Flush();
            }

            // Give each test session a different type of signatory
            testSession1.MardixSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession2.MardixWitnessSignatory = new Engineer(_employeeServices).RandomEngineer();
            testSession3.ClientWitnessSignatory = clientWitnessSignatory;
            testSession1.Result = _resultServices.Single(TestResult.Results.Pass.Id);
            testSession2.Result = _resultServices.Single(TestResult.Results.Pass.Id);
            testSession3.Result = _resultServices.Single(TestResult.Results.Pass.Id);

            // Update test sessions
            var putResponse1 = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession1.Id).WithResource(ToDtoWrite(testSession1)).ExecuteUpdateDelete();
            var putResponse2 = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession2.Id).WithResource(ToDtoWrite(testSession2)).ExecuteUpdateDelete();
            var putResponse3 = ApiBuilder.PutRequest(BearerToken).ForTestSessions(testSession3.Id).WithResource(ToDtoWrite(testSession3)).ExecuteUpdateDelete();

            Assert.AreEqual(HttpStatusCode.OK, putResponse1.StatusCode);
            Assert.AreEqual(HttpStatusCode.OK, putResponse2.StatusCode);
            Assert.AreEqual(HttpStatusCode.OK, putResponse3.StatusCode);

            // Get test session data following update
            TestSession updatedTestSession1;
            TestSession updatedTestSession2;
            TestSession updatedTestSession3;
            using (var session = ConfigurationProviderSqlServer.SessionFactory.OpenSession())
            {
                updatedTestSession1 = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession1.Id);
                updatedTestSession2 = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession2.Id);
                updatedTestSession3 = session.Query<TestSession>().FirstOrDefault(t => t.Id == testSession3.Id);
                if (updatedTestSession1 == null || updatedTestSession2 == null || updatedTestSession3 == null) throw new Exception("Expected data not found in database");
            }

            // Confirm the test sessions have not had their statuses or end dates set
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession1.Status.Id);
            Assert.IsNull(updatedTestSession1.EndDate);
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession2.Status.Id);
            Assert.IsNull(updatedTestSession2.EndDate);
            Assert.AreNotEqual(TestSessionStatus.Statuses.Completed.Id, updatedTestSession3.Status.Id);
            Assert.IsNull(updatedTestSession3.EndDate);
        }
    }
}