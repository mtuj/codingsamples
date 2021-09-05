using System;
using System.Collections.Generic;
using System.Linq;
using NHibernate.Criterion;
using NHibernate.SqlCommand;
using Vision.Api.DotNet.ApplicationServices.Branches;
using Vision.Api.DotNet.ApplicationServices.Countries;
using Vision.Api.DotNet.ApplicationServices.Employees;
using Vision.Api.DotNet.ApplicationServices.Equipments;
using Vision.Api.DotNet.ApplicationServices.Extensions;
using Vision.Api.DotNet.ApplicationServices.WorksOrders;
using Vision.Api.DotNet.Common.Exceptions;
using Vision.Api.DotNet.Domain.Employees;
using Vision.Api.DotNet.Domain.SiteTimeLogs;
using Vision.Api.DotNet.Domain.Paging;

namespace Vision.Api.DotNet.ApplicationServices.SiteTimeLogs
{
    public class SiteTimeLogServices : SaveableServicesBase<Dto.Write.SiteTimeLogs.SiteTimeLog, SiteTimeLog>, ISiteTimeLogServices
    {
        private readonly ISiteTimeLogTypeServices _siteTimeLogTypeServices;
        private readonly IEmployeeServices _employeeServices;
        private readonly ICountryServices _countryServices;
        private readonly IWorksOrderServices _worksOrderServices;
        private readonly IBranchServices _branchServices;
        private readonly IEquipmentServices _equipmentServices;
        private readonly PropertyProjection _defaultOrderBy = Projections.Property<SiteTimeLog>(p => p.StartDateTimeUtc);

        private const decimal OverTimeAt1Point33HoursThreshold = (decimal)9.5;

        /// <summary>
        /// Ctor
        /// </summary>
        /// <param name="servicesContext">The services context.</param>
        /// <param name="siteTimeLogType">The site time log type services.</param>
        /// <param name="employeeServices">The employee services.</param>
        /// <param name="country">The country services.</param>
        /// <param name="worksOrder">The works order services.</param>
        /// <param name="branchServices">The branch services.</param>
        /// <param name="equipmentServices">The equipment services.</param>
        public SiteTimeLogServices(IServicesContext servicesContext, ISiteTimeLogTypeServices siteTimeLogTypeServices, IEmployeeServices employeeServices, ICountryServices countryServices, IWorksOrderServices worksOrderServices, IBranchServices branchServices, IEquipmentServices equipmentServices)
            : base(servicesContext)
        {
            _siteTimeLogTypeServices = siteTimeLogTypeServices;
            _employeeServices = employeeServices;
            _countryServices = countryServices;
            _worksOrderServices = worksOrderServices;
            _branchServices = branchServices;
            _equipmentServices = equipmentServices;
        }

        /// <summary>
        /// Returns all <see cref="SiteTimeLog"/>s in the system.
        /// </summary>
        /// <returns>A list of <see cref="SiteTimeLog"/>s.</returns>
        public IList<SiteTimeLog> All()
        {
            var query = CoreQueryOver<SiteTimeLog>()
                .ExecuteWithOrdering(ServicesContext, _defaultOrderBy)
                .ToList();

            return query;
        }

        /// <summary>
        /// Gets a <see cref="PagedData{T}">paged list of all <see cref="SiteTimeLog"/></see> in the system within the current context.
        /// </summary>
        /// <param name="skip">The number of records to skip.</param>
        /// <param name="top">The number of records to return.</param>
        /// <returns>The requested page of <see cref="SiteTimeLog"/>s.</returns>
        public PagedData<SiteTimeLog> All(int skip, int top)
        {
            var pagedData = CoreQueryOver<SiteTimeLog>()
                .ExecuteWithPaging(skip, top, ServicesContext, _defaultOrderBy);
            return pagedData;
        }

        /// <summary>
        /// Returns the single <see cref="SiteTimeLog"/> for the supplied <paramref name="id">Id</paramref>.
        /// </summary>
        /// <param name="id">The id of the <see cref="SiteTimeLog"/> to return.</param>
        /// <returns>A <see cref="SiteTimeLog"/>.</returns>
        public SiteTimeLog Single(Guid id)
        {
            var siteTimeLog = CoreQueryOver<SiteTimeLog>().Where(d => d.Id == id).SingleOrDefault();
            return siteTimeLog;
        }

        /// <summary>
        /// <para>Gets the page number on which the record identified by its <paramref name="id"/> will appear.</para>
        /// </summary>
        /// <param name="id">The id of the record.</param>
        /// <param name="pageSize">The page size.</param>
        /// <returns>The page number on which the record will appear.</returns>
        public PageInformation PageInformation(Guid id, int pageSize)
        {
            return CalculatePageInformation<SiteTimeLog>(id, pageSize, _defaultOrderBy);
        }

        /// <summary>
        /// Creates a new <see cref="SiteTimeLog"/> for the supplied <param name="entity">dto entity</param> and persists it in the system.
        /// </summary>
        /// <param name="entityId">The id of the <see cref="SiteTimeLog"/> to be persisted.</param>
        /// <param name="entity">The Dto object to use to create the <see cref="SiteTimeLog"/>.</param>
        /// <returns>The persisted <see cref="SiteTimeLog"/>.</returns>
        internal override SiteTimeLog Create(Dto.Write.SiteTimeLogs.SiteTimeLog entity, Guid? entityId)
        {
            // Retrieve the associated domain objects.
            var siteTimeLogType = _siteTimeLogTypeServices.Single(entity.SiteTimeLogTypeId);
            var employee = _employeeServices.Single(entity.EmployeeId);
            var country = (entity.CountryId.HasValue) ? _countryServices.Single(entity.CountryId.Value) : null;
            var worksOrder = (entity.WorksOrderId.HasValue) ? _worksOrderServices.Single(entity.WorksOrderId.Value) : null;
            var site = (entity.SiteId.HasValue) ? _branchServices.Single(entity.SiteId.Value) : null;
            var equipment = (entity.EquipmentId.HasValue) ? _equipmentServices.Single(entity.EquipmentId.Value) : null;

            //  Create the site time log.
            var siteTimeLog = new SiteTimeLog
            {
                SiteTimeLogType = siteTimeLogType,
                Employee = employee,
                Country = country,
                WorksOrder = worksOrder,
                Site = site,
                Equipment = equipment,
                StartDateTimeUtc = entity.StartDateTimeUtc,
                FinishDateTimeUtc = entity.FinishDateTimeUtc
            };

            // Save the site time log.
            Save(siteTimeLog, entityId);

            // If the employee has just logged a Country Visit event, update their current location.
            if (siteTimeLogType.Id == Types.SiteTimeLogType.Types.CountryVisit.Id)
                UpdateEmployeeCurrentLocation(employee);

            return siteTimeLog;
        }

