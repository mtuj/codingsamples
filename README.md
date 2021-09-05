This repository contains a sample of classes, scripts and documents that I have written during the past few years.

Hopefully this will be useful in demonstrating the languages I am familiar with, my coding style, and the typical level of complexity of the systems I would normally work on.

Please use the **Code** > **Download ZIP** option to download this repository, which I have arranged into subdirectories. A brief overview of each file can be found below.

Mark Jackson


# Documentation

Project System Requirements document.docx
* A functional specification I wrote for a large-scale project covering several modules in an in-house ERP system. This was a project I also implemented and wrote the code for; had this been distributed to other developers to work on instead, an additional technical specification would also been produced alongside this document.

iOS Engineer App User Guide.pdf
* A user guide I produced for an in-house iOS app that I wrote. The app is used primarily by site-based engineers for logging site visits, updating details of installed equipment, completing electronic testing documentation, and submitting time logs. I have also produced similar guides for four other in-house apps.

iOS app development summary.pdf
* A brief summary covering the in-house iOS apps I have written, including screenshots of some of the key screens.

### JIRA Tasks

*A sample of the detail sections of some JIRA tasks I have written while mentoring junior developers.*

JIRA task - VIS-3180 - Core coding task.pdf
* A task I wrote for a developer to create and update domain model objects, including ORM mappings to related database tables.

JIRA task - VIS-3435 - Code refactor (With code review feedback).pdf
* A task for a developer to refactor a collection of "building block" helper methods in a business logic class, in preparation for usage elsewhere in the system. This task was one small part of a large project, so this requirement was one element in a much wider structured system architecture plan. (Typically my role involves scoping out the full technical architecture at a high level, then breaking tasks down in manageable portions for a developer.) This task also includes some typical code review feedback I am usually required to provide back to the assignee.

JIRA task - VIS-3498 - Integration test.pdf
* A task for a developer to write an integration test to verify a specific area of functionality. For this task detail I used a standard template that includes wider guidance on test driven development in general, as well as some of the more specific system features. The developer is provided with suggested parameters for the key business logic method call, as well as expected outputs; they are expected to write the test first, then implement the logic to satisfy the requirements.

JIRA task - VIS-4056 - Integration tests.pdf
* A task for a developer to write a series of integration tests. This is for a developer who is a little more familiar with how unit testing works, so does not provide as much guidance on the basics as the previous task; however it does provide the required detail on the data and logic-specific elements of the process that is being tested.

JIRA task - VIS-4057 - System test.pdf
* A task to guide a developer through a manual testing run of new functionality. This may be required when the assignee has completed some business logic changes and associated unit testing, but may not be as familiar with how the full system will be affected in context, so tasks like this can sometimes be worded more in the form of a user guide than an outright technical task.

# C#.Net

### Business Logic

FileSystemServices.cs
* An API application service class providing a number of common reusable helper methods, related specifically to file system operations. Note that this class makes use of **dependency injection** to provide access to other similar classes (in this case, EmailServices). Dependency injection is accomplished by passing an associated interface that the consumed service implements (e.g. IEmailServices) as a parameter into the constructor of the consuming class; a similar chaining of dependencies is then also performed in the constructors of any consumed services, meaning that they can be made available for use - with all dependencies instantly resolved - simply and quickly.

SiteTimeLogServices.cs
* An API application service class providing methods specific to time log data logged by site engineers (synced to the system from an iOS app via a REST-based web service). The key method is GetConsolidatedSiteTimeLogs which is used to construct complete site time logs on-the-fly from disconnected start and end logs; these complete time log entities are then used by other methods in the same class, such as GenerateSiteHoursSummary which is used to process the records and return an overall summary of time sheet data, based on which hours fall within certain pre-set periods related to different HR pay levels (such as double time and 1.5 time).

TestSessionServices.cs
* An API application service class used to process submitted data relating to electronic test certificates. This class includes a number of file system operations (so calls the FileSystemServices class detailed above). The data payload typically includes PDF documents (synced from iOS apps as base 64-encoded strings), so this class includes code for interrogating and modifying the data contained within the submitted PDF document.

### Integration Tests

*A sample of integration tests I have written for testing several elements of the core API. These are unit tests, but as well as testing the core functionality they also verify the persisted data, as most of the processes I work on have a key reliance on verified data integrity.*

DocumentNHibernateRawTests.cs
* A suite of integration tests for verifying the core functionality of the NHibernate ORM, specifically relating to Document data and Blob storage.

