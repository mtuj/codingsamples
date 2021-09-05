using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.Mail;
using Common.Extensions;
using Common.Utilities;
using iTextSharp.text.pdf;
using NHibernate;
using NHibernate.Criterion;
using NHibernate.Linq;
using NHibernate.Transform;
using Vision.Api.DotNet.ApplicationServices.CommissionStatuses;
using Vision.Api.DotNet.ApplicationServices.Documents;
using Vision.Api.DotNet.ApplicationServices.DocumentTypes;
using Vision.Api.DotNet.ApplicationServices.Emails;
using Vision.Api.DotNet.ApplicationServices.Employees;
using Vision.Api.DotNet.ApplicationServices.Equipments;
using Vision.Api.DotNet.ApplicationServices.Extensions;
using Vision.Api.DotNet.ApplicationServices.FileSystem;
using Vision.Api.DotNet.ApplicationServices.SiteVisitReports;
using Vision.Api.DotNet.Common.Configuration;
using Vision.Api.DotNet.Common.Exceptions;
using Vision.Api.DotNet.Domain.Documents;
using Vision.Api.DotNet.Domain.Equipments;
using Vision.Api.DotNet.Domain.Filtering;
using Vision.Api.DotNet.Domain.Paging;
using Vision.Api.DotNet.Domain.Production;
using Vision.Api.DotNet.Domain.Qmfs;
using Vision.Api.DotNet.Domain.TestDocuments;
using Vision.Api.DotNet.Domain.WorksOrders;
using Attachment = Vision.Api.DotNet.Domain.Emails.Attachment;
using ProductionStage = Vision.Api.DotNet.Types.ProductionStage;
using ProductionStep = Vision.Api.DotNet.Domain.Production.ProductionStep;
using TestSessionStatus = Vision.Api.DotNet.Domain.TestDocuments.TestSessionStatus;
using TestSessionType = Vision.Api.DotNet.Domain.TestDocuments.TestSessionType;

namespace Vision.Api.DotNet.ApplicationServices.TestDocuments
{

    /// <summary>
    /// Test session application services
    /// </summary>
    public class TestSessionServices : ServicesBase, ITestSessionServices
    {
        private readonly IConfigurationManager _configurationManager;
        private readonly ITestServices _testServices;
        private readonly IEquipmentServices _equipmentServices;
        private readonly IEmployeeServices _employeeServices;
        private readonly ISiteVisitReportSignatoryServices _siteVisitReportSignatoryServices;
        private readonly IDocumentServices _documentServices;
        private readonly IDocumentTypeServices _documentTypeServices;
        private readonly ITestSessionStatusServices _testSessionStatusServices;
        private readonly ITestDocumentTemplateServices _testDocumentTemplateServices;
        private readonly IEmailServices _emailServices;
        private readonly IFileSystemServices _fileSystemServices;
        private readonly ITestSessionTypeServices _testSessionTypeServices;
        private readonly ITestSessionLocationServices _testSessionLocationServices;
        private readonly IElectricalSupplySystemServices _electricalSupplySystemServices;
        private readonly ICheckOutcomeServices _checkOutcomeServices;
        private readonly IResultServices _resultServices;
        private readonly ICommissionStatusServices _commissionStatusServices;
        private readonly PropertyProjection _defaultOrderBy = Projections.Property<TestSession>(ts => ts.StartDate);

        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="servicesContext">The services context</param>
        /// <param name="configurationManager">The configuration manager</param>
        /// <param name="testServices">The test services</param>
        /// <param name="equipmentServices">The equipment services</param>
        /// <param name="employeeServices">The employee services</param>
        /// <param name="siteVisitReportSignatory">The site visit report signatory services</param>
        /// <param name="document">The document services</param>
        /// <param name="documentTypeServices">The document type services</param>
        /// <param name="testSessionStatusServices">The test session status services</param>
        /// <param name="testDocumentTemplate">The test document template services</param>
        /// <param name="emailServices">The e-mail services</param>
        /// <param name="fileSystemServices">The file system services</param>
        /// <param name="testSessionTypeServices">The test session type services</param>
        /// <param name="testSessionLocationServices">The test session location services</param>
        /// <param name="electricalSupplySystemServices">The electrical supply system services</param>
        /// <param name="checkOutcomeServices">The check outcome services</param>
        /// <param name="resultServices">The result services</param>
        /// <param name="commissionStatusServices">The commission status services</param>
        public TestSessionServices(IServicesContext servicesContext, IConfigurationManager configurationManager, ITestServices testServices, IEquipmentServices equipmentServices, IEmployeeServices employeeServices, ISiteVisitReportSignatoryServices siteVisitReportSignatoryServices, IDocumentServices documentServices, IDocumentTypeServices documentTypeServices, ITestSessionStatusServices testSessionStatusServices, ITestDocumentTemplateServices testDocumentTemplateServices, IEmailServices emailServices, IFileSystemServices fileSystemServices, ITestSessionTypeServices testSessionTypeServices, ITestSessionLocationServices testSessionLocationServices, IElectricalSupplySystemServices electricalSupplySystemServices, ICheckOutcomeServices checkOutcomeServices, IResultServices resultServices, ICommissionStatusServices commissionStatusServices)
            : base(servicesContext)
        {
            _testServices = testServices;
            _equipmentServices = equipmentServices;
            _employeeServices = employeeServices;
            _siteVisitReportSignatoryServices = siteVisitReportSignatoryServices;
            _documentServices = documentServices;
            _documentTypeServices = documentTypeServices;
            _testSessionStatusServices = testSessionStatusServices;
            _testDocumentTemplateServices = testDocumentTemplateServices;
            _emailServices = emailServices;
            _fileSystemServices = fileSystemServices;
            _configurationManager = configurationManager;
            _testSessionTypeServices = testSessionTypeServices;
            _testSessionLocationServices = testSessionLocationServices;
            _electricalSupplySystemServices = electricalSupplySystemServices;
            _checkOutcomeServices = checkOutcomeServices;
            _resultServices = resultServices;
            _commissionStatusServices = commissionStatusServices;
        }

        public static class FormFields
        {
            public const string AhfRatingUppercase = "AHF RATING";
            public const string AhfSerialNoUppercase = "AHF SERIAL NO";
            public const string Engineers = "Engineers";
            public const string Equipment = "Equipment";
            public const string EquipmentUppercase = "EQUIPMENT";
            public const string EquipmentRating = "Equipment Rating";
            public const string EquipmentSerialNumber = "Equipment Serial Number";
            public const string InstallationReference = "Installation Reference";
            public const string JobNoUppercase = "JOB NO";
            public const string JobNumber = "Job Number";
            public const string PanelLocation = "Panel Location";
            public const string PanelRef = "Panel Ref";
            public const string PanelReference = "Panel Reference";
            public const string PanelReferenceUppercase = "PANEL REFERENCE";
            public const string PartNoUppercase = "PART NO";
            public const string Project = "Project";
            public const string ProjectUppercase = "PROJECT";
            public const string SerialNumber = "Serial Number";
            public const string ServiceTagNoUppercase = "SERVICE TAG NO";
            public const string ServiceTagNumber = "Service Tag Number";
            public const string SiteAddress = "Site Address";
            public const string StsRatingUppercase = "STS RATING";
            public const string StsSerialNoUppercase = "STS SERIAL NO";
            public const string TxRatingUppercase = "TX RATING";
            public const string TxSerialNoUppercase = "TX SERIAL NO";
            public const string UnitRatingUppercase = "UNIT RATING";
            public const string UnitRef = "Unit Ref";
            public const string UnitReferenceUppercase = "UNIT REFERENCE";
            public const string UnitSerialNo = "Unit Serial No";
            public const string UnitSerialNoUppercase = "UNIT SERIAL NO";
            public const string WoNumber = "WO Number";
        }

        /// <summary>
        /// Returns all <see cref="IEnumerable{TestSession}">TestSessions</see>
        /// </summary>
        /// <returns>The TestSessions</returns>
        public IList<TestSession> All()
        {
            return CoreQueryOver<TestSession>()
                .ExecuteWithOrdering(ServicesContext, _defaultOrderBy)
                .ToList();
        }

        /// <summary>
        /// <para>Gets a <see cref="PagedData{T}">paged list of all production schedule items</see> in the system within the current context</para>
        /// </summary>
        /// <param name="skip">The number of records to skip</param>
        /// <param name="top">The number of records to return</param>
        /// <returns>The requested page of <see cref="TestSession"/>s</returns>
        public PagedData<TestSession> All(int skip, int top)
        {
            var pagedData = CoreQueryOver<TestSession>()
                .ExecuteWithPaging(skip, top, ServicesContext, _defaultOrderBy, CoreQueryOver<TestSession>());
            return pagedData;
        }

        /// <summary>
        /// Returns a <see cref="TestSession"/> for the supplied <paramref name="id">id</paramref>
        /// </summary>
        /// <param name="id">The Id of the TestSession</param>
        /// <returns>The TestSession</returns>
        public TestSession Single(Guid id)
        {
            return CoreQueryOver<TestSession>().Where(ts => ts.Id == id).SingleOrDefault();
        }

        /// <summary>
        /// <para>Gets the page number on which the record identified by its <paramref name="id"/> will appear</para>
        /// </summary>
        /// <param name="id">The id of the record</param>
        /// <param name="pageSize">The page size</param>
        /// <returns>The page number on which the record will appear</returns>
        public PageInformation PageInformation(Guid id, int pageSize)
        {
            return CalculatePageInformation<TestSession>(id, pageSize, _defaultOrderBy);
        }

        /// <summary>
        /// Gets the options which the test sessions can be filtered on
        /// </summary>
        /// <returns>The filter options</returns>
        public IList<FilterOptions> FilterOptions()
        {
            // Equipment
            Equipment equipmentAlias = null;
            var equipmentFilterOptions = new FilterOptions
            {
                Property = TypeExtensions.GetPropertyNameWithParentPropertyNames<TestSession>(ts => ts.Equipment.Id),
                Options = CoreQueryOver<TestSession>()
                    .JoinAlias(ts => ts.Equipment, () => equipmentAlias)
                    .Select(Projections.ProjectionList()
                        .Add(Projections.Distinct(Projections.Cast(NHibernateUtil.String, Projections.Property(() => equipmentAlias.Id))), "Value")
                        .Add(Projections.Cast(NHibernateUtil.String, Projections.Property(() => equipmentAlias.ServiceTagNumber)), "Display"))  // Cast to String needed as this is an Int64
                    .TransformUsing(Transformers.AliasToBean<FilterOption>())
                    .ExecuteProjectionList(ServicesContext)
                    .OrderBy(e => e.Display)
                    .ToList()
            };

            // Test Session Type
            TestSessionType testSessionTypeAlias = null;
            var testSessionTypeFilterOptions = new FilterOptions
            {
                Property = TypeExtensions.GetPropertyNameWithParentPropertyNames<TestSession>(ts => ts.TestSessionType.Id),
                Options = CoreQueryOver<TestSession>()
                    .JoinAlias(ts => ts.TestSessionType, () => testSessionTypeAlias)
                    .Select(Projections.ProjectionList()
                        .Add(Projections.Distinct(Projections.Cast(NHibernateUtil.String, Projections.Property(() => testSessionTypeAlias.Id))), "Value")
                        .Add(Projections.Property(() => testSessionTypeAlias.Name), "Display"))
                    .TransformUsing(Transformers.AliasToBean<FilterOption>())
                    .ExecuteProjectionList(ServicesContext)
                    .OrderBy(e => e.Display)
                    .ToList()
            };

            // Test Session Status
            TestSessionStatus testSessionStatusAlias = null;
            var testSessionStatusFilterOptions = new FilterOptions
            {
                Property = TypeExtensions.GetPropertyNameWithParentPropertyNames<TestSession>(ts => ts.Status.Id),
                Options = CoreQueryOver<TestSession>()
                    .JoinAlias(ts => ts.Status, () => testSessionStatusAlias)
                    .Select(Projections.ProjectionList()
                        .Add(Projections.Distinct(Projections.Cast(NHibernateUtil.String, Projections.Property(() => testSessionStatusAlias.Id))), "Value")
                        .Add(Projections.Property(() => testSessionStatusAlias.Name), "Display"))
                    .TransformUsing(Transformers.AliasToBean<FilterOption>())
                    .ExecuteProjectionList(ServicesContext)
                    .OrderBy(e => e.Display)
                    .ToList()
            };

            return new List<FilterOptions> { equipmentFilterOptions, testSessionTypeFilterOptions, testSessionStatusFilterOptions };
        }