        /// <summary>
        /// Updates a <see cref="SiteTimeLog"/> using the <paramref name="entityId"/> with the supplied <param name="entity">dto entity</param> and persists it to the system.
        /// </summary>
        /// <param name="entityId">The id of the <see cref="SiteTimeLog"/> to be persisted.</param>
        /// <param name="entity">The Dto object to use to update the <see cref="SiteTimeLog"/>.</param>
        /// <returns>The persisted <see cref="SiteTimeLog"/>.</returns>
        internal override SiteTimeLog Update(Dto.Write.SiteTimeLogs.SiteTimeLog entity, Guid entityId)
        {
            // Retrieve the associated domain objects.
            var siteTimeLogType = _siteTimeLogTypeServices.Single(entity.SiteTimeLogTypeId);
            var employee = _employeeServices.Single(entity.EmployeeId);
            var country = (entity.CountryId.HasValue) ? _countryServices.Single(entity.CountryId.Value) : null;
            var worksOrder = (entity.WorksOrderId.HasValue) ? _worksOrderServices.Single(entity.WorksOrderId.Value) : null;
            var site = (entity.SiteId.HasValue) ? _branchServices.Single(entity.SiteId.Value) : null;
            var equipment = (entity.EquipmentId.HasValue) ? _equipmentServices.Single(entity.EquipmentId.Value) : null;

            // Load the existing site time log.
            var siteTimeLog = Single(entityId);

            if (siteTimeLog == null)
                throw new EntityNotFoundException();

            // Update the site time log.
            siteTimeLog.SiteTimeLogType = siteTimeLogType;
            siteTimeLog.Employee = employee;
            siteTimeLog.Country = country;
            siteTimeLog.WorksOrder = worksOrder;
            siteTimeLog.Site = site;
            siteTimeLog.Equipment = equipment;
            siteTimeLog.StartDateTimeUtc = entity.StartDateTimeUtc;
            siteTimeLog.FinishDateTimeUtc = entity.FinishDateTimeUtc;

            // Save the site time log.
            CurrentSession.Update(siteTimeLog);

            // If the employee has just logged a Country Visit event, update their current location.
            if (siteTimeLogType.Id == Types.SiteTimeLogType.Types.CountryVisit.Id)
                UpdateEmployeeCurrentLocation(employee);

            return siteTimeLog;
        }

        /// <summary>
        /// Deletes the <see cref="SiteTimeLog"/> with the provided <paramref name="id"/>.
        /// </summary>
        /// <param name="id">The id of the <see cref="SiteTimeLog"/> to be deleted.</param>
        public bool Delete(Guid id)
        {
            // Ensure we have a site time log with the specified id.
            if (id == Guid.Empty)
                return false;

            // Retrieve the site time log.
            var existingEntry = CoreQueryOver<SiteTimeLog>()
                                .Where(d => d.Id == id)
                                .SingleOrDefault();

            // Delete the site time log.
            if (existingEntry != null)
            {
                CurrentSession.Delete(existingEntry);
                CurrentSession.Flush();
                return true;
            }

            return false;
        }