UpdateTestSessionTests.cs
* A suite of integration tests for testing the updating of Test Session data (electronic test documentation) by the TestSessionServices class. This is a particularly detailed and complex set of tests as the data in question is of a critical nature, and system operation has to be reliably verifiable following any key system updates. Note that this class relates just to the updating of electronic test documentation data; similar separate suites of tests have also been written to handle creation and retrieval of data, with further classes also written for testing other related data sets.

CreateProductionJobTests.cs
* A suite of integration tests for testing the automatic generation of batches of data for a proprietary in-house production system; unlike the other test suites listed (which test against standard REST CRUD methods), these tests relate to CQRS functionality (where a custom Command object is populated with parameters specific to a particular data operation, then processed by a custom business logic class).

### ORM Mapping

WorksOrderMapping.cs
* An example of an NHibernate ORM mapping class, demonstrating how I would typically map the properties of a domain model object to corresponding database table fields; in some cases more complex formula mappings are used, which involve more detailed SQL statements to be implemented.

# JavaScript

uploader.js
* A JavaScript file I wrote utilising the BackBone MVC framework, for providing front-end functionality for an in-house multi-file uploader screen. Backbone scripts typically work in tandem with an associated CSHTML file that contains view template elements, which are rendered using data provided by the JavaScript component. Unlike the files detailed above, this set of classes typically lives within a separate UI solution, and consumes / updates data via an associated REST API.

cleartobuild.js
* A JavaScript file I wrote utilising the Telerik KendoUI MVVM framework. This is also a UI solution file, and is used to display data relating to stock and procurement, and used to display the percentage of ordered parts that have been received for specific production lines in a factory. Most JavaScript work I now undertake is in KendoUI, and again relies on a related CSHTML template definition file.

# SQL

Schema update script.sql
* A standard script written to perform a schema update of the core SQL database upon release of a specific new version.

Data update script.sql
* A standard script written to perform a data update of the core SQL database upon release of a specific new version. Typically this will be run just after a related schema update.

Data manipulation script.sql
* A one-off script I was asked to write to target and manipulate data logged by an in-house iOS time logging app. The requirement here was to split out and redistribute blocks of logged time to different time slots, but without overlapping any existing populated time log periods for each affected employee.

Data import script.sql
* A script I wrote to parse data from an Excel spreadsheet, convert to the correct data types, and consolidate to existing data stored within the central SQL database. I have often been required to write similar import routines, all of which tend to use the same OLE DB provider functionality to harvest the raw data, before employing custom scripts to then manipulate the imported data as required.

# iOS

### Objective-C

*A sample of iOS code I have written using the Objective-C language. I have been programming iOS apps using this language for many years, and have produced a number of in-house production apps to date.*

AppDelegate.m
* The delegate class that responds to key system and app events, such as launch complete, device entering sleep mode, memory warning detected, and so on.

ApiManager.m
* A common helper class used to handle API operations, including sending data and processing payloads received. This class typically contains first-stage handling of errors and unsuccessful status codes.

DatabaseManager.m
* A common helper class used to handle database CRUD operations. Most iOS apps I have worked on include local Sqlite database to faciliate offline working, so this is a typical file that I would include in any such app. This class makes use of a third-party library called FMDB for Sqlite read and write operations; the methods generally have a similar format throughout the file as they deal with similar operations, but on different database tables. The convention is that data dictionary and/or array objects are passed to and from the methods, with the methods then taking care of any data retrieval and persistence functionality.

OAuthManager.m
* A common helper class used to generate the authorisation headers required by the OAuth protocol, which the iOS app and API both conform to.

TestSessionDetailsViewController.m
* A view controller class used for handling data related to electronic test documentation. Test documents are displayed and edited within the app, then upon committing changes the PDF form data is captured and processed within this file. As such this is a particularly detailed controller class, with a number of handler methods dedicated to the processing of data specific to known documents, test numbers, and test types.

### Swift

*A sample of iOS code I have written using the Swift language. Although most of the production apps I have written are in Objective-C, I have been working on converting these to Swift as a personal project.*

OAuthManager.swift
* A common helper class used to generate the authorisation headers required by the OAuth protocol, which the iOS app and API both conform to.

User.swift
* A standard model class, which I am implementing in the Swift version of the apps to replace the previous convention of utilising data dictionaries to represent domain objects.

UserTests.swift
* A set of unit tests relating to a particular model class.

ProfilesViewController.swift
* A view controller I wrote for a demo app, designed to display data relating to account profiles in a scrolling table view.

ProfileTableViewCell.swift
* A class for generating a custom table view cell, used by the ProfilesViewController class described above.

# Classic ASP

outlet-configuration.asp
* A class written for an older legacy Classic ASP system. This consists of an HTML page with a number of dynamic elements generated from VBScript variables. SQL read and write statements are performed within the page, with the scripts (by convention) contained within the main body of the code.