        /// <summary>
        /// <para>Updates the <see cref="TestSession"/> with the specified <param name="entityId">id</param> using the supplied <param name="entityId">Test dto object</param></para>
        /// </summary>
        /// <param name="entity">The test session to be persisted</param>
        /// <param name="entityId">The id of the <see cref="TestSession"/> to be updated</param>
        /// <param name="conflict">Flag to indicate whether a source device conflict was detected when attempting to save the test session</param>
        /// <returns>The persisted <see cref="TestSession"/></returns>
        public TestSession CreateOrUpdate(Guid entityId, Dto.Write.TestDocuments.TestSession entity, out bool conflict)
        {
            TestSession testSession = null;

            var originalTestSession = Single(entityId);
            var originalTestSessionStatusId = (originalTestSession != null && originalTestSession.Status != null) ? originalTestSession.Status.Id : Types.TestSessionStatus.Statuses.NotStarted.Id;
            var originalTestSessionEndDate = (originalTestSession != null && originalTestSession.EndDate != null) ? originalTestSession.EndDate : null;

            if (entityId != Guid.Empty)
            {
                testSession = Single(entityId);
            }
            
            var isNew = testSession == null;
            if (isNew)
            {
                testSession = new TestSession();
                if (entityId != Guid.Empty) testSession.Id = entityId;
            }
            else
            {
                // If this is an existing record, and the existing device id is from another device, return the original record and set the conflict parameter
                conflict = (!string.IsNullOrWhiteSpace(testSession.LastDeviceUsed) && testSession.LastDeviceUsed != entity.LastDeviceUsed);
                if (conflict)
                    return testSession;
            }
            
            conflict = false;
            var statusNotStarted = _testSessionStatusServices.Single(Types.TestSessionStatus.Statuses.NotStarted.Id);
            var statusCompleted = _testSessionStatusServices.Single(Types.TestSessionStatus.Statuses.Completed.Id);
            var statusAbandoned = _testSessionStatusServices.Single(Types.TestSessionStatus.Statuses.Abandoned.Id);

            // Get the test session property domain objects
            var equipment = entity.EquipmentId != null ? _equipmentServices.Single((long)entity.EquipmentId) : null;
            var branch = equipment != null && equipment.Branch != null 
                ? equipment.Branch 
                : equipment != null && equipment.ParentEquipment != null && equipment.ParentEquipment.Branch != null 
                    ? equipment.ParentEquipment.Branch 
                    : null;

            var barStandard = equipment != null && equipment.ParentEquipment != null 
                                ? equipment.ParentEquipment.Qmf.BarStandard 
                                : equipment != null 
                                    ? equipment.Qmf.BarStandard 
                                    : null;

            var tester = entity.TesterId != null ? _employeeServices.Single((int)entity.TesterId) : null;
            var testSessionType = entity.TestSessionTypeId != null ? _testSessionTypeServices.Single((Guid)entity.TestSessionTypeId) : null;
            var testSessionLocation = entity.TestSessionLocationId != null ? _testSessionLocationServices.Single((Guid)entity.TestSessionLocationId) : null;
            var electricalsupplysystem = entity.ElectricalSupplySystemId != null ? _electricalSupplySystemServices.Single((Guid)entity.ElectricalSupplySystemId) : null;
            var tripUnitCheckOutcome = entity.TripUnitCheckOutcomeId != null ? _checkOutcomeServices.Single((Guid)entity.TripUnitCheckOutcomeId) : null;
            var mardixSignatory = entity.MardixSignatoryId != null ? _employeeServices.Single((int)entity.MardixSignatoryId) : null;
            var mardixWitnessSignatory = entity.MardixWitnessSignatoryId != null ? _employeeServices.Single((int)entity.MardixWitnessSignatoryId) : null;
            var clientWitnessSignatory = entity.ClientWitnessSignatoryEmail != null && branch != null ? _siteVisitReportSignatoryServices.ByOrganisationIdAndEmail(branch.Organisation.Id, entity.ClientWitnessSignatoryEmail) : null;
            var status = entity.MardixSignatoryId != null && (!testSessionType.RequiresWitness || entity.MardixWitnessSignatoryId != null || entity.ClientWitnessSignatoryEmail != null) && entity.StatusId != Types.TestSessionStatus.Statuses.Abandoned.Id
                ? statusCompleted
                : entity.StatusId != null
                    ? _testSessionStatusServices.Single((Guid)entity.StatusId) 
                    : statusNotStarted;
            var result = entity.ResultId != null ? _resultServices.Single((Guid)entity.ResultId) : null;
            var worksOrder = equipment != null && equipment.WorksOrder != null
                ? equipment.WorksOrder
                : equipment != null && equipment.ParentEquipment != null && equipment.ParentEquipment.WorksOrder != null
                    ? equipment.ParentEquipment.WorksOrder
                    : null;
            var m0 = equipment != null && !string.IsNullOrWhiteSpace(equipment.M0)
                ? equipment.M0
                : equipment != null && equipment.ParentEquipment != null
                    ? equipment.ParentEquipment.M0
                    : null;

            // Set the test session properties
            testSession.TestSessionType = testSessionType;
            testSession.Equipment = equipment;
            testSession.Tester = tester;
            testSession.LastDeviceUsed = entity.LastDeviceUsed;
            testSession.StartDate = entity.StartDate;
            testSession.EndDate = entity.MardixSignatoryId != null && ((testSession.TestSessionType != null && !testSession.TestSessionType.RequiresWitness) || entity.MardixWitnessSignatoryId != null || entity.ClientWitnessSignatoryEmail != null)
                ? entity.EndDate == null && originalTestSessionEndDate == null
                    ? SystemTime.UtcNow()
                    : entity.EndDate ?? originalTestSessionEndDate
                : null;
            testSession.TestSessionLocation = testSessionLocation;
            testSession.ElectricalSupplySystem = electricalsupplysystem;
            testSession.TripUnitCheckOutcome = tripUnitCheckOutcome;
            testSession.Comments = entity.Comments;
            testSession.TestedToGeneralArrangementDrawingRevision = entity.TestedToGeneralArrangementDrawingRevision;
            testSession.TestedToElectricalSchematicDrawingRevision = entity.TestedToElectricalSchematicDrawingRevision;
            testSession.MardixSignatory = mardixSignatory;
            testSession.MardixSignOffDate = entity.MardixSignOffDate;
            testSession.MardixWitnessSignatory = mardixWitnessSignatory;
            testSession.ClientWitnessSignatory = clientWitnessSignatory;
            testSession.WitnessSignOffDate = entity.WitnessSignOffDate;
            testSession.Status = status;
            testSession.Result = result;
            testSession.TXSerialNo = entity.TXSerialNo;
            testSession.STSSerialNo = entity.STSSerialNo;
            testSession.AHFSerialNo = entity.AHFSerialNo;
            testSession.UnitRating = entity.UnitRating;
            testSession.TXRating = entity.TXRating;
            testSession.STSRating = entity.STSRating;
            testSession.AHFRating = entity.AHFRating;

            if (isNew)
                CurrentSession.Save(testSession);
            else
                CurrentSession.SaveOrUpdate(testSession);

            // Ensure test session has all required tests, and test documents
            _testServices.AddAllTestsToTestSession(testSession);

            // Persist core documents
            if (entity.CoreDocuments != null)
            {
                foreach (var documentWrite in entity.CoreDocuments)
                {
                    var existingDocument = testSession.Documents.FirstOrDefault(d => d.Type.Id == documentWrite.TypeId);

                    if (existingDocument != null)
                    {
                        // If a document already exists for this test session and document type, just update the document
                        // This is the convention for all core documents, such as master document and signatures
                        documentWrite.FileName = existingDocument.LatestRevision.FileName;
                        documentWrite.MimeType = existingDocument.LatestRevision.MimeType;
                        _documentServices.CreateOrUpdate(existingDocument.Id, documentWrite);
                    }
                    else
                    {
                        // If no document exists for this test session and document type, generate a new document and association

                        // Document services creates document
                        var document = _documentServices.Create(documentWrite);

                        // Add document to test session's documents collection
                        testSession.Documents.Add(document);
                    }
                }
            }

            // Ensure the required master document is included in either the test session's own documents collections, or any of its tests
            foreach (var documentWrite in GenerateTestSessionDocuments(testSession, worksOrder.WoNumber, m0, new[] { testSession.TestSessionType.MasterDocumentType.Id }, barStandard))
            {
                // Document services creates document
                var document = _documentServices.Create(documentWrite);
                testSession.Documents.Add(document);
            }

            // Persist the IBAR installation test metadata.
            if (entity.IbarInstallationTestMetadatas != null && entity.StatusId != Types.TestSessionStatus.Statuses.Abandoned.Id)
            {
                foreach (var ibarInstallationTestMetadata in entity.IbarInstallationTestMetadatas)  // There should actually only be one.
                {
                    UpdateIbarInstallationTestMetadata(ibarInstallationTestMetadata);
                }
            }

            // Persist the IBAR installation joint test metadata.
            if (entity.IbarInstallationJointTestMetadatas != null && entity.StatusId != Types.TestSessionStatus.Statuses.Abandoned.Id)
            {
                foreach (var ibarInstallationJointTestMetadata in entity.IbarInstallationJointTestMetadatas)  // There should actually only be one.
                {
                    UpdateIbarInstallationJointTestMetadata(ibarInstallationJointTestMetadata);
                }
            }

            // Persist test session to update document associations
            CurrentSession.SaveOrUpdate(testSession);

            // Refresh the test session domain object
            testSession = Single(testSession.Id);

            // If the test session is set as Completed, save the documents to the network then e-mail them to the tester
            if (testSession.Status.Id == statusCompleted.Id)
            {
                // Set the signatory fields and annotate the photo and signature images to all master documents and test session documents
                var masterDocuments = GetMasterDocuments(testSession);
                foreach (var masterDocument in masterDocuments)
                {
                    AddTestSessionPhotoToDocument(masterDocument, testSession);
                    SetSignatoriesInDocument(masterDocument, testSession);
                    AddSignaturesToDocument(masterDocument, testSession);
                }
                foreach (var document in testSession.Documents.Where(d => d.Type.Category != null && d.Type.Category.Id == Types.DocumentTypeCategory.Categories.TestSessionDocument.Id))
                {
                    AddTestSessionPhotoToDocument(document, testSession);
                    SetSignatoriesInDocument(document, testSession);
                    AddSignaturesToDocument(document, testSession);
                }

                // Save the documents and get the network file path that they have been saved to
                var filePath = SaveTestSessionDocumentsToNetwork(testSession.Id);

                // E-mail the documents to the tester, including details of the network location they have also been saved to
                if (testSession.MardixSignatory != null && testSession.MardixSignatory.Email != null)
                    EmailTestSession(testSession, filePath, testSession.MardixSignatory.Email);
            }

            // Additional check for completed test sessions with no associated document on the network
            if (testSession.Status.Id == statusCompleted.Id && !_fileSystemServices.FileExists(
                ScannedDocumentNetworkFilePath(testSession),
                _configurationManager.FileSystem.CredentialsDomain,
                _configurationManager.FileSystem.CredentialsUsername,
                _configurationManager.FileSystem.CredentialsPassword
                ))
            {
                EmailTestSessionMissingNetworkFileReport(testSession);
            }

            CurrentSession.Flush();

            // Update build status if applicable to test session type
            if (testSession.TestSessionType.UpdateBuildStatusDuringTest)
            {
                UpdateBuildStatus(testSession, originalTestSessionStatusId, entity.BuildLocationId);
            }

            if (testSession.TestSessionType.UpdateCommissioningStatusDuringTest)
            {
                // Update commission status if applicable to test session type
                UpdateCommissionStatus(testSession, originalTestSessionStatusId);
            }

            // Return the updated test session
            return Single(testSession.Id);
        }