        /// <summary>
        /// Returns a <see cref="IList{T}">collection of consolidated <see cref="SiteTimeLog"/>s</see> for the specified parameters.
        /// </summary>
        /// <param name="startDateTimeUtc">The start of the date range for which to return site time logs.</param>
        /// <param name="endDateTimeUtc">The end of the date range for which to return site time logs.</param>
        /// <param name="siteTimeLogTypeCategoryIds">A collection of <see cref="SiteTimeLogTypeCategory"/> ids for which to return site time logs.</param>
        /// <param name="siteTimeLogTypeIds">A collection of <see cref="SiteTimeLogType"/> ids for which to return site time logs.</param>
        /// <param name="employeeIds">A collection of <see cref="Domain.Employees.Employee"/> ids for which to return site time logs.</param>
        /// <param name="countryIds">A collection of <see cref="Domain.Countries.Country"/> ids for which to return site time logs.</param>
        /// <param name="worksOrderNumbers">A collection of <see cref="Domain.WorksOrders.WorksOrder"/> numbers for which to return site time logs.</param>
        /// <param name="siteIds">A collection of <see cref="Domain.Branches.Branch"/> ids for which to return site time logs.</param>
        /// <param name="equipmentIds">A collection of <see cref="Domain.Equipments.Equipment"/> ids for which to return site time logs.</param>
        /// <param name="returnComplete">If true, return collection will include complete time logs.</param>
        /// <param name="returnIncomplete">If true, return collection will include incomplete time logs (segments that could not be matched with a corresponding start/finish segment).</param>
        /// <returns>A <see cref="IList{T}">collection of consolidated<see cref="SiteTimeLog"/>s</see>.</returns>
        public IList<SiteTimeLog> GetConsolidatedSiteTimeLogs(DateTime? startDateTimeUtc, DateTime? endDateTimeUtc, IList<Guid> siteTimeLogTypeCategoryIds, IList<Guid> siteTimeLogTypeIds, IList<Guid> countryIds, IList<int> worksOrderNumbers, IList<int> siteIds, IList<long> equipmentIds, IList<int> employeeIds, bool returnComplete, bool returnIncomplete)
        {
            var completeSiteTimeLogs = new List<SiteTimeLog>();
            var incompleteSiteTimeLogs = new List<SiteTimeLog>();

            // Get all time log segments matching the supplied parameters.
            var siteTimeLogSegments = GetAllSiteTimeLogs(
                startDateTimeUtc, 
                endDateTimeUtc, 
                siteTimeLogTypeCategoryIds, 
                siteTimeLogTypeIds, 
                employeeIds
                );

            // Get the distinct employees and time log types contained in the list of segments.
            IList<Employee> employees = siteTimeLogSegments.Select(e => e.Employee).Distinct().ToList();
            IList<SiteTimeLogType> siteTimeLogTypes = siteTimeLogSegments.Select(e => e.SiteTimeLogType).Distinct().ToList();

            foreach (var employee in employees)
            {
                foreach (var siteTimeLogType in siteTimeLogTypes)
                {
                    var siteTimeLogTypeIdsToProcess = new List<Guid> { siteTimeLogType.Id };
                    // If we are processing Service (Work) time logs, we also want to query for Site Attendance time logs
                    // as these are also used to terminate open Service logs.
                    if (siteTimeLogType.Id == Types.SiteTimeLogType.Types.Service.Id)
                        siteTimeLogTypeIdsToProcess.Add(Types.SiteTimeLogType.Types.SiteAttendance.Id);

                    // Initialise our active time log object.
                    // This will be re-used to build up a complete time log from the segments.
                    SiteTimeLog activeTimeLog = null;

                    // Flag to set when we first encounter a valid Start segment.
                    var startSegmentFound = false;

                    var employeeId = employee.Id;
                    foreach (var timeLogSegment in siteTimeLogSegments
                        .Where(e => e.Employee.Id == employeeId && siteTimeLogTypeIdsToProcess.Contains(e.SiteTimeLogType.Id))
                        .OrderBy(e => e.StartDateTimeUtc ?? e.FinishDateTimeUtc))
                    {
                        if (activeTimeLog == null)
                        {
                            // Active time log object is null.
                            // This means we are looking to start building a new time log.

                            // This line may seem redundant ... 
                            // but when building a list of some time log types (e.g. Service (Work)), we also need to process other segment types (e.g. Site Attendance)
                            // so here we are ensuring this block of code only applies to the time log type for which we are currently building a list.
                            if (timeLogSegment.SiteTimeLogType.Id == siteTimeLogType.Id)
                            {
                                if (timeLogSegment.StartDateTimeUtc != null)
                                {
                                    // Segment has a start date.
                                    startSegmentFound = true;

                                    // Begin a new active time log by cloning the segment encountered.
                                    activeTimeLog = CloneSiteTimeLog(timeLogSegment);

                                    // If the segment has a finish date, we simply add it to the return list then continue processing.
                                    // We null the active time log for the next iteration so we know to start building a new record.
                                    if (activeTimeLog.FinishDateTimeUtc.HasValue)
                                    {
                                        completeSiteTimeLogs.Add(CloneSiteTimeLog(activeTimeLog));
                                        activeTimeLog = null;
                                    }
                                    continue;
                                }

                                // We have encountered a partial segment that we could not match to a corresponding segment.
                                // We therefore add it to the unmatched list.
                                // Note we only do this once we have encountered a Start segment, 
                                // as up to that point we could be encountring Finish segments that started outside of the selected time range.
                                if (startSegmentFound)
                                    incompleteSiteTimeLogs.Add(timeLogSegment);
                            }
                        }
                        else
                        {
                            // Active time log object is not null.
                            // This means we are looking to continue building an existing time log.

                            // This line may seem redundant ... 
                            // but when building a list of some time log types (e.g. Service (Work)), we also need to process other segment types (e.g. Site Attendance)
                            // so here we are ensuring this block of code only applies to the time log type for which we are currently building a list.
                            if (timeLogSegment.SiteTimeLogType.Id == siteTimeLogType.Id)
                            {
                                if (timeLogSegment.StartDateTimeUtc != null)
                                {
                                    // Segment has a start date.

                                    // Close off the previous active time log and add it to the return list.
                                    activeTimeLog.FinishDateTimeUtc = timeLogSegment.StartDateTimeUtc;
                                    completeSiteTimeLogs.Add(CloneSiteTimeLog(activeTimeLog));

                                    // Begin a new active time log by cloning the segment encountered.
                                    activeTimeLog = CloneSiteTimeLog(timeLogSegment);

                                    // If the segment has a finish date, we simply add it to the return list then continue processing.
                                    // We null the active time log for the next iteration so we know to start building a new record.
                                    if (activeTimeLog.FinishDateTimeUtc.HasValue)
                                    {
                                        completeSiteTimeLogs.Add(CloneSiteTimeLog(activeTimeLog));
                                        activeTimeLog = null;

                                    }
                                    continue;
                                }
                                else if (timeLogSegment.FinishDateTimeUtc != null)
                                {
                                    // Segment has no start date, but does have a finish date.

                                    // Conditional time log termination logic.
                                    if (
                                            // Project Time category or Site Attendance type - Match on Site.
                                            (
                                                (siteTimeLogType.SiteTimeLogTypeCategory.Id == Types.SiteTimeLogTypeCategory.Categories.ProjectTime.Id || siteTimeLogType.Id == Types.SiteTimeLogType.Types.SiteAttendance.Id)
                                                &&
                                                timeLogSegment.Site != null && activeTimeLog.Site != null && timeLogSegment.Site.Id == activeTimeLog.Site.Id
                                            )
                                            ||
                                            // Country Visit type - Match on Country.
                                            (
                                                siteTimeLogType.Id == Types.SiteTimeLogType.Types.CountryVisit.Id
                                                &&
                                                timeLogSegment.Country != null && activeTimeLog.Country != null && timeLogSegment.Country.Id == activeTimeLog.Country.Id
                                            )
                                            ||
                                            // Non-Project Time category and not Country Visit or Site Attendance types - No match required.
                                            (
                                                siteTimeLogType.SiteTimeLogTypeCategory.Id == Types.SiteTimeLogTypeCategory.Categories.NonProjectTime.Id
                                                &&
                                                siteTimeLogType.Id != Types.SiteTimeLogType.Types.CountryVisit.Id
                                                &&
                                                siteTimeLogType.Id != Types.SiteTimeLogType.Types.SiteAttendance.Id
                                            )
                                        )
                                    {
                                        // Set the finish date of the active time log, add it to the return list, then continue processing.
                                        // We null the active time log for the next iteration so we know to start building a new record.
                                        activeTimeLog.FinishDateTimeUtc = timeLogSegment.FinishDateTimeUtc;
                                        completeSiteTimeLogs.Add(CloneSiteTimeLog(activeTimeLog));
                                        activeTimeLog = null;

                                        continue;
                                    }
                                }

                                // We have encountered a partial segment that we could not match to a corresponding segment.
                                // We therefore add it to the unmatched list.
                                incompleteSiteTimeLogs.Add(timeLogSegment);
                            }

                            // Special scenario for when we are building a list of Service (Work) time logs, but have encountered a Site Attendance segment.
                            // This is because these additional segments are included in the processing list, as they can be used to terminate Service time logs.
                            else if (siteTimeLogType.Id == Types.SiteTimeLogType.Types.Service.Id && timeLogSegment.SiteTimeLogType.Id == Types.SiteTimeLogType.Types.SiteAttendance.Id)
                            {
                                if (timeLogSegment.StartDateTimeUtc == null && timeLogSegment.FinishDateTimeUtc != null)
                                {
                                    // Segment has no start date, but does have a finish date.

                                    // We set the finish date of the active time log, but ONLY if its Site matches that of the segment encountered.
                                    if (timeLogSegment.Site != null && activeTimeLog.Site != null && timeLogSegment.Site.Id == activeTimeLog.Site.Id)
                                    {
                                        // Set the finish date of the active time log, add it to the return list, then continue processing.
                                        // We null the active time log for the next iteration so we know to start building a new record.
                                        activeTimeLog.FinishDateTimeUtc = timeLogSegment.FinishDateTimeUtc;
                                        completeSiteTimeLogs.Add(CloneSiteTimeLog(activeTimeLog));
                                        activeTimeLog = null;

                                        continue;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Build up the return list of time logs.

            var siteTimeLogs = new List<SiteTimeLog>();

            if (returnComplete)
                siteTimeLogs.AddRange(completeSiteTimeLogs);

            if (returnIncomplete)
                siteTimeLogs.AddRange(incompleteSiteTimeLogs);

            // Non-project time logs do not have an associated country, so for these we derive this 
            // based on the last country logged by the engineer immediately prior to the segment.
            // We start by getting all site time logs for engineers within the result data set, up to the last date in the data set.
            // The reason we do this here, is because if we update the enumerated segments instead, it actually updates the persisted records!!
            var allEngineerSegments = GetAllSiteTimeLogs(
                null,
                siteTimeLogs.Select(s => s.StartDateTimeUtc).Concat(siteTimeLogs.Select(f => f.FinishDateTimeUtc)).Max(),
                new List<Guid>(),
                new List<Guid>(),
                siteTimeLogs.Select(s => s.Employee).Select(e => e.Id).Distinct().ToList()
                );

            foreach (var siteTimeLog in siteTimeLogs)
            {
                // Derive country for time logs that do not currently have one assigned.
                if (siteTimeLog.Country == null)
                {
                    var lastEngineerSegmentWithCountry = allEngineerSegments
                        .Where(e => e.Employee.Id == siteTimeLog.Employee.Id && (e.StartDateTimeUtc ?? e.FinishDateTimeUtc) < (siteTimeLog.StartDateTimeUtc ?? siteTimeLog.FinishDateTimeUtc) && e.Country != null)
                        .OrderByDescending(e => e.StartDateTimeUtc ?? e.FinishDateTimeUtc)
                        .FirstOrDefault();
                    // If no country time logs have been logged for the engineer, we simply use the engineer's current location.
                    siteTimeLog.Country = lastEngineerSegmentWithCountry != null ? lastEngineerSegmentWithCountry.Country : siteTimeLog.Employee.CurrentLocation;
                }

                // Remove seconds from the time logs.
                siteTimeLog.StartDateTimeUtc = RemoveSeconds(siteTimeLog.StartDateTimeUtc);
                siteTimeLog.FinishDateTimeUtc = RemoveSeconds(siteTimeLog.FinishDateTimeUtc);

                // Calculate local start and finish dates.
                var timeZoneInfo = (siteTimeLog.Country != null && siteTimeLog.Country.TimeZone != null) ? TimeZoneInfo.FindSystemTimeZoneById(siteTimeLog.Country.TimeZone) : TimeZoneInfo.Local;
                siteTimeLog.StartDateTimeLocal = siteTimeLog.StartDateTimeUtc != null ? TimeZoneInfo.ConvertTimeFromUtc(siteTimeLog.StartDateTimeUtc.Value, timeZoneInfo) : (DateTime?)null;
                siteTimeLog.FinishDateTimeLocal = siteTimeLog.FinishDateTimeUtc != null ? TimeZoneInfo.ConvertTimeFromUtc(siteTimeLog.FinishDateTimeUtc.Value, timeZoneInfo) : (DateTime?)null;
            }

            // Apply filters.
            // See comment in the GetAllSiteTimeLogs method which explains why some filters are applied here, rather than in the NHibernate query.

            // Note that site time log types are filtered both in the NHibernate query, as well as here.
            // This is because for certain types, additional types are sent into the NHibernate query.
            // For example, Site Attendance types are also sent in for Service time logs, as they can also be used to terminate that type of time log.
            // However we do not want to include them in the return list.
            if (siteTimeLogTypeIds.Any())
                siteTimeLogs.RemoveAll(e => siteTimeLogTypeIds.All(t => e.SiteTimeLogType != null && t != e.SiteTimeLogType.Id));

            if (countryIds.Any())
                siteTimeLogs.RemoveAll(e => countryIds.All(c => e.Country != null && c != e.Country.Id));

            if (worksOrderNumbers.Any())
                siteTimeLogs.RemoveAll(e => worksOrderNumbers.All(w => e.WorksOrder != null && w != e.WorksOrder.WoNumber));

            if (siteIds.Any())
                siteTimeLogs.RemoveAll(e => siteIds.All(s => e.Site != null && s != e.Site.Id));

            if (equipmentIds.Any())
            {
                siteTimeLogs.RemoveAll(e => equipmentIds.All(eq => e.Equipment != null && e.Equipment.ParentEquipment == null && eq != e.Equipment.Id));
                siteTimeLogs.RemoveAll(e => equipmentIds.All(eq => e.Equipment?.ParentEquipment != null && eq != e.Equipment.ParentEquipment.Id));
            }

            // Return the consolidated list.

            return siteTimeLogs
                .OrderBy(e => e.StartDateTimeUtc ?? e.FinishDateTimeUtc)
                .ToList();
        }

        /// <summary>
        /// Returns a <see cref="IList{T}">collection of <see cref="SiteTimeLog"/>s</see> derived from an initial <paramref name="siteTimeLogs">collection of complete <see cref="SiteTimeLog"/>s</paramref>, with overlapping time logs merged.
        /// </summary>
        /// <param name="siteTimeLogs">The initial <see cref="IList{T}">collection of complete <see cref="SiteTimeLog"/>s</see>.</param>
        /// <returns>A <see cref="IList{T}">collection of <see cref="SiteTimeLog"/>s</see>.</returns>
        public IList<SiteTimeLog> MergeOverlappingSiteTimeLogs(IList<SiteTimeLog> siteTimeLogs)
        {
            // Initialise a return collection.
            var mergedSiteTimeLogs = new List<SiteTimeLog>();

            // Initialise the active time log.
            SiteTimeLog activeTimeLog = null;

            foreach (var siteTimeLog in siteTimeLogs.Where(e => e.StartDateTimeLocal.HasValue && e.FinishDateTimeLocal.HasValue).OrderBy(e => e.StartDateTimeLocal.Value))
            {
                if (!siteTimeLog.StartDateTimeLocal.HasValue || !siteTimeLog.FinishDateTimeLocal.HasValue || !siteTimeLog.StartDateTimeUtc.HasValue || !siteTimeLog.FinishDateTimeUtc.HasValue)
                    continue;

                // If the active time log is null, we need to start a new time log, so clone one from the current time log being processed then move to the next time log.
                if (activeTimeLog == null)
                {
                    activeTimeLog = CloneSiteTimeLog(siteTimeLog);
                    continue;
                }

                if (!activeTimeLog.StartDateTimeLocal.HasValue || !activeTimeLog.FinishDateTimeLocal.HasValue || !activeTimeLog.StartDateTimeUtc.HasValue || !activeTimeLog.FinishDateTimeUtc.HasValue)
                    continue;

                // Active time log is not null, so we need to check it against the new time log being processed.

                // If the new time log starts before the current active time log ends, we have an overlap.
                // Update the active time log finish date to be the greater of the two finish dates, then move to the next time log to process.
                if (siteTimeLog.StartDateTimeLocal.Value < activeTimeLog.FinishDateTimeLocal.Value)
                {
                    activeTimeLog.FinishDateTimeLocal = MaxDate(activeTimeLog.FinishDateTimeLocal.Value, siteTimeLog.FinishDateTimeLocal.Value);
                    activeTimeLog.FinishDateTimeUtc = MaxDate(activeTimeLog.FinishDateTimeUtc.Value, siteTimeLog.FinishDateTimeUtc.Value);
                    continue;
                }

                // If the new time log does not start before the current active time log ends, we do not have an overlap.
                // Add the active time log to the return collection, clone a new active time log from the current time log being processed, then move to the next time log.
                mergedSiteTimeLogs.Add(activeTimeLog);

                activeTimeLog = CloneSiteTimeLog(siteTimeLog);
                continue;
            }

            // After processing the final time log, add the final active time log to the return collection.
            if (activeTimeLog != null)
                mergedSiteTimeLogs.Add(activeTimeLog);

            // Return the collection.
            return mergedSiteTimeLogs;
        }

        /// <summary>
        /// Returns a <see cref="IList{T}">collection of <see cref="SiteTimeLog"/> portions</see> that fall within the specified date range, derived from an initial <paramref name="siteTimeLogs">collection of complete <see cref="SiteTimeLog"/>s</paramref>.
        /// </summary>
        /// <param name="siteTimeLogs">The initial <see cref="IList{T}">collection of complete <see cref="SiteTimeLog"/>s</see>.</param>
        /// <param name="startDateTimeLocal">The start of the date range for which to return site time logs, matched on the local time of the site time logs.</param>
        /// <param name="endDateTimeLocal">The end of the date range for which to return site time logs, matched on the local time of the site time logs.</param>
        /// <param name="siteTimeLogTypeIds">A collection of <see cref="SiteTimeLogType"/> ids for which to return portions.</param>
        /// <param name="daysOfWeek">A collection of day of week numbers for which to return portions.</param>
        /// <param name="timeOfDayFrom">A time of day from which to return portions.</param>
        /// <param name="timeOfDayTo">A time of day to which to return portions.</param>
        /// <returns>A <see cref="IList{T}">collection of <see cref="SiteTimeLog"/> portions</see>.</returns>
        public IList<SiteTimeLog> SiteTimeLogPortionsWithinRange(IList<SiteTimeLog> siteTimeLogs, DateTime startDateTimeLocal, DateTime endDateTimeLocal, IList<Guid> siteTimeLogTypeIds, IList<DayOfWeek> daysOfWeek, TimeSpan? timeOfDayFrom, TimeSpan? timeOfDayTo)
        {
            var siteTimeLogPortions = new List<SiteTimeLog>();

            foreach (var siteTimeLog in siteTimeLogs)
            {
                // Firstly ensure that the time log actually does fall within the date range.
                if (siteTimeLog.StartDateTimeLocal <= endDateTimeLocal && siteTimeLog.FinishDateTimeLocal >= startDateTimeLocal)
                {
                    // Filter on site time log type ids (if any have been specified).
                    if (siteTimeLogTypeIds.Any() && !siteTimeLogTypeIds.Contains(siteTimeLog.SiteTimeLogType.Id))
                        continue;

                    var siteTimeLogPortion = CloneSiteTimeLog(siteTimeLog);

                    if (!siteTimeLogPortion.StartDateTimeLocal.HasValue || !siteTimeLogPortion.FinishDateTimeLocal.HasValue || !siteTimeLogPortion.StartDateTimeUtc.HasValue || !siteTimeLogPortion.FinishDateTimeUtc.HasValue)
                        continue;

                    // Calculate the offset between local and Utc time.
                    var localMinusUtcOffset = siteTimeLogPortion.StartDateTimeLocal.Value.Subtract(siteTimeLogPortion.StartDateTimeUtc.Value).TotalMilliseconds;

                    // If the site time log starts outside the date range, trim its local start date to the start of the date range.
                    if (siteTimeLogPortion.StartDateTimeLocal < startDateTimeLocal)
                    {
                        siteTimeLogPortion.StartDateTimeLocal = startDateTimeLocal;
                        // Also Set the Utc start date based on the offset calculated earlier.
                        siteTimeLogPortion.StartDateTimeUtc = siteTimeLogPortion.StartDateTimeLocal.Value.AddMilliseconds(-(localMinusUtcOffset));
                    }

                    // If the site time log finishes outside the date range, trim its local finish date to the end of the date range.
                    if (siteTimeLogPortion.FinishDateTimeLocal > endDateTimeLocal)
                    {
                        siteTimeLogPortion.FinishDateTimeLocal = endDateTimeLocal;
                        // Also Set the Utc finish date based on the offset calculated earlier.
                        siteTimeLogPortion.FinishDateTimeUtc = siteTimeLogPortion.FinishDateTimeLocal.Value.AddMilliseconds(-(localMinusUtcOffset));
                    }

                    // If either specific days of the week, or start/finish times of day, have been specified, we need to divide the time log portion into day segments.
                    // This is to allow us to handle site time logs that span multiple days.
                    if ((daysOfWeek.Any() || timeOfDayFrom != null || timeOfDayTo != null))
                    {
                        var dayPortions = new List<SiteTimeLog>();

                        // Get the date ranges for each separate day covered by the time log portion.
                        // https://stackoverflow.com/questions/28604138/linq-query-to-split-a-time-interval-into-daily-batches-with-part-days-at-start-a
                        var dayDateRanges = Enumerable.Range(0, (siteTimeLogPortion.FinishDateTimeLocal.Value.Date - siteTimeLogPortion.StartDateTimeLocal.Value.Date).Days + 1)
                            .Select(c => Tuple.Create(
                                MaxDate(siteTimeLogPortion.StartDateTimeLocal.Value.Date.AddDays(c), siteTimeLogPortion.StartDateTimeLocal.Value),
                                MinDate(siteTimeLogPortion.StartDateTimeLocal.Value.Date.AddDays(c + 1), siteTimeLogPortion.FinishDateTimeLocal.Value)
                            )).ToList();

                        // Add a new time log portion for each day covered by the original portion.
                        foreach (var dayDateRange in dayDateRanges)
                        {
                            var dayPortion = CloneSiteTimeLog(siteTimeLogPortion);

                            if (!dayPortion.StartDateTimeLocal.HasValue || !dayPortion.FinishDateTimeLocal.HasValue || !dayPortion.StartDateTimeUtc.HasValue || !dayPortion.FinishDateTimeUtc.HasValue)
                                continue;

                            // Assign the portion start and end dates to match the current date range being processed.
                            dayPortion.StartDateTimeLocal = dayDateRange.Item1;
                            dayPortion.FinishDateTimeLocal = dayDateRange.Item2;

                            // If a start and/or finish time of day has been specified, trim the day portions further still to these values.
                            if (timeOfDayFrom.HasValue)
                            {
                                if (dayPortion.StartDateTimeLocal.Value.TimeOfDay < timeOfDayFrom.Value)
                                    dayPortion.StartDateTimeLocal = new DateTime(dayPortion.StartDateTimeLocal.Value.Year, dayPortion.StartDateTimeLocal.Value.Month, dayPortion.StartDateTimeLocal.Value.Day, timeOfDayFrom.Value.Hours, timeOfDayFrom.Value.Minutes, timeOfDayFrom.Value.Seconds);
                            }
                            if (timeOfDayTo.HasValue && timeOfDayTo.Value != new TimeSpan(0, 0, 0))
                            {
                                if (dayPortion.FinishDateTimeLocal.Value.TimeOfDay > timeOfDayTo.Value|| dayPortion.FinishDateTimeLocal.Value.TimeOfDay == new TimeSpan(0, 0, 0))
                                {
                                    // Handle midnight finish date by setting the trimmed date as the previous day's date.
                                    var date = (dayPortion.FinishDateTimeLocal.Value.TimeOfDay == new TimeSpan(0, 0, 0)) 
                                        ? dayPortion.FinishDateTimeLocal.Value.AddDays(-1).Date 
                                        : dayPortion.FinishDateTimeLocal.Value.Date;
                                    dayPortion.FinishDateTimeLocal = new DateTime(date.Year, date.Month, date.Day, timeOfDayTo.Value.Hours, timeOfDayTo.Value.Minutes, timeOfDayTo.Value.Seconds);
                                }
                            }

                            // Also Set the Utc dates based on the offset calculated earlier.
                            dayPortion.StartDateTimeUtc = dayPortion.StartDateTimeLocal.Value.AddMilliseconds(-(localMinusUtcOffset));
                            dayPortion.FinishDateTimeUtc = dayPortion.FinishDateTimeLocal.Value.AddMilliseconds(-(localMinusUtcOffset));

                            // If the resulting portion is a zero or negative time span, ignore it.
                            if (dayPortion.FinishDateTimeLocal.Value.Subtract(dayPortion.StartDateTimeLocal.Value).TotalMinutes <= 0)
                                continue;

                            dayPortions.Add(dayPortion);
                        }

                        // If specific days of the week have been specified, remove any portions not covered by these.
                        if (daysOfWeek.Any())
                            dayPortions.RemoveAll(e => daysOfWeek.All(d => e.StartDateTimeLocal.HasValue && e.StartDateTimeLocal.Value.DayOfWeek != d));

                        siteTimeLogPortions.AddRange(dayPortions);
                    }
                    else
                    {
                        // If the resulting portion is a zero or negative time span, ignore it.
                        if (siteTimeLogPortion.FinishDateTimeLocal.Value.Subtract(siteTimeLogPortion.StartDateTimeLocal.Value).TotalMinutes <= 0)
                            continue;

                        siteTimeLogPortions.Add(siteTimeLogPortion);
                    }
                }
            }

            return siteTimeLogPortions;
        }

        /// <summary>
        /// Returns the <see cref="int">total hours</see> of <see cref="SiteTimeLog"/> portions that fall within the specified date range, derived from an initial <paramref name="siteTimeLogs">collection of complete <see cref="SiteTimeLog"/>s</paramref>.
        /// </summary>
        /// <param name="siteTimeLogs">The initial <see cref="IList{T}">collection of complete <see cref="SiteTimeLog"/>s</see>.</param>
        /// <param name="startDateTimeLocal">The start of the date range for which to return site time logs, matched on the local time of the site time logs.</param>
        /// <param name="endDateTimeLocal">The end of the date range for which to return site time logs, matched on the local time of the site time logs.</param>
        /// <param name="siteTimeLogTypeIds">A collection of <see cref="SiteTimeLogType"/> ids for which to return portions.</param>
        /// <param name="daysOfWeek">A collection of day of week numbers for which to return portions.</param>
        /// <param name="timeOfDayFrom">A time of day from which to return portions.</param>
        /// <param name="timeOfDayTo">A time of day to which to return portions.</param>
        /// <param name="mergeOverlapping">If set to true, overlapping <see cref="SiteTimeLog"/> portions will be merged.</param>
        /// <returns>The <see cref="int">total hours</see> of <see cref="SiteTimeLog"/> portions.</returns>
        public decimal SiteTimeLogHoursWithinRange(IList<SiteTimeLog> siteTimeLogs, DateTime startDateTimeLocal, DateTime endDateTimeLocal, IList<Guid> siteTimeLogTypeIds, IList<DayOfWeek> daysOfWeek, TimeSpan? timeOfDayFrom, TimeSpan? timeOfDayTo, bool mergeOverlapping)
        {
            // Get the site time log portions.
            var siteTimeLogPortions = SiteTimeLogPortionsWithinRange(siteTimeLogs, startDateTimeLocal, endDateTimeLocal, siteTimeLogTypeIds, daysOfWeek, timeOfDayFrom, timeOfDayTo);

            // If the 'merge overlapping' flag has been set, merge overlapping time log portions.
            if (mergeOverlapping)
                siteTimeLogPortions = MergeOverlappingSiteTimeLogs(siteTimeLogPortions);

            // Return the total calculated hours.
            return (decimal) (siteTimeLogPortions
                .Where(e => e.StartDateTimeLocal.HasValue && e.FinishDateTimeLocal.HasValue)
                .Sum(e => e.FinishDateTimeLocal.Value.Subtract(e.StartDateTimeLocal.Value).TotalHours));
        }

        /// <summary>
        /// Returns a <see cref="SiteHoursSummary"/> derived from the supplied <paramref name="siteTimeLogs">site time logs</paramref> for the specified parameters>.
        /// </summary>
        /// <param name="siteTimeLogs">The site time logs from which to generate the site hours summary.</param>
        /// <param name="startDate">The start date of the site hours summary.</param>
        /// <param name="endDate">The end date of the site hours summary.</param>
        /// <returns>A <see cref="SiteHoursSummary"/>.</returns>
        public SiteHoursSummary GenerateSiteHoursSummary(IList<SiteTimeLog> siteTimeLogs, DateTime startDate, DateTime endDate)
        {
            //////// Normal Hours ////////

            // Monday to Friday, 6am to 4pm - On Site
            var normalHours = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.Service.Id, Types.SiteTimeLogType.Types.SiteAttendance.Id },
                    new List<DayOfWeek> { DayOfWeek.Monday, DayOfWeek.Tuesday, DayOfWeek.Wednesday, DayOfWeek.Thursday, DayOfWeek.Friday },
                    new TimeSpan(6, 0, 0),
                    new TimeSpan(16, 0, 0),
                    mergeOverlapping: true
                    );

            //////// No Work/Office ////////

            // Monday to Friday, 6am to 12am - Paid Hours for No Work
            // Monday to Friday, 6am to 12am - Days of Training
            var noWorkOfficePaidNoWorkTraining = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.PaidHoursForNoWork.Id, Types.SiteTimeLogType.Types.Training.Id },
                    new List<DayOfWeek> { DayOfWeek.Monday, DayOfWeek.Tuesday, DayOfWeek.Wednesday, DayOfWeek.Thursday, DayOfWeek.Friday },
                    new TimeSpan(6, 0, 0),
                    new TimeSpan(0, 0, 0),
                    mergeOverlapping: true
                    );

            // Any Day - Paid Rest Days, College
            var noWorkOfficePaidRestDayCollege = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.PaidRestDay.Id, Types.SiteTimeLogType.Types.College.Id },
                    new List<DayOfWeek>(),
                    null,
                    null,
                    mergeOverlapping: true
                    );

            //////// Basic ////////

            // Normal Hours + No Work/Office

            //////// Breaks ////////

            // Monday to Friday only - 0.5hrs per day
            var breaks = (decimal)(SiteTimeLogPortionsWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.Service.Id, Types.SiteTimeLogType.Types.PaidHoursForNoWork.Id, Types.SiteTimeLogType.Types.Training.Id, Types.SiteTimeLogType.Types.PaidRestDay.Id, Types.SiteTimeLogType.Types.College.Id },
                    new List<DayOfWeek> { DayOfWeek.Monday, DayOfWeek.Tuesday, DayOfWeek.Wednesday, DayOfWeek.Thursday, DayOfWeek.Friday },
                    null,
                    null
                    )
                    .Where(e => e.StartDateTimeLocal.HasValue && e.FinishDateTimeLocal.HasValue && e.FinishDateTimeLocal.Value.Subtract(e.StartDateTimeLocal.Value).TotalHours > 0.5)
                    .Select(e => e.StartDateTimeLocal.Value.DayOfWeek)
                    .Distinct()
                    .Count() * 0.5);

            //////// Basic Total (minus Breaks) ////////

            // Basic minus Breaks

            //////// O/T at 1.33 ////////

            // Monday to Friday, 4pm to 12am (if Basic Total & Travel time > 9.5hrs a day) - On Site, Days of Training
            decimal overtimeAt1Point33 = 0;
            var days = new List<DayOfWeek> { DayOfWeek.Monday, DayOfWeek.Tuesday, DayOfWeek.Wednesday, DayOfWeek.Thursday, DayOfWeek.Friday };
            foreach (var day in days)
            {
                // Firstly we calculate the Basic Total plus Travel Time for each day in turn.
                var normalHoursDailyTotal = SiteTimeLogHoursWithinRange(
                                    siteTimeLogs,
                                    startDate,
                                    endDate,
                                    new List<Guid> { Types.SiteTimeLogType.Types.Service.Id, Types.SiteTimeLogType.Types.SiteAttendance.Id },
                                    new List<DayOfWeek> { day },
                                    new TimeSpan(6, 0, 0),
                                    new TimeSpan(16, 0, 0),
                                    mergeOverlapping: true
                                    );
                var noWorkOfficeTravelDailyTotal = SiteTimeLogHoursWithinRange(
                                    siteTimeLogs,
                                    startDate,
                                    endDate,
                                    new List<Guid> { Types.SiteTimeLogType.Types.PaidHoursForNoWork.Id, Types.SiteTimeLogType.Types.Training.Id, Types.SiteTimeLogType.Types.PaidRestDay.Id, Types.SiteTimeLogType.Types.College.Id, Types.SiteTimeLogType.Types.TravelTime.Id },
                                    new List<DayOfWeek> { day },
                                    null,
                                    null,
                                    mergeOverlapping: true
                                    );
                // Next we calculate the evening hours daily total for each day in turn.
                var eveningHoursTotal = SiteTimeLogHoursWithinRange(
                                    siteTimeLogs,
                                    startDate,
                                    endDate,
                                    new List<Guid> { Types.SiteTimeLogType.Types.Service.Id, Types.SiteTimeLogType.Types.Training.Id },
                                    new List<DayOfWeek> { day },
                                    new TimeSpan(16, 0, 0),
                                    new TimeSpan(0, 0, 0),
                                    mergeOverlapping: true
                                    );
                // Finally, we only apply the overtime to the evening hours if the Basic Total plus Travel Time (not forgetting to subtract the daily break value!) is greater than 9.5 hours
                // otherwise the evening hours are simply counted as Normal Hours.
                if ((normalHoursDailyTotal + noWorkOfficeTravelDailyTotal - (decimal)(0.5)) > OverTimeAt1Point33HoursThreshold)
                    overtimeAt1Point33 = overtimeAt1Point33 + eveningHoursTotal;
                else
                    normalHours = normalHours + eveningHoursTotal;
            }

            //////// O/T at 1.50 ////////

            // Saturday, except 12am to 6am - On Site, Paid Hours For No Work, Days of Training
            var overtimeAt1Point50 = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.Service.Id, Types.SiteTimeLogType.Types.PaidHoursForNoWork.Id, Types.SiteTimeLogType.Types.Training.Id },
                    new List<DayOfWeek> { DayOfWeek.Saturday },
                    new TimeSpan(6, 0, 0),
                    new TimeSpan(0, 0, 0),
                    mergeOverlapping: true
                    );

            //////// O/T at 2.00 ////////

            // Sunday - On Site, Paid Hours For No Work, Days of Training
            var overtimeAt2Point00Sunday = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.Service.Id, Types.SiteTimeLogType.Types.PaidHoursForNoWork.Id, Types.SiteTimeLogType.Types.Training.Id },
                    new List<DayOfWeek> { DayOfWeek.Sunday },
                    null,
                    null,
                    mergeOverlapping: true
                    );

            // All week, 12am to 6am - On Site, Paid Hours For No Work, Days of Training
            var overtimeAt2Point00AllWeek = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.Service.Id, Types.SiteTimeLogType.Types.PaidHoursForNoWork.Id, Types.SiteTimeLogType.Types.Training.Id },
                    new List<DayOfWeek> { DayOfWeek.Monday, DayOfWeek.Tuesday, DayOfWeek.Wednesday, DayOfWeek.Thursday, DayOfWeek.Friday, DayOfWeek.Saturday },
                    new TimeSpan(0, 0, 0),
                    new TimeSpan(6, 0, 0),
                    mergeOverlapping: true
                    );

            //////// Travel ////////

            // Monday - Friday - Travel Time
            var travel = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.TravelTime.Id },
                    new List<DayOfWeek> { DayOfWeek.Monday, DayOfWeek.Tuesday, DayOfWeek.Wednesday, DayOfWeek.Thursday, DayOfWeek.Friday },
                    null,
                    null,
                    mergeOverlapping: true
                    );

            //////// Travel x 1.5 ////////

            // Saturday - Travel Time
            var travelAt1Point50 = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.TravelTime.Id },
                    new List<DayOfWeek> { DayOfWeek.Saturday },
                    null,
                    null,
                    mergeOverlapping: true
                    );

            //////// Travel x 2 ////////

            // Sunday - Travel Time
            var travelAt2Point00 = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.TravelTime.Id },
                    new List<DayOfWeek> { DayOfWeek.Sunday },
                    null,
                    null,
                    mergeOverlapping: true
                    );

            //////// Holiday Pay ////////

            // Annual Leave
            var holidayPay = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.AnnualLeave.Id },
                    new List<DayOfWeek>(),
                    null,
                    null,
                    mergeOverlapping: true
                    );

            //////// Site Subs ////////

            // Site Subs (UK)
            var siteSubs = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.SiteSubsUk.Id },
                    new List<DayOfWeek>(),
                    null,
                    null,
                    mergeOverlapping: true
                    );

            //////// Site Subs Abroad ////////

            // Site Subs (Outside UK)
            var siteSubsAbroad = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.SiteSubsOutsideUk.Id },
                    new List<DayOfWeek>(),
                    null,
                    null,
                    mergeOverlapping: true
                    );

            //////// Standby ////////

            // Standby
            var standby = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.Standby.Id },
                    new List<DayOfWeek>(),
                    null,
                    null,
                    mergeOverlapping: true
                    );

            //////// Site Closed ////////

            // Site Closed
            var siteClosed = SiteTimeLogHoursWithinRange(
                    siteTimeLogs,
                    startDate,
                    endDate,
                    new List<Guid> { Types.SiteTimeLogType.Types.SiteClosed.Id },
                    new List<DayOfWeek>(),
                    null,
                    null,
                    mergeOverlapping: true
                    );

            var siteTimeSheetSummary = new SiteHoursSummary
            {
                NormalHours = normalHours,
                NoWorkOffice = noWorkOfficePaidNoWorkTraining + noWorkOfficePaidRestDayCollege,
                Basic = normalHours + noWorkOfficePaidNoWorkTraining + noWorkOfficePaidRestDayCollege,
                Breaks = breaks,
                BasicTotalMinusBreaks = (normalHours + noWorkOfficePaidNoWorkTraining + noWorkOfficePaidRestDayCollege) - breaks,
                OtAt1Point33 = overtimeAt1Point33,
                OtAt1Point50 = overtimeAt1Point50,
                OtAt2Point00 = overtimeAt2Point00Sunday + overtimeAt2Point00AllWeek,
                Travel = travel,
                TravelAt1Point50 = travelAt1Point50,
                TravelAt2Point00 = travelAt2Point00,
                HolidayPay = holidayPay,
                SiteSubs = siteSubs,
                SiteSubsAbroad = siteSubsAbroad,
                Standby = standby,
                SiteClosed = siteClosed
            };

            return siteTimeSheetSummary;
        }

        /// <summary>
        /// Returns a <see cref="IList{T}">collection of all <see cref="SiteTimeLog"/>s</see> for the specified parameters.
        /// </summary>
        /// <param name="startDateTimeUtc">The start of the date range for which to return site time logs.</param>
        /// <param name="endDateTimeUtc">The end of the date range for which to return site time logs.</param>
        /// <param name="siteTimeLogTypeCategoryIds">A collection of <see cref="SiteTimeLogTypeCategory"/> ids for which to return site time logs.</param>
        /// <param name="siteTimeLogTypeIds">A collection of <see cref="SiteTimeLogType"/> ids for which to return site time logs.</param>
        /// <param name="employeeIds">A collection of <see cref="Employee"/> ids for which to return site time logs.</param>
        /// <returns>A <see cref="IList{T}">collection of all <see cref="SiteTimeLog"/>s</see>.</returns>
        private IList<SiteTimeLog> GetAllSiteTimeLogs(DateTime? startDateTimeUtc, DateTime? endDateTimeUtc, IList<Guid> siteTimeLogTypeCategoryIds, IList<Guid> siteTimeLogTypeIds, IList<int> employeeIds)
        {
            SiteTimeLog siteTimeLogAlias = null;
            SiteTimeLogType siteTimeLogTypeAlias = null;
            SiteTimeLogTypeCategory siteTimeLogTypeCategoryAlias = null;
            Employee employeeAlias = null;
            Domain.Countries.Country countryAlias = null;
            Domain.WorksOrders.WorksOrder worksOrderAlias = null;
            Domain.Branches.Branch siteAlias = null;
            Domain.Equipments.Equipment equipmentAlias = null;
            Domain.ProductionSchedules.ProductionSchedule productionScheduleAlias = null;
            Domain.Organisations.Organisation organisationAlias = null;
            Domain.Countries.Country currentLocationAlias = null;
            var query = CurrentSession.QueryOver(() => siteTimeLogAlias)
                                         .JoinAlias(() => siteTimeLogAlias.SiteTimeLogType, () => siteTimeLogTypeAlias)
                                         .JoinAlias(() => siteTimeLogTypeAlias.SiteTimeLogTypeCategory, () => siteTimeLogTypeCategoryAlias)
                                         .JoinAlias(() => siteTimeLogAlias.Employee, () => employeeAlias)
                                         .JoinAlias(() => siteTimeLogAlias.Country, () => countryAlias, JoinType.LeftOuterJoin)
                                         .JoinAlias(() => siteTimeLogAlias.WorksOrder, () => worksOrderAlias, JoinType.LeftOuterJoin)
                                         .JoinAlias(() => siteTimeLogAlias.Site, () => siteAlias, JoinType.LeftOuterJoin)
                                         .JoinAlias(() => siteTimeLogAlias.Equipment, () => equipmentAlias, JoinType.LeftOuterJoin)
                                         .JoinAlias(() => equipmentAlias.ProductionSchedule, () => productionScheduleAlias, JoinType.LeftOuterJoin)
                                         .JoinAlias(() => employeeAlias.Organisation, () => organisationAlias, JoinType.LeftOuterJoin)
                                         .JoinAlias(() => employeeAlias.CurrentLocation, () => currentLocationAlias, JoinType.LeftOuterJoin);

            // Apply filters.

            // Note that some filters (e.g. Site) have to be applied to the result set rather than in the NHibernate query,
            // as otherwise some reconstructed time logs would be incorrectly filtered out of the results.
            // For example, where two concurrent Site Start time logs result in a Finish terminator being applied to the first,
            // if the second Site is filtered out of the SQL results, the first log will remain unterminated and therefore not be returned in the result set.

            if (startDateTimeUtc.HasValue)
                query = query.Where(() => siteTimeLogAlias.StartDateTimeUtc >= startDateTimeUtc.Value || siteTimeLogAlias.FinishDateTimeUtc >= startDateTimeUtc.Value);

            if (endDateTimeUtc.HasValue)
                query = query.Where(() => siteTimeLogAlias.StartDateTimeUtc <= endDateTimeUtc.Value || siteTimeLogAlias.FinishDateTimeUtc <= endDateTimeUtc.Value);

            if (siteTimeLogTypeCategoryIds.Any())
                query = query.WhereRestrictionOn(() => siteTimeLogTypeCategoryAlias.Id).IsIn(siteTimeLogTypeCategoryIds.ToList());

            if (siteTimeLogTypeIds.Any())
            {
                var siteTimeLogTypeIdsConsolidated = new List<Guid>();
                siteTimeLogTypeIdsConsolidated.AddRange(siteTimeLogTypeIds);
                // If we are processing Service (Work) time logs, we also want to query for Site Attendance time logs
                // as these are also used to terminate open Service logs.
                if (siteTimeLogTypeIds.Contains(Types.SiteTimeLogType.Types.Service.Id))
                    siteTimeLogTypeIdsConsolidated.Add(Types.SiteTimeLogType.Types.SiteAttendance.Id);
                query = query.WhereRestrictionOn(() => siteTimeLogTypeAlias.Id).IsIn(siteTimeLogTypeIdsConsolidated.ToList());
            }

            if (employeeIds.Any())
                query = query.WhereRestrictionOn(() => employeeAlias.Id).IsIn(employeeIds.ToList());

            return query.List();
        }

        /// <summary>
        /// Returns a clone of the <paramref name="siteTimeLog">site time log</paramref>.
        /// </summary>
        /// <param name="siteTimeLog">The site time log to clone.</param>
        /// <returns>A cloned <see cref="SiteTimeLog"/>.</returns>
        private static SiteTimeLog CloneSiteTimeLog(SiteTimeLog siteTimeLog)
        {
            return new SiteTimeLog
            {
                Id = siteTimeLog.Id,
                SiteTimeLogType = siteTimeLog.SiteTimeLogType,
                Employee = siteTimeLog.Employee,
                Country = siteTimeLog.Country,
                WorksOrder = siteTimeLog.WorksOrder,
                Site = siteTimeLog.Site,
                Equipment = siteTimeLog.Equipment,
                StartDateTimeUtc = siteTimeLog.StartDateTimeUtc,
                FinishDateTimeUtc = siteTimeLog.FinishDateTimeUtc,
                StartDateTimeLocal = siteTimeLog.StartDateTimeLocal,
                FinishDateTimeLocal = siteTimeLog.FinishDateTimeLocal
            };

        }

        /// <summary>
        /// Recalculates the <see cref="employee"/>'s current location based on their most recent Country Arrival time log.
        /// </summary>
        /// <param name="employee">The employee to recalculate the current location for.</param>
        private void UpdateEmployeeCurrentLocation(Employee employee)
        {
            var countryChanges = CurrentSession.QueryOver<SiteTimeLog>()
                .Where(
                    e =>
                        e.Employee.Id == employee.Id &&
                        e.SiteTimeLogType.Id == Types.SiteTimeLogType.Types.CountryVisit.Id &&
                        e.StartDateTimeUtc != null)
                .OrderBy(e => e.StartDateTimeUtc).Desc
                .List();

            // Update the employee's current location to be the country from their most recent Arrival.
            if (countryChanges.Any())
            {
                employee.CurrentLocation = countryChanges.First().Country;
                CurrentSession.SaveOrUpdate(employee);
            }
        }

        /// <summary>
        /// Sets the seconds of the supplied <paramref name="dateTime">date time object</paramref> to zero.
        /// </summary>
        /// <param name="dateTime">The original date time object</param>.
        /// <returns>The modified <paramref name="dateTime">date time object</paramref>.</returns>
        protected static DateTime? RemoveSeconds(DateTime? dateTime)
        {
            return dateTime?.AddSeconds(-dateTime.Value.Second);
        }

        /// <summary>
        /// Returns the minimum of the two date parameters <paramref name="dateTime1"/> and <paramref name="dateTime2"/>.
        /// </summary>
        /// <param name="dateTime1">The first date to compare.</param>
        /// <param name="dateTime2">The second date to compare.</param>
        /// <returns>The minimum of the two date parameters <paramref name="dateTime1"/> and <paramref name="dateTime2"/>.</returns>
        private static DateTime MinDate(DateTime dateTime1, DateTime dateTime2)
        {
            if (dateTime1 > dateTime2)
                return dateTime2;
            return dateTime1;
        }

        /// <summary>
        /// Returns the maximum of the two date parameters <paramref name="dateTime1"/> and <paramref name="dateTime2"/>.
        /// </summary>
        /// <param name="dateTime1">The first date to compare.</param>
        /// <param name="dateTime2">The second date to compare.</param>
        /// <returns>The maximum of the two date parameters <paramref name="dateTime1"/> and <paramref name="dateTime2"/>.</returns>
        private static DateTime MaxDate(DateTime dateTime1, DateTime dateTime2)
        {
            if (dateTime1 < dateTime2)
                return dateTime2;
            return dateTime1;
        }
    }
}