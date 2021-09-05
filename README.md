This repository contains a sample of classes, scripts and documents that I have written during the past few years.

Hopefully this will be useful in demonstrating the languages I am familiar with, my coding style, and the typical level of complexity of the systems I would normally work on.

Please use the **Code** > **Download ZIP** option to download this repository, which I have arranged into subdirectories. A brief overview of each file can be found below.

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
* A task I wrote for a developer to add create and update domain model objects, including ORM mappings to related database tables.

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
* TBC

cleartobuild.js
* TBC

# SQL

Schema update script.sql
* TBC

Data update script.sql
* TBC

Data manipulation script.sql
* TBC

Data import script.sql
* TBC

# iOS

### Objective-C

AppDelegate.m
* TBC

ApiManager.m
* TBC

DatabaseManager.m
* TBC

OAuthManager.m
* TBC

TestSessionDetailsViewController.m
* TBC

### Swift

OAuthManager.swift
* TBC

User.swift
* TBC

UserTests.swift
* TBC

ProfilesViewController.swift
* TBC

ProfileTableViewCell.swift
* TBC

# Classic ASP

outlet-configuration.asp
* TBC