        /// <summary>
        /// Returns the network file path of the composite document for the test session
        /// </summary>
        /// <param name="id">The id of the <see cref="TestSession"/> to get the network file path for</param>
        /// <returns>The network file path of the composite document for the test session</returns>
        public string ScannedDocumentNetworkFilePath(Guid id)
        {
            var testSession = Single(id);
            if (testSession == null) 
                return null;

            if (_fileSystemServices.FileExists(
                ScannedDocumentNetworkFilePath(testSession),
                _configurationManager.FileSystem.CredentialsDomain,
                _configurationManager.FileSystem.CredentialsUsername,
                _configurationManager.FileSystem.CredentialsPassword
                ))
            {
                return ScannedDocumentNetworkFilePath(testSession);
            }

            return ScannedDocumentNetworkFilePath(testSession, true);
        }

        /// <summary>
        /// Creates a list of writeable dto documents for any of the specified test document template types, if they do not already exist for the test session
        /// </summary>
        /// <param name="testSession">The test session</param>
        /// <param name="woNumber">The works order number to get the template for (can be null if not specific to a works order)</param>
        /// <param name="m0">The M0 to get the template for (can be null if not specific to an M0)</param>
        /// <param name="documentTypeIds">The collection of document type ids to test for</param>
        /// <param name="barStandard">The bar standard of the equipment we are creating the test session documents for.</param>
        /// <returns>A list of writeable dto documents for any of the missing specified test document template types</returns>
        private IEnumerable<Dto.Write.Documents.Document> GenerateTestSessionDocuments(TestSession testSession, int? woNumber, string m0, IEnumerable<Guid> documentTypeIds, BarStandard barStandard)
        {
            var documents = new List<Dto.Write.Documents.Document>();

            foreach (var documentTypeId in documentTypeIds)
            {
                // Test for existence of the specified document type, in either the test session's own documents collections, or any of its tests
                var domainDocument = testSession.Documents.FirstOrDefault(d => d.Type.Id == documentTypeId) ??
                            testSession.Tests.Select(t => t.Document).FirstOrDefault(d => d != null && d.Type != null && d.Type.Id == documentTypeId);

                // If no document of the specified type exists, create one
                if (domainDocument == null)
                {
                    // Get the test document template type
                    var testDocumentType = _documentTypeServices.Single(documentTypeId);
                    var testDocumentTemplateType = CurrentSession.Query<Domain.Documents.Type>().FirstOrDefault(
                        t => t.Name == testDocumentType.Name &&
                        t.QualityManagementSystemCode == testDocumentType.QualityManagementSystemCode &&
                        t.Category.Id == Types.DocumentTypeCategory.Categories.TestDocumentTemplate.Id
                        );
                    if (testDocumentTemplateType == null)
                        throw new EntityNotFoundException();
                    
                    // Get the test document template for the specified document type
                    var testDocumentTemplates = _testDocumentTemplateServices.FilteredTestDocumentTemplates(testDocumentTemplateType.Id, woNumber, m0, barStandard);
                    // No direct matches so look for a generic template
                    if (testDocumentTemplates.Count == 0)
                        testDocumentTemplates = _testDocumentTemplateServices.FilteredTestDocumentTemplates(testDocumentTemplateType.Id, null, null, barStandard);
                    // There may be multiple document revisions, so get the most recent document only
                    var testDocumentTemplate = testDocumentTemplates.OrderByDescending(tdt => tdt.Document.LatestRevision.CreatedDateUtc).FirstOrDefault();

                    // We now create the Document object to give the test
                    if (testDocumentTemplate != null)
                    {
                        // This is a new Document, and is basically a copy of the template document
                        var templateDocument = testDocumentTemplate.Document;
                        var document = new Dto.Write.Documents.Document
                        {
                            TypeId = documentTypeId,
                            Description = Path.GetFileNameWithoutExtension(templateDocument.LatestRevision.FileName),
                            FileName = templateDocument.LatestRevision.FileName,
                            MimeType = templateDocument.LatestRevision.MimeType,
                            Revision = "1",
                            PublishedDateUtc = SystemTime.UtcNow(),
                            DocumentContent = Convert.ToBase64String(templateDocument.LatestRevision.Content.Content)
                        };

                        // Add the new document to the test session's Documents collection
                        documents.Add(document);
                    }
                }
            }

            return documents;
        }

        /// <summary>
        /// Saves the supplied <paramref name="ibarInstallationTestMetadataDto"/>.
        /// </summary>
        /// <param name="ibarInstallationTestMetadataDto">The Dto object.</param>
        private void UpdateIbarInstallationTestMetadata(Dto.Write.TestDocuments.IbarInstallationTestMetadata ibarInstallationTestMetadataDto)
        {
            // Get the IBAR Installation Test metadata that already exists for the associated test session, if any exists.
            // There should only be one for each test session, so this should be a safe query to use.
            // In addition, the metadata object is synced up as a child component of the test session, and does not supply an Id to query directly.
            var ibarInstallationTestMetadata = CurrentSession.Query<IbarInstallationTestMetadata>()
                .FirstOrDefault(e => e.TestSession.Id == ibarInstallationTestMetadataDto.TestSessionId);

            // Get the associated domain objects.
            var testSession = Single(ibarInstallationTestMetadataDto.TestSessionId);
            var document = _documentServices.Single(ibarInstallationTestMetadataDto.DocumentId);

            // A small convention-based catch here.
            // Mostly, the document Id contained in the Dto will be the correct one, as the tests are formed on the server at the time of the test sesion being created.
            // As such, when a test's document is synced up from the app, it does not include the Id as this is already known.
            // However, in the rare case of a duplicate test session caused by conflicts in the pre-activation cycle, the document is recreated for the duplicate test session
            // with a new Id; however in this case the Id sent up will be different to that for the actual synced document, which in that scenario gets created from scratch.
            // In this rare case, we simply obtain the document of the first test, which by convention will be the correct one.
            if (document == null)
                document = testSession.Tests.First().Document;

            // If there is currently no associated IBAR Installation Test Metadata object, create a new one.
            if (ibarInstallationTestMetadata == null)
            {
                ibarInstallationTestMetadata = new IbarInstallationTestMetadata
                {
                    TestSession = testSession,
                    Document = document
                };

                // Save the IBAR Installation Test Metadata object.
                CurrentSession.Save(ibarInstallationTestMetadata);
                CurrentSession.Flush();
            }

            // Update the IBAR Installation Test Metadata object.

            ibarInstallationTestMetadata.AdjoiningSectionsLevel = ibarInstallationTestMetadataDto.AdjoiningSectionsLevel;
            ibarInstallationTestMetadata.SupportBracketsInstalled = ibarInstallationTestMetadataDto.SupportBracketsInstalled;
            ibarInstallationTestMetadata.SupportBracketsFixingBoltsSecure = ibarInstallationTestMetadataDto.SupportBracketsFixingBoltsSecure;
            ibarInstallationTestMetadata.JointsInstalled = ibarInstallationTestMetadataDto.JointsInstalled;
            ibarInstallationTestMetadata.CoversSecurelyInstalled = ibarInstallationTestMetadataDto.CoversSecurelyInstalled;

            ibarInstallationTestMetadata.DuctorTestInstrumentIdNumber = ibarInstallationTestMetadataDto.DuctorTestInstrumentIdNumber;

            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsPEToE = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsPEToE;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsPEToN = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsPEToN;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsPEToL1 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsPEToL1;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsPEToL2 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsPEToL2;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsPEToL3 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsPEToL3;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsEToN = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsEToN;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsEToL1 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsEToL1;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsEToL2 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsEToL2;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsEToL3 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsEToL3;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsNToL1 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsNToL1;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsNToL2 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsNToL2;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsNToL3 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsNToL3;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsL1ToL2 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsL1ToL2;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsL2ToL3 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsL2ToL3;
            ibarInstallationTestMetadata.InsulationResistanceTestResultMegaOhmsL3ToL1 = ibarInstallationTestMetadataDto.InsulationResistanceTestResultMegaOhmsL3ToL1;

            ibarInstallationTestMetadata.InsulationResistanceTestInstrumentIdNumber = ibarInstallationTestMetadataDto.InsulationResistanceTestInstrumentIdNumber;

            ibarInstallationTestMetadata.Comments = ibarInstallationTestMetadataDto.Comments;

            CurrentSession.SaveOrUpdate(ibarInstallationTestMetadata);

            // Delete any IBAR Installation Test Metadata Continuity Run Ductor Test objects.
            // We always recreate these fresh, as the engineers could conceivably remove data from the associated document as well as add it.

            var ibarInstallationTestMetadataContinuityRunDuctorTests = CurrentSession.Query<IbarInstallationTestMetadataContinuityRunDuctorTest>()
            .Where(i => i.IbarInstallationTestMetadata.Id == ibarInstallationTestMetadata.Id)
            .ToList();

            ibarInstallationTestMetadataContinuityRunDuctorTests.ForEach(e => CurrentSession.Delete(e));
            CurrentSession.Flush();

            // Recreate the IBAR Installation Test Metadata Continuity Run Ductor Test objects.
            foreach (var ibarInstallationTestMetadataContinuityRunDuctorTestDto in ibarInstallationTestMetadataDto.ContinuityRunDuctorTests)
            {
                var ibarInstallationTestMetadataContinuityRunDuctorTest = new IbarInstallationTestMetadataContinuityRunDuctorTest
                {
                    IbarInstallationTestMetadata = ibarInstallationTestMetadata,
                    From = ibarInstallationTestMetadataContinuityRunDuctorTestDto.From,
                    To = ibarInstallationTestMetadataContinuityRunDuctorTestDto.To,
                    ConductorPair1 = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair1,
                    ConductorPair1LinkMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair1LinkMilliOhms,
                    ConductorPair1ResultMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair1ResultMilliOhms,
                    ConductorPair2 = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair2,
                    ConductorPair2LinkMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair2LinkMilliOhms,
                    ConductorPair2ResultMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair2ResultMilliOhms,
                    ConductorPair3 = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair3,
                    ConductorPair3LinkMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair3LinkMilliOhms,
                    ConductorPair3ResultMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair3ResultMilliOhms,
                    ConductorPair4 = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair4,
                    ConductorPair4LinkMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair4LinkMilliOhms,
                    ConductorPair4ResultMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair4ResultMilliOhms,
                    ConductorPair5 = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair5,
                    ConductorPair5LinkMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair5LinkMilliOhms,
                    ConductorPair5ResultMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair5ResultMilliOhms,
                    ConductorPair6 = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair6,
                    ConductorPair6LinkMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair6LinkMilliOhms,
                    ConductorPair6ResultMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair6ResultMilliOhms,
                    ConductorPair7 = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair7,
                    ConductorPair7LinkMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair7LinkMilliOhms,
                    ConductorPair7ResultMilliOhms = ibarInstallationTestMetadataContinuityRunDuctorTestDto.ConductorPair7ResultMilliOhms
                };

                // Save the IBAR Installation Test Metadata Continuity Run Ductor Test object.
                CurrentSession.Save(ibarInstallationTestMetadataContinuityRunDuctorTest);
            }

            CurrentSession.Flush();
        }

        /// <summary>
        /// Saves the supplied <paramref name="ibarInstallationJointTestMetadataDto"/>.
        /// </summary>
        /// <param name="ibarInstallationJointTestMetadataDto">The Dto object.</param>
        private void UpdateIbarInstallationJointTestMetadata(Dto.Write.TestDocuments.IbarInstallationJointTestMetadata ibarInstallationJointTestMetadataDto)
        {
            // Get the IBAR Installation Joint Test metadata that already exists for the associated test session, if any exists.
            // There should only be one for each test session, so this should be a safe query to use.
            // In addition, the metadata object is synced up as a child component of the test session, and does not supply an Id to query directly.
            var ibarInstallationJointTestMetadata = CurrentSession.Query<IbarInstallationJointTestMetadata>()
                .FirstOrDefault(e => e.TestSession.Id == ibarInstallationJointTestMetadataDto.TestSessionId);

            // Get the associated domain objects.
            var testSession = Single(ibarInstallationJointTestMetadataDto.TestSessionId);
            var document = _documentServices.Single(ibarInstallationJointTestMetadataDto.DocumentId);

            // A small convention-based catch here.
            // Mostly, the document Id contained in the Dto will be the correct one, as the tests are formed on the server at the time of the test sesion being created.
            // As such, when a test's document is synced up from the app, it does not include the Id as this is already known.
            // However, in the rare case of a duplicate test session caused by conflicts in the pre-activation cycle, the document is recreated for the duplicate test session
            // with a new Id; however in this case the Id sent up will be different to that for the actual synced document, which in that scenario gets created from scratch.
            // In this rare case, we simply obtain the document of the first test, which by convention will be the correct one.
            if (document == null)
                document = testSession.Tests.First().Document;

            // If there is currently no associated IBAR Installation Joint Test Metadata object, create a new one.
            if (ibarInstallationJointTestMetadata == null)
            {
                ibarInstallationJointTestMetadata = new IbarInstallationJointTestMetadata
                {
                    TestSession = testSession,
                    Document = document
                };

                // Save the IBAR Installation Joint Test Metadata object.
                CurrentSession.Save(ibarInstallationJointTestMetadata);
                CurrentSession.Flush();
            }

            // Update the IBAR Installation Joint Test Metadata object.

            ibarInstallationJointTestMetadata.BellevilleWashersSeated = ibarInstallationJointTestMetadataDto.BellevilleWashersSeated;
            ibarInstallationJointTestMetadata.NutOuterHeadsShearedOff = ibarInstallationJointTestMetadataDto.NutOuterHeadsShearedOff;
            ibarInstallationJointTestMetadata.NutsMarked = ibarInstallationJointTestMetadataDto.NutsMarked;
            ibarInstallationJointTestMetadata.CoversInstalled = ibarInstallationJointTestMetadataDto.CoversInstalled;
            ibarInstallationJointTestMetadata.BoltsTorqueChecked = ibarInstallationJointTestMetadataDto.BoltsTorqueChecked;
            ibarInstallationJointTestMetadata.TorqueWrenchIdNumber = ibarInstallationJointTestMetadataDto.TorqueWrenchIdNumber;
            ibarInstallationJointTestMetadata.DuctorResistanceMicroOhmsEarth = ibarInstallationJointTestMetadataDto.DuctorResistanceMicroOhmsEarth;
            ibarInstallationJointTestMetadata.DuctorResistanceMicroOhmsNeutral = ibarInstallationJointTestMetadataDto.DuctorResistanceMicroOhmsNeutral;
            ibarInstallationJointTestMetadata.DuctorResistanceMicroOhmsNeutral2 = ibarInstallationJointTestMetadataDto.DuctorResistanceMicroOhmsNeutral2;
            ibarInstallationJointTestMetadata.DuctorResistanceMicroOhmsPhaseL1= ibarInstallationJointTestMetadataDto.DuctorResistanceMicroOhmsPhaseL1;
            ibarInstallationJointTestMetadata.DuctorResistanceMicroOhmsPhaseL2 = ibarInstallationJointTestMetadataDto.DuctorResistanceMicroOhmsPhaseL2;
            ibarInstallationJointTestMetadata.DuctorResistanceMicroOhmsPhaseL3 = ibarInstallationJointTestMetadataDto.DuctorResistanceMicroOhmsPhaseL3;
            ibarInstallationJointTestMetadata.DuctorTestInstrumentIdNumber = ibarInstallationJointTestMetadataDto.DuctorTestInstrumentIdNumber;
            ibarInstallationJointTestMetadata.Comments = ibarInstallationJointTestMetadataDto.Comments;

            CurrentSession.SaveOrUpdate(ibarInstallationJointTestMetadata);
        }

        /// <summary>
        /// Generates an e-mail to the specified e-mail addresses containing the test session details
        /// </summary>
        /// <param name="testSession">The test session for which to generate the e-mail</param>
        /// <param name="filePath">The file path on the network where the files have also been stored</param>
        /// <param name="emailTo">The email address to send this test session to</param>
        private void EmailTestSession(TestSession testSession, string filePath, string emailTo)
        {
            var forComponent = testSession.Equipment.ParentEquipment != null;

            // Build up subject line
            var testSessionParentType = forComponent ? Globalisation.Emails.TestSessionParentTypeComponent : Globalisation.Emails.TestSessionParentTypeEquipment;
            var subject =
                Globalisation.Emails.TestSessionDetailsSubject
                    .Replace(EmailServices.PlaceHolders.TestSessionParentType, testSessionParentType)
                    .Replace(EmailServices.PlaceHolders.ServiceTagNumber, testSession.Equipment.ServiceTagNumber.ToString());

            // Build up subject body

            // Dates
            var startDate = testSession.StartDate != null
                                ? ((DateTime)testSession.StartDate).ToLocalTime().ToLongDateAndTimeString()
                                : string.Empty;
            var endDate = testSession.EndDate != null
                              ? ((DateTime)testSession.EndDate).ToLocalTime().ToLongDateAndTimeString()
                              : string.Empty;
            var testerSignOffDate = testSession.MardixSignOffDate != null
                                        ? ((DateTime)testSession.MardixSignOffDate).ToLocalTime().ToLongDateAndTimeString()
                                        : string.Empty;
            var witnessSignOffDate = testSession.WitnessSignOffDate != null
                                         ? ((DateTime)testSession.WitnessSignOffDate).ToLocalTime().ToLongDateAndTimeString()
                                         : string.Empty;

            // Signatory names
            var testerName = testSession.MardixSignatory != null ? string.Format("{0} {1}", testSession.MardixSignatory.FirstName, testSession.MardixSignatory.Surname) : string.Empty;
            var witnessName = testSession.MardixWitnessSignatory != null
                                  ? string.Format("{0} {1}", testSession.MardixWitnessSignatory.FirstName, testSession.MardixWitnessSignatory.Surname)
                                  : testSession.ClientWitnessSignatory != null
                                        ? testSession.ClientWitnessSignatory.FullName
                                        : string.Empty;

            // Construct body
            var serviceTagNumber = testSession.Equipment.ServiceTagNumber;
            var serialNumber = testSession.Equipment.SerialNumber;
            var equipmentType = testSession.Equipment.EquipmentType;
            var unitReference = testSession.Equipment.UnitReference;
            var unitDescription = testSession.Equipment.UnitDescription;
            var locationOnSite = testSession.Equipment.UnitLocation;
            var body = Globalisation.Emails.TestSessionDetailsCss;
            var worksOrder = testSession.Equipment.WorksOrder ?? (testSession.Equipment.ParentEquipment != null ? testSession.Equipment.ParentEquipment.WorksOrder : new WorksOrder());
            body += Globalisation.Emails.TestSessionDetailsBody.Replace(EmailServices.PlaceHolders.ProjectName,
                worksOrder.ProjectName)
                .Replace(EmailServices.PlaceHolders.ServiceTagNumber, serviceTagNumber.ToString())
                .Replace(EmailServices.PlaceHolders.SerialNumber, serialNumber)
                .Replace(EmailServices.PlaceHolders.EquipmentType, equipmentType.Name)
                .Replace(EmailServices.PlaceHolders.UnitReference, unitReference)
                .Replace(EmailServices.PlaceHolders.UnitDescription, unitDescription)
                .Replace(EmailServices.PlaceHolders.LocationOnSite, locationOnSite)
                .Replace(EmailServices.PlaceHolders.TestSessionType, testSession.TestSessionType.Name)
                .Replace(EmailServices.PlaceHolders.StartDate, startDate)
                .Replace(EmailServices.PlaceHolders.EndDate, endDate)
                .Replace(EmailServices.PlaceHolders.Result, testSession.Result.Name)
                .Replace(EmailServices.PlaceHolders.Comments, testSession.Comments)
                .Replace(EmailServices.PlaceHolders.TesterName, testerName)
                .Replace(EmailServices.PlaceHolders.TesterSignOffDateTime, testerSignOffDate)
                .Replace(EmailServices.PlaceHolders.WitnessName, witnessName)
                .Replace(EmailServices.PlaceHolders.WitnessSignOffDateTime, witnessSignOffDate);

			var attachments = new List<Attachment>();

            // Generate a composite document memory stream comprising all the documents from the test session
            // then add this as an attachment
            var combinedPdf = TestDocumentCombinedStream(testSession);

            if (combinedPdf != null)
            {
                // Move the stream position to the beginning
                combinedPdf.Seek(0, SeekOrigin.Begin);
	            var filename = string.Format("{0}.pdf", TestSessionBaseName(testSession));

	            var attachment = new Attachment
	            {
					FileName = filename,
					MimeType = System.Web.MimeMapping.GetMimeMapping(filename),
		            Content = combinedPdf.ToArray()
	            };

                // Attach document if file size is within email attachment limit
                var documentsAttached = string.Empty;
                if (attachment.Content.Length < _configurationManager.Smtp.MaximumAttachmentFileSizeBytes)
                {
                    attachments.Add(attachment);
                    documentsAttached += Globalisation.Emails.TestSessionDocumentsAttached;
                }

                // Documents attached / saved to network
                documentsAttached += (filePath == null)
                    ? Globalisation.Emails.TestSessionErrorSavingDocumentsToNetwork
                    : testSession.Documents.Count > 0
                        ? Globalisation.Emails.TestSessionDocumentsSavedTo.Replace(EmailServices.PlaceHolders.TestDocumentsFilePath, filePath)
                        : "";
                body = body.Replace(EmailServices.PlaceHolders.DocumentsAttached, documentsAttached);
            }

            try
            {
                // E-mail the test session details and document
                if (testSession.Documents != null && testSession.Documents.Count > 0)
					_emailServices.Send(emailTo, subject, body, attachments);
                else
                    _emailServices.Send(emailTo, subject, body);
            }
            catch (Exception ex)
            {
                throw new SmtpException(ex.Message);
            }
        }

        /// <summary>
        /// Generates an e-mail to report when a completed test session has no associated network document
        /// </summary>
        /// <param name="testSession">The test session for which to generate the e-mail</param>
        private void EmailTestSessionMissingNetworkFileReport(TestSession testSession)
        {
            var forComponent = testSession.Equipment.ParentEquipment != null;

            // Build up subject line
            var testSessionParentType = forComponent ? Globalisation.Emails.TestSessionParentTypeComponent : Globalisation.Emails.TestSessionParentTypeEquipment;
            var subject =
                Globalisation.Emails.TestSessionMissingNetworkFileReportSubject
                    .Replace(EmailServices.PlaceHolders.TestSessionParentType, testSessionParentType)
                    .Replace(EmailServices.PlaceHolders.ServiceTagNumber, testSession.Equipment.ServiceTagNumber.ToString());

            // Build up subject body

            // Dates
            var testerSignOffDate = testSession.MardixSignOffDate != null
                                        ? ((DateTime)testSession.MardixSignOffDate).ToLongDateAndTimeString()
                                        : string.Empty;
            var witnessSignOffDate = testSession.WitnessSignOffDate != null
                                         ? ((DateTime)testSession.WitnessSignOffDate).ToLongDateAndTimeString()
                                         : string.Empty;

            // Signatory names
            var testerName = testSession.MardixSignatory != null ? string.Format("{0} {1}", testSession.MardixSignatory.FirstName, testSession.MardixSignatory.Surname) : string.Empty;
            var witnessName = testSession.MardixWitnessSignatory != null
                                  ? string.Format("{0} {1}", testSession.MardixWitnessSignatory.FirstName, testSession.MardixWitnessSignatory.Surname)
                                  : testSession.ClientWitnessSignatory != null
                                        ? testSession.ClientWitnessSignatory.FullName
                                        : string.Empty;

            // Construct body
            var serviceTagNumber = testSession.Equipment.ServiceTagNumber;
            var serialNumber = testSession.Equipment.SerialNumber;
            var equipmentType = testSession.Equipment.EquipmentType;
            var unitReference = testSession.Equipment.UnitReference;
            var worksOrder = testSession.Equipment.WorksOrder ?? (testSession.Equipment.ParentEquipment != null ? testSession.Equipment.ParentEquipment.WorksOrder : new WorksOrder());
            var body = Globalisation.Emails.TestSessionMissingNetworkFileReportCss;
            body += Globalisation.Emails.TestSessionMissingNetworkFileReportBody.Replace(EmailServices.PlaceHolders.ProjectName,
                                                                        worksOrder.ProjectName)
                .Replace(EmailServices.PlaceHolders.ServiceTagNumber, serviceTagNumber.ToString())
                .Replace(EmailServices.PlaceHolders.SerialNumber, serialNumber)
                .Replace(EmailServices.PlaceHolders.EquipmentType, equipmentType.Name)
                .Replace(EmailServices.PlaceHolders.UnitReference, unitReference)
                .Replace(EmailServices.PlaceHolders.TestSessionType, testSession.TestSessionType.Name)
                .Replace(EmailServices.PlaceHolders.TesterName, testerName)
                .Replace(EmailServices.PlaceHolders.TesterSignOffDateTime, testerSignOffDate)
                .Replace(EmailServices.PlaceHolders.WitnessName, witnessName)
                .Replace(EmailServices.PlaceHolders.WitnessSignOffDateTime, witnessSignOffDate)
                .Replace(EmailServices.PlaceHolders.ExpectedFilePath, ScannedDocumentNetworkFilePath(testSession));

			var attachments = new List<Attachment>();

            // Generate a composite document memory stream comprising all the documents from the test session
            // then add this as an attachment
            var combinedPdf = TestDocumentCombinedStream(testSession);

            if (combinedPdf != null)
            {
				// Move the stream position to the beginning
				combinedPdf.Seek(0, SeekOrigin.Begin);
				var filename = string.Format("{0}.pdf", TestSessionBaseName(testSession));

				var attachment = new Attachment
				{
					FileName = filename,
					MimeType = System.Web.MimeMapping.GetMimeMapping(filename),
					Content = combinedPdf.ToArray()
				};
				attachments.Add(attachment);
            }

            try
            {
                // E-mail the test session details and zip archive
                if (testSession.Documents != null && testSession.Documents.Count > 0)
					_emailServices.Send(_configurationManager.SoftwareSupport.Email, subject, body, attachments);
                else
					_emailServices.Send(_configurationManager.SoftwareSupport.Email, subject, body);
            }
            catch (Exception ex)
            {
                throw new SmtpException(ex.Message);
            }
        }

        /// <summary>
        /// Constructs the network directory path for the test session, where its composite document will be located
        /// </summary>
        /// <param name="testSession">The test session for which to construct the directory path</param>
        /// <param name="withSwitchgearPath">Indicates whether or not the old version of the path (including the Switchgear segment) is to be returned</param>
        private string ScannedDocumentDirectory(TestSession testSession, bool withSwitchgearPath = false)
        {
            // Get current projects directory path
            var currentProjectsDirectoryPath = Path.Combine(new[] {
                    _configurationManager.FileSystem.ProjectShareRoot.UncPath, 
                    _configurationManager.FileSystem.TestDocuments.ProjectsDirectory,
                    _configurationManager.FileSystem.TestDocuments.CurrentProjectsDirectory
                });

            string worksOrderDirectoryPath;
            try
            {
                // Get works order directory path
                var worksOrder = testSession.Equipment.WorksOrder ?? (testSession.Equipment.ParentEquipment != null ? testSession.Equipment.ParentEquipment.WorksOrder : new WorksOrder());
                worksOrderDirectoryPath = _fileSystemServices.DirectoryMatchingPattern(
                    currentProjectsDirectoryPath,
                    string.Format(@"{0}*", _configurationManager.FileSystem.TestDocuments.WorksOrderDirectoryPrefix.Replace(FileSystemServices.PlaceHolders.WoNumber, worksOrder.WoNumber.ToString(CultureInfo.InvariantCulture))),
                    true,
                    _configurationManager.FileSystem.CredentialsDomain,
                    _configurationManager.FileSystem.CredentialsUsername,
                    _configurationManager.FileSystem.CredentialsPassword);
            }
            catch (IOException)
            {
                // Invalid directory path, so just return null
                return null;
            }

            // Get the target network subdirectory for the test session type
            string scannedDocumentDirectory;
            if (testSession.TestSessionLocation != null)
            {
                // If the test session has its location property set, we get the network subdirectory from that
                scannedDocumentDirectory = testSession.ClientWitnessSignatory == null
                    ? testSession.TestSessionLocation.NetworkSubdirectoryMardix
                    : testSession.TestSessionLocation.NetworkSubdirectoryWitness;
            }
            else
            {
                scannedDocumentDirectory = testSession.ClientWitnessSignatory == null
                    ? testSession.TestSessionType.NetworkSubdirectoryMardix
                    : testSession.TestSessionType.NetworkSubdirectoryWitness;
            }

            // Return the full path by combining all the elements
            return withSwitchgearPath
                       ? Path.Combine(new[] {
                           worksOrderDirectoryPath, 
                           _configurationManager.FileSystem.TestDocuments.SwitchgearDirectory,
                           _configurationManager.FileSystem.TestDocuments.TestingDirectory,
                           scannedDocumentDirectory
                       })
                       : Path.Combine(new[] {
                           worksOrderDirectoryPath, 
                           _configurationManager.FileSystem.TestDocuments.TestingDirectory,
                           scannedDocumentDirectory
                       });
        }

        /// <summary>
        /// Constructs the network file path of the composite document for the test session
        /// </summary>
        /// <param name="testSession">The test session for which to construct the file path</param>
        /// <param name="withSwitchgearPath">Indicates whether or not the old version of the path (including the Switchgear segment) is to be returned</param>
        private string ScannedDocumentNetworkFilePath(TestSession testSession, bool withSwitchgearPath = false)
        {
            return Path.Combine(
                ScannedDocumentDirectory(testSession, withSwitchgearPath),
                string.Format("{0}.pdf", TestSessionBaseName(testSession).Replace('/', ' ').Replace('\\', ' '))
                );
        }

        /// <summary>
        /// Constructs the base name of the combined document for the <paramref name="testSession"/>, following the pre-defined convention
        /// </summary>
        /// <param name="testSession">The test session for which to construct the base name</param>
        /// <returns></returns>
        private string TestSessionBaseName(TestSession testSession)
        {
            var forComponent = testSession.Equipment.ParentEquipment != null;

            var serialNumberParts = testSession.Equipment.SerialNumber.Split('/').ToList();
            var serialNumberPartA = serialNumberParts.Count > 0 ? serialNumberParts[0] : string.Empty;
            var serialNumberPartB = serialNumberParts.Count > 1 ? serialNumberParts[1] : string.Empty;
            var serialNumberPartD = serialNumberParts.Count > 3 ? serialNumberParts[3] : string.Empty;
            var equipmentType = testSession.Equipment.EquipmentType.Name;
            var unitReference = testSession.Equipment.UnitReference;
            var startDate = testSession.StartDate != null ? ((DateTime)testSession.StartDate).ToString("ddMMyy") : string.Empty;
            var m0 = !string.IsNullOrWhiteSpace(testSession.Equipment.M0) ? testSession.Equipment.M0 : (testSession.Equipment.ParentEquipment != null ? testSession.Equipment.ParentEquipment.M0 : null);
            var testSessionTypeName = string.Format("{0}{1}",
                testSession.TestSessionLocation != null ? string.Format("{0} ", testSession.TestSessionLocation.Name) : string.Empty,
                testSession.TestSessionType.AbbreviatedName.IsNullOrWhiteSpace() ? testSession.TestSessionType.Name : testSession.TestSessionType.AbbreviatedName
                );

            // Get base name by substituting default placeholders with test session details
            var baseName = _configurationManager.FileSystem.TestDocuments.CombinedBaseName
                .Replace(FileSystemServices.PlaceHolders.SerialPartA, serialNumberPartA)
                .Replace(FileSystemServices.PlaceHolders.SerialPartB, serialNumberPartB)
                .Replace(FileSystemServices.PlaceHolders.ComponentNumber, forComponent ? string.Format("-{0}", serialNumberPartD) : string.Empty)
                .Replace(FileSystemServices.PlaceHolders.M0, m0)
                .Replace(FileSystemServices.PlaceHolders.TestSessionTypeName, testSessionTypeName)
                .Replace(FileSystemServices.PlaceHolders.EquipmentType, equipmentType)
                .Replace(FileSystemServices.PlaceHolders.UnitReference, unitReference)
                .Replace(FileSystemServices.PlaceHolders.DateDdMmYy, startDate);

            // Strip invalid characters from base name
            foreach (var c in Path.GetInvalidFileNameChars())
                baseName = baseName.Replace(c.ToString(CultureInfo.InvariantCulture), "");

            return baseName;
        }

        /// <summary>
        /// Saves the combined test session document to the relevant network drive
        /// </summary>
        /// <param name="testSessionId">The id of the <see cref="TestSession"/> for which to generate the document</param>
        public string SaveTestSessionDocumentsToNetwork(Guid testSessionId)
        {
            // Get the test session
            var testSession = Single(testSessionId);

            // Generate a composite document memory stream comprising all the documents from the test session
            // then save this to the network
            var combinedPdf = TestDocumentCombinedStream(testSession);
            
            // If no combined pdf was able to be created, return an empty string
            if (combinedPdf == null)
                return string.Empty;
            
            // Move the stream position to the beginning
            combinedPdf.Seek(0, SeekOrigin.Begin);

            // Ensure there are no problems deriving the directory path before proceeding
            if (ScannedDocumentDirectory(testSession) == null) return null;

            // Save the document
            var filePath = _fileSystemServices.SaveFileData(
                combinedPdf,
                ScannedDocumentNetworkFilePath(testSession), 
                true,
                _configurationManager.FileSystem.CredentialsDomain,
                _configurationManager.FileSystem.CredentialsUsername,
                _configurationManager.FileSystem.CredentialsPassword
                );

            // If a duplicate version exists at the old network location, remove it
            if (_fileSystemServices.FileExists(
                ScannedDocumentNetworkFilePath(testSession, true),
                _configurationManager.FileSystem.CredentialsDomain,
                _configurationManager.FileSystem.CredentialsUsername,
                _configurationManager.FileSystem.CredentialsPassword
                ))
            {
                _fileSystemServices.DeleteFile(
                    ScannedDocumentNetworkFilePath(testSession, true),
                    _configurationManager.FileSystem.CredentialsDomain,
                    _configurationManager.FileSystem.CredentialsUsername,
                    _configurationManager.FileSystem.CredentialsPassword
                    );
            }

            // Return the file path of the saved document
            return filePath;
        }

        /// <summary>
        /// Returns a combined pdf document, comprising all the documents from the test session
        /// </summary>
        /// <param name="testSessionId">The id of the <see cref="TestSession"/> for which to generate the document</param>
        /// <returns>The composite document for the test session</returns>
        public Document TestDocumentCombinedCertificate(Guid testSessionId)
        {
            // Get the test session
            var testSession = Single(testSessionId);

            // Get the master documents
            var masterDocuments = GetMasterDocuments(testSession);
            if (masterDocuments.Count == 0)
                throw new EntityNotFoundException();

            // Get the combined test certificate content
            var content = TestDocumentCombinedStream(testSession).ToArray();

            // Form the combined document
            var document = new Document
            {
                Id = masterDocuments.First().Id,
                Description = masterDocuments.First().Description,
                Type = _documentTypeServices.Single(Types.DocumentType.Types.Uncategorised.CombinedTestCertificate.Id),
                Revisions = new HashSet<DocumentRevisionMetaData>()
            };
            foreach (var masterDocument in masterDocuments)
            {
                var documentRevisionMetadata = new DocumentRevisionMetaData(document)
                {
                    Id = masterDocument.LatestRevision.Id,
                    DisplayName = masterDocument.LatestRevision.DisplayName,
                    FileName = masterDocument.LatestRevision.FileName,
                    MimeType = masterDocument.LatestRevision.MimeType,
                    Revision = masterDocument.LatestRevision.Revision,
                    CreatedDateUtc = masterDocument.LatestRevision.CreatedDateUtc,
                    PublishedDateUtc = masterDocument.LatestRevision.PublishedDateUtc,
                    Bytes = content.Length,
                    Content = new DocumentRevisionContent
                    {
                        Id = masterDocument.LatestRevision.Content.Id,
                        Content = content
                    },
                };
                document.Revisions.Add(documentRevisionMetadata);
            }

            return document;
        }

        /// <summary>
        /// Returns a memory stream for a combined pdf document, comprising all the documents from the test session
        /// </summary>
        /// <param name="testSessionId">The id of the <see cref="TestSession"/> for which to generate the document</param>
        /// <returns>A memory stream of the composite document for the test session</returns>
        public MemoryStream TestDocumentCombinedStream(Guid testSessionId)
        {
            var testSession = Single(testSessionId);
            return TestDocumentCombinedStream(testSession);
        }

        /// <summary>
        /// Returns a memory stream for a combined pdf document, comprising all the documents from the test session
        /// </summary>
        /// <param name="testSession">The test session for which to generate the e-mail</param>
        private MemoryStream TestDocumentCombinedStream(TestSession testSession)
        {
            // Build up a list of all test session documents and test documents
            var documents = new List<Document>();

            // Add the panel test certificate first, if one exists
            if (testSession.Documents != null)
                documents.AddRange(testSession.Documents.Where(d =>
                    d.Type.Id == Types.DocumentType.Types.TestDocuments.PanelTestCertificate.Id));

            // Test documents can be shared between tests, so we only add distinct entities to the collection
            if (testSession.Tests != null)
            {
                foreach (var test in OrderedDocumentTests(testSession.Tests).Where(test => documents.All(d => d.Id != test.Document.Id)))
                {
                    documents.Add(test.Document);
                }
            }

            // Add the remaining test session documents
            // except for the signature images as these are annotated onto the master document
            if (testSession.Documents != null)
                documents.AddRange(testSession.Documents
                    .Where(d =>
                        d.Type.Id != Types.DocumentType.Types.TestDocuments.PanelTestCertificate.Id &&
                        d.Type.Id != Types.DocumentType.Types.Uncategorised.TestSessionPhoto.Id &&
                        d.Type.Id != Types.DocumentType.Types.Signatures.TestSessionTesterSignature.Id &&
                        d.Type.Id != Types.DocumentType.Types.Signatures.TestSessionMardixWitnessSignature.Id &&
                        d.Type.Id != Types.DocumentType.Types.Signatures.TestSessionClientWitnessSignature.Id)
                    .OrderBy(d => d.Type.QualityManagementSystemCode)                                   // Same ordering as on iOS app
                    .ThenBy(d => d.Revisions.OrderBy(r => r.CreatedDateUtc).First().CreatedDateUtc)
                    .ThenBy(d => d.Revisions.OrderBy(r => r.CreatedDateUtc).First().FileName)
                    );

            // Finally, if this is an IBAR Installation Test, add any completed IBAR Installation Joint Test documents
            if (testSession.TestSessionType.Id == Types.TestSessionType.Types.IbarInstallationTest.Id)
            {
                foreach (var component in testSession.Equipment.ChildEquipment.Where(e => e.EquipmentType.Id == Types.EquipmentType.Types.JointPack.Id))
                {
                    var componentId = component.Id;
                    var ibarInstallationJointTestSessions = CurrentSession.Query<TestSession>()
                        .Where(
                            e =>
                                e.Equipment.Id == componentId &&
                                e.TestSessionType.Id == Types.TestSessionType.Types.IbarInstallationJointTest.Id &&
                                e.Status.Id == Types.TestSessionStatus.Statuses.Completed.Id)
                        .ToList();
                    ibarInstallationJointTestSessions.ForEach(e => documents.AddRange(GetMasterDocuments(e)));
                }
            }

            // Combine the documents
            return _fileSystemServices.PdfDocumentCombinedStream(documents);
        }


        /// <summary>
        /// Regenerates all the documents for the <see cref="TestSession"/>, with key fields refreshed, in the database and on the network
        /// </summary>
        /// <param name="testSessionId">The id of the <see cref="TestSession"/> for which to regenerate the documents</param>
        public void RegenerateTestDocuments(Guid testSessionId)
        {
            // Get the test session
            var testSession = Single(testSessionId);

            // Build up list of documents
            var documents = new List<Document>();
            // Master document
            var masterDocument = testSession.Documents.FirstOrDefault(d => d.Type.Id == testSession.TestSessionType.MasterDocumentType.Id);
            if (masterDocument != null) documents.Add(masterDocument);
            // Test documents
            documents.AddRange(testSession.Tests.Where(t => t.Document != null).Select(t => t.Document));

            foreach (var document in documents.Distinct())
            {
                // Create a pdf reader to read the document content, and a pdf stamper to modify it and output to a memory stream
                var reader = new PdfReader(document.LatestRevision.Content.Content);
                var oStream = new MemoryStream();
                var stamper = new PdfStamper(reader, oStream);

                // Derive data
                var engineer = string.Format("{0} {1}", testSession.Tester.FirstName, testSession.Tester.Surname);
                var equipmentRating = testSession.Equipment != null && testSession.Equipment.ParentEquipment != null && testSession.Equipment.ParentEquipment.Qmf.Rating != null
                                        ? testSession.Equipment.ParentEquipment.Qmf.Rating.Name.ToString()
                                        : testSession.Equipment != null && testSession.Equipment.ParentEquipment == null && testSession.Equipment.Qmf.Rating != null
                                            ? testSession.Equipment.Qmf.Rating.Name.ToString()
                                            : null;
                var worksOrderNumber = testSession.Equipment.WorksOrder != null
                    ? testSession.Equipment.WorksOrder.WoNumber.ToString()
                    : testSession.Equipment.ParentEquipment.WorksOrder.WoNumber.ToString();
                var partNumber = testSession.Equipment.ParentEquipment != null
                    ? testSession.Equipment.UnitReference
                    : null;
                var project = testSession.Equipment.WorksOrder != null
                    ? testSession.Equipment.WorksOrder.ProjectName
                    : testSession.Equipment.ParentEquipment.WorksOrder.ProjectName;
                var address = testSession.Equipment.Branch != null ? testSession.Equipment.Branch.Address : null;
                string siteAddress = null;
                if (address != null) {
                    var addressComponents = new[] { address.Line1, address.Line2, address.Line3, address.Line4, address.Line5, address.Town, address.County, address.PostCode };
                    siteAddress = string.Join(",", addressComponents.Where(c => !string.IsNullOrEmpty(c)));
                }

                // Set the form fields
                stamper.AcroFields.SetField(FormFields.AhfRatingUppercase, testSession.AHFRating);
                stamper.AcroFields.SetField(FormFields.AhfSerialNoUppercase, testSession.AHFSerialNo);
                stamper.AcroFields.SetField(FormFields.Engineers, engineer);
                stamper.AcroFields.SetField(FormFields.Equipment, testSession.Equipment.EquipmentType.Name);
                stamper.AcroFields.SetField(FormFields.EquipmentUppercase, testSession.Equipment.UnitDescription);
                stamper.AcroFields.SetField(FormFields.EquipmentRating, equipmentRating);
                stamper.AcroFields.SetField(FormFields.EquipmentSerialNumber, testSession.Equipment.SerialNumber);
                stamper.AcroFields.SetField(FormFields.InstallationReference, testSession.Equipment.UnitReference);
                stamper.AcroFields.SetField(FormFields.JobNoUppercase, worksOrderNumber);
                stamper.AcroFields.SetField(FormFields.JobNumber, worksOrderNumber);
                stamper.AcroFields.SetField(FormFields.PanelLocation, testSession.Equipment.UnitLocation);
                stamper.AcroFields.SetField(FormFields.PanelRef, testSession.Equipment.UnitReference);
                stamper.AcroFields.SetField(FormFields.PanelReference, testSession.Equipment.UnitReference);
                stamper.AcroFields.SetField(FormFields.PanelReferenceUppercase, testSession.Equipment.UnitReference);
                stamper.AcroFields.SetField(FormFields.PartNoUppercase, partNumber);
                stamper.AcroFields.SetField(FormFields.Project, project);
                stamper.AcroFields.SetField(FormFields.ProjectUppercase, project);
                stamper.AcroFields.SetField(FormFields.SerialNumber, testSession.Equipment.SerialNumber);
                stamper.AcroFields.SetField(FormFields.ServiceTagNoUppercase, testSession.Equipment.ServiceTagNumber.ToString());
                stamper.AcroFields.SetField(FormFields.ServiceTagNumber, testSession.Equipment.ServiceTagNumber.ToString());
                stamper.AcroFields.SetField(FormFields.SiteAddress, siteAddress);
                stamper.AcroFields.SetField(FormFields.StsRatingUppercase, testSession.STSRating);
                stamper.AcroFields.SetField(FormFields.StsSerialNoUppercase, testSession.STSSerialNo);
                stamper.AcroFields.SetField(FormFields.TxRatingUppercase, testSession.TXRating);
                stamper.AcroFields.SetField(FormFields.TxSerialNoUppercase, testSession.TXSerialNo);
                stamper.AcroFields.SetField(FormFields.UnitRatingUppercase, testSession.UnitRating);
                stamper.AcroFields.SetField(FormFields.UnitRef, testSession.Equipment.UnitReference);
                stamper.AcroFields.SetField(FormFields.UnitReferenceUppercase, testSession.Equipment.UnitReference);
                stamper.AcroFields.SetField(FormFields.UnitSerialNo, testSession.Equipment.SerialNumber);
                stamper.AcroFields.SetField(FormFields.UnitSerialNoUppercase, testSession.Equipment.SerialNumber);
                stamper.AcroFields.SetField(FormFields.WoNumber, worksOrderNumber);

                // Close the pdf stamper to flush the output memory stream
                stamper.Writer.CloseStream = false;
                stamper.Close();

                // Move the stream position to the beginning
                oStream.Seek(0, SeekOrigin.Begin);

                // Update the content
                var content = oStream.ToArray();
                document.LatestRevision.Content.Content = content;
                document.LatestRevision.Content.FileChecksum = _fileSystemServices.GenerateFileChecksum(document.LatestRevision.Content.Content);

                document.LatestRevision.Bytes = document.LatestRevision.Content.Content.Length;

                // Save the revision
                CurrentSession.SaveOrUpdate(document.LatestRevision);

                // Refresh the signatories and signatures
                AddTestSessionPhotoToDocument(document, testSession);
                SetSignatoriesInDocument(document, testSession);
                AddSignaturesToDocument(document, testSession);
            }

            // Refresh the documents on the network
            SaveTestSessionDocumentsToNetwork(testSession.Id);
        }

        /// <summary>
        /// Regenerates the test documents in the database following a run move, without affecting any test session data.
        /// </summary>
        /// <param name="equipmentId">The id of the equipment that has been moved.</param>
        /// <exception cref="CannotRenameTestSessionDocumentException">Thrown when the existing file could not be renamed.  A new file is created.</exception>
        public void MoveRun(long equipmentId)
	    {
			// Get the existing test session.
			var testSession = CoreQueryOver<TestSession>().Where(ts => ts.Equipment.Id == equipmentId)
														.SingleOrDefault();

			// If there is no test session then nothing to do.
		    if (testSession == null) return;

			// Only completed test sessions should be regenerated.
		    if (testSession.Status.Id != Types.TestSessionStatus.Statuses.Completed.Id) return;

			// There is a test session, so let's proceed.
	        var currentFileUnc = string.Empty;
            var newFileUnc = string.Empty;

            // Get the file unc before the changes.
            // Try catch is to allow the updating of the equipment to proceed in the event of a file system exception
	        try { currentFileUnc = ScannedDocumentNetworkFilePath(testSession.Id); }
            catch { }

	        try
	        {
                // Get the new file path at this point as we want to trigger an exception
                // if there are any problems accessing the network path
                newFileUnc = ScannedDocumentNetworkFilePath(testSession);

                // Determine if the current test session documentation is on the network.
                if (_fileSystemServices.FileExists(currentFileUnc
                    , _configurationManager.FileSystem.CredentialsDomain
                    , _configurationManager.FileSystem.CredentialsUsername
                    , _configurationManager.FileSystem.CredentialsPassword))
                {
                    // Yes the file already exists.  Just rename.
                    _fileSystemServices.RenameFile(currentFileUnc, newFileUnc
                        , _configurationManager.FileSystem.CredentialsDomain
                        , _configurationManager.FileSystem.CredentialsUsername
                        , _configurationManager.FileSystem.CredentialsPassword);
                }
                else
                {
                    // For some reason the file does not exist, lets recreate.
                    SaveTestSessionDocumentsToNetwork(testSession.Id);
                }
            }
            catch (Exception)
            {
                // For some reason the file rename did not work ... maybe someone has it open.
                // So lets just create a new one.
                SaveTestSessionDocumentsToNetwork(testSession.Id);
                throw new CannotRenameTestSessionDocumentException(currentFileUnc, newFileUnc);
            }
	    }

        /// <summary>
        /// Returns the master documents for the <paramref name="testSession">test session</paramref>.
        /// </summary>
        /// <param name="testSession">The test session to get the master documents for.</param>
        /// <returns>The <paramref name="testSession">test session</paramref>'s master documents collection.</returns>
        private IList<Document> GetMasterDocuments(TestSession testSession)
        {
            var masterDocuments = new List<Document>();

            masterDocuments.AddRange(testSession.Documents.Where(d => d.Type.Id == testSession.TestSessionType.MasterDocumentType.Id));

            foreach (var test in OrderedDocumentTests(testSession.Tests).Where(t => masterDocuments.All(d => d.Id != t.Document.Id)))
            {
                masterDocuments.Add(test.Document);
            }

            return masterDocuments;
        }

        /// <summary>
        /// Applies standard ordering to the supplied <paramref name="tests">collection of tests</paramref>.
        /// </summary>
        /// <param name="tests">The collection of tests to reorder.</param>
        /// <returns>The reordered <paramref name="tests">collection of tests</paramref>.</returns>
        private IList<Test> OrderedDocumentTests(IEnumerable<Test> tests)
        {
            return tests
                .Where(t => t.Document != null)
                .OrderBy(t => t.Document.Type.QualityManagementSystemCode)                                  // Firstly order by quality management system code, i.e. document type code
                .ThenBy(t => t.CircuitBreakerReference, new NumericStringComparer())                        // Then by circuit breaker reference, if applicable
                .ThenBy(t => t.Document.Revisions.OrderBy(r => r.CreatedDateUtc).First().CreatedDateUtc)    // Then by test document initial creation date
                .ThenBy(t => t.Document.Revisions.OrderBy(r => r.CreatedDateUtc).First().FileName)          // Then by test document filename (if creation dates are identical)
                .ToList();
        }

        /// <summary>
        /// Updates the commission status for the equipment item being tested, if relevant
        /// </summary>
        /// <param name="testSession">The test session being updated</param>
        /// <param name="originalTestSessionStatusId">The id of the original test session status prior to being updated</param>
        private void UpdateCommissionStatus(TestSession testSession, Guid originalTestSessionStatusId)
        {
            var component = _equipmentServices.Single(testSession.Equipment.Id);

            // Scenario 1 - Test session status has changed from 'Not Started' to ANY OTHER status
            if (originalTestSessionStatusId == Types.TestSessionStatus.Statuses.NotStarted.Id && testSession.Status.Id != Types.TestSessionStatus.Statuses.NotStarted.Id)
                // Update the component commission status to be In Test
                component.CommissionStatus = _commissionStatusServices.Single(Types.CommissionStatus.Statuses.InTest.Id);
            
            // Scenario 2 - Test session status has changed from something other than 'Completed' to 'Completed'
            // Note that this could potentially occur at the same time as Scenario 1, if a test session is pre-activated then completed offline
            if (originalTestSessionStatusId != Types.TestSessionStatus.Statuses.Completed.Id && testSession.Status.Id == Types.TestSessionStatus.Statuses.Completed.Id && testSession.Result.Id == Types.TestResult.Results.Pass.Id)
                // Update the component commission status to be In Test
                component.CommissionStatus = _commissionStatusServices.Single(Types.CommissionStatus.Statuses.TestingComplete.Id);

            CurrentSession.SaveOrUpdate(component);
        }

        /// <summary>
        /// Updates the build status for the equipment item being tested, if relevant
        /// </summary>
        /// <param name="testSession">The test session being updated</param>
        /// <param name="originalTestSessionStatusId">The id of the original test session status prior to being updated</param>
        /// <param name="buildLocationId">The id of the build location where the test session was updated</param>
        private void UpdateBuildStatus(TestSession testSession, Guid originalTestSessionStatusId, Guid? buildLocationId)
        {
            var component = _equipmentServices.Single(testSession.Equipment.Id);

            // Get production job equipment and one associated production part identifier (any one will do for what we need)
            var productionJobEquipment = component.ProductionJobEquipment.SingleOrDefault();
            if (productionJobEquipment == null) return;
            var identifier = productionJobEquipment.Identifiers.FirstOrDefault();
            var serviceTag = component.ServiceTagNumber;

            // Scenario 1 - Test session status has changed from 'Not Started' to ANY OTHER status
            // Build scenario - Test started
            if (originalTestSessionStatusId == Types.TestSessionStatus.Statuses.NotStarted.Id && testSession.Status.Id != Types.TestSessionStatus.Statuses.NotStarted.Id)
            {
                // Get build report
                var buildReport = ServicesContext.Mediator.Send(new Dto.Queries.Production.BuildReport.Query.Query { ProductionJobEquipmentId = productionJobEquipment.Id });
                if (buildReport != null && buildLocationId != null)
                {
                    // Get currently active build stage
                    var currentStage = buildReport.CurrentlyActiveStage();

                    // If build stage is 'Test' and not started, progress the build
                    if (currentStage != null && currentStage.Id == ProductionStage.Stages.Test.Id && currentStage.IsStarted == false)
                    {
                        var progressBuild = ConstructProgressBuild((identifier != null ? (Guid?)(identifier.Id) : null), serviceTag, (Guid)buildLocationId);
                        ServicesContext.Mediator.Send(progressBuild);
                    }
                }
            }

            // At this point, NHibernate level 1 cache still has the build report in memory, including the 'not started' flag
            // Removing the object from cache will force NHibernate to requery the database, getting the updated flags
            CurrentSession.Flush();
            CurrentSession.Clear();

            // Scenario 2 - Test session status has changed from something other than 'Completed' to 'Completed'
            // Build scenario - Test completed
            // Note that this could potentially occur at the same time as Scenario 1, if a test session is pre-activated then completed offline
            if (originalTestSessionStatusId != Types.TestSessionStatus.Statuses.Completed.Id && testSession.Status.Id == Types.TestSessionStatus.Statuses.Completed.Id && testSession.Result.Id == Types.TestResult.Results.Pass.Id)
            {
                // Get build report
                var buildReport = ServicesContext.Mediator.Send(new Dto.Queries.Production.BuildReport.Query.Query { ProductionJobEquipmentId = productionJobEquipment.Id });
                if (buildReport != null)
                {
                    // Get currently active build stage
                    var currentStage = buildReport.CurrentlyActiveStage();

                    // If build stage is 'Test' and started but not completed, progress the build
                    if (currentStage != null && currentStage.Id == ProductionStage.Stages.Test.Id && currentStage.IsStarted && currentStage.IsComplete == false)
                    {
                        // Get the location from the corresponding start step
                        ProductionJobBuildStep productionJobBuildStepAlias = null;
                        EquipmentTypeProductionStepDefinition equipmentTypeProductionStepDefinitionAlias = null;
                        ProductionStepDefinition productionStepDefinitionAlias = null;
                        ProductionStep productionStepAlias = null;
                        ProductionStageDefinition productionStageDefinitionAlias = null;
                        ProductionStage productionStageAlias = null;
                        ProductionJobEquipment productionJobEquipmentAlias = null;
                        var buildStepStart = CurrentSession.QueryOver<ProductionJobBuildStepAudit>()
                            .JoinAlias(e => e.ProductionJobBuildStep, () => productionJobBuildStepAlias)
                            .JoinAlias(() => productionJobBuildStepAlias.EquipmentTypeProductionStepDefinition, () => equipmentTypeProductionStepDefinitionAlias)
                            .JoinAlias(() => productionJobBuildStepAlias.ProductionJobEquipment, () => productionJobEquipmentAlias)
                            .JoinAlias(() => equipmentTypeProductionStepDefinitionAlias.ProductionStepDefinition, () => productionStepDefinitionAlias)
                            .JoinAlias(() => productionStepDefinitionAlias.Step, () => productionStepAlias)
                            .JoinAlias(() => productionStepDefinitionAlias.ProductionStageDefinition, () => productionStageDefinitionAlias)
                            .JoinAlias(() => productionStageDefinitionAlias.Stage, () => productionStageAlias)
                            .Where(() => productionJobEquipmentAlias.Id == productionJobEquipment.Id)
                            .Where(() => productionStepDefinitionAlias.Id == currentStage.ProductionParts.SingleOrDefault().Steps.SingleOrDefault().Id)
                            .Where(() => productionStageAlias.Id == ProductionStage.Stages.Test.Id)
                            .SingleOrDefault();

                        var progressBuild = ConstructProgressBuild((identifier != null ? (Guid?)(identifier.Id) : null), serviceTag, buildStepStart.BuildLocation.Id);
                        ServicesContext.Mediator.Send(progressBuild);
                    }
                }
            }
        }

        /// <summary>
        /// Returns a <see cref="Dto.Commands.Production.ProgressBuild.Command.Command">progress build command</see> based on the supplied parameters.
        /// </summary>
        /// <param name="identifierId">One of the production part identifier ids</param>.
        /// <param name="serviceTag">The equipment service tag</param>.
        /// <param name="buildLocationId">The build location id</param>.
        /// <returns>A <see cref="Dto.Commands.Production.ProgressBuild.Command.Command">progress build command</returns>.
        private Dto.Commands.Production.ProgressBuild.Command.Command ConstructProgressBuild(Guid? identifierId, long? serviceTag, Guid buildLocationId)
        {
            if (identifierId != null)
                return new Dto.Commands.Production.ProgressBuild.Command.Command
                {
                    BuildLocationId = buildLocationId,
                    ProductionJobEquipmentProductionPartIdentifierId = identifierId
                };
            else
                return new Dto.Commands.Production.ProgressBuild.Command.Command
                {
                    BuildLocationId = buildLocationId,
                    ServiceTag = serviceTag
                };
        }

        /// <summary>
        /// Modifies the document content to set the Mardix and witness signatory fields, where these values exist
        /// </summary>
        /// <param name="document">The document for which to set the form fields</param>
        /// <param name="testSession">The associated test session</param>
        private void SetSignatoriesInDocument(Document document, TestSession testSession)
        {
            // Add each signatory to the document, if they exist
            if (testSession.MardixSignatory != null)
                _fileSystemServices.SetPdfFormField(document, FileSystemServices.PdfFormFields.TesterName, string.Format("{0} {1}", testSession.MardixSignatory.FirstName, testSession.MardixSignatory.Surname));
            if (testSession.MardixWitnessSignatory != null)
                _fileSystemServices.SetPdfFormField(document, FileSystemServices.PdfFormFields.WitnessName, string.Format("{0} {1}", testSession.MardixWitnessSignatory.FirstName, testSession.MardixWitnessSignatory.Surname));
            if (testSession.ClientWitnessSignatory != null)
                _fileSystemServices.SetPdfFormField(document, FileSystemServices.PdfFormFields.WitnessName, testSession.ClientWitnessSignatory.FullName);

            // Update the content of the document
            CurrentSession.SaveOrUpdate(document);
        }

        /// <summary>
        /// Modifies the <paramref name="document"/> content to annotate the test session photo, where this exists
        /// </summary>
        /// <param name="document">The document to add the signatures to</param>
        /// <param name="testSession">The test session whose collection the document exists in</param>
        public void AddTestSessionPhotoToDocument(Document document, TestSession testSession)
        {
            if (!testSession.TestSessionType.DisplayPhoto)
                return;

            // Get the test session photo from the test session's documents collection
            var testSessionPhoto = testSession.Documents
                .Where(d => d.Type.Id == Types.DocumentType.Types.Uncategorised.TestSessionPhoto.Id)
                .OrderByDescending(d => d.LatestRevision.CreatedDateUtc)
                .FirstOrDefault();

            // If no test session photo exists in the test session document's collection, attempt to retrive the stock holding image instead
            if (testSessionPhoto == null)
            {
                var stockImageDocumentType = Types.DocumentRevisionMetadata.Types.StockImagePhotographyNotAllowed;
                var documentRevisionMetadata = CurrentSession.Query<DocumentRevisionMetaData>().FirstOrDefault(e => e.FileName == stockImageDocumentType.FileName);
                if (documentRevisionMetadata != null)
                {
                    // If the stock holding image exists, generate a new test session photo object using the content of the stock image
                    // We need to do this so the document co-ordinates find a match for an image with the expected document type, i.e. test session photo
                    testSessionPhoto = new Document
                    {
                        Id = Guid.NewGuid(),
                        Type = CurrentSession.Query<Domain.Documents.Type>() .FirstOrDefault(e => e.Id == Types.DocumentType.Types.Uncategorised.TestSessionPhoto.Id),
                        Revisions = new HashSet<DocumentRevisionMetaData>()
                    };
                    var testSessionPhotoMetaData = new DocumentRevisionMetaData(testSessionPhoto)
                    {
                        MimeType = stockImageDocumentType.MimeType,
                        Bytes = documentRevisionMetadata.Bytes,
                        Content = new DocumentRevisionContent
                        {
                            Content = documentRevisionMetadata.Content.Content
                        },
                    };
                    testSessionPhoto.Revisions.Add(testSessionPhotoMetaData);
                }
            }

            // Add the test session photo to the document, if it exists
            if (testSessionPhoto != null)
                _fileSystemServices.AddImageToPdfDocument(document, testSessionPhoto);

            // Update the content of the document
            CurrentSession.SaveOrUpdate(document);
        }

        /// <summary>
        /// Modifies the <paramref name="document"/> content to annotate the signature images with tester and witness signatures annotated, where these exist
        /// </summary>
        /// <param name="document">The document to add the signatures to</param>
        /// <param name="testSession">The test session whose collection the document exists in</param>
        public void AddSignaturesToDocument(Document document, TestSession testSession)
        {
            // Get the signature images from the test session's documents collection
            var testerSignature = testSession.Documents.FirstOrDefault(d => d.Type.Id == Types.DocumentType.Types.Signatures.TestSessionTesterSignature.Id);
            var mardixWitnessSignature = testSession.Documents.FirstOrDefault(d => d.Type.Id == Types.DocumentType.Types.Signatures.TestSessionMardixWitnessSignature.Id);
            var clientWitnessSignature = testSession.Documents.FirstOrDefault(d => d.Type.Id == Types.DocumentType.Types.Signatures.TestSessionClientWitnessSignature.Id);

            // Add each signature to the document, if they exist
            // Although the two types of witness signature are written to the same co-ordinates, there should only ever be one
            if (testerSignature != null && testSession.MardixSignatory != null)
                _fileSystemServices.AddImageToPdfDocument(document, testerSignature);
            if (mardixWitnessSignature != null && testSession.MardixWitnessSignatory != null)
                _fileSystemServices.AddImageToPdfDocument(document, mardixWitnessSignature);
            if (clientWitnessSignature != null && testSession.ClientWitnessSignatory != null)
                _fileSystemServices.AddImageToPdfDocument(document, clientWitnessSignature);

            // Update the content of the document
            CurrentSession.SaveOrUpdate(document);
        }

        /// <summary>
        /// Custom comparer for strings that correctly orders numeric strings to e.g. 1,2,10 instead of 1,10,2
        /// </summary>
        private class NumericStringComparer : IComparer<string>
        {
            public int Compare(string x, string y)
            {
                // Firstly handle any null values
                if (x == null && y == null) return 0;
                else if (x == null) return -1;
                else if (y == null) return 1;

                // If both values are numeric, compare them as numbers
                int intX, intY;
                if (int.TryParse(x, out intX) && int.TryParse(y, out intY))
                    return intX.CompareTo(intY);

                // Otherwise straightforward string compare
                return x.CompareTo(y);
            }
        }
    }
}