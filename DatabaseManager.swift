import Foundation
import SQLite3

class DatabaseManager {

    init()
    {
        db = openDatabase()
    }

    var db:OpaquePointer?

    // MARK: - Database

    func databasePath() -> URL {
        let appSettings = AppSettings()
        let documentsDirectoryPath = appSettings.documentsDirectoryPath
        let databasePath = documentsDirectoryPath.appendingPathComponent(appSettings.databaseFile.path)
        return databasePath
    }

    func openDatabase() -> OpaquePointer?
    {
        var db: OpaquePointer? = nil
        if sqlite3_open(self.databasePath().path, &db) != SQLITE_OK
        {
            print("error opening database")
            return nil
        }
        else
        {
            print("Successfully opened connection to database at \(self.databasePath().path)")
            return db
        }
    }
    
    // MARK: - Registered Users
    
    func getRegisteredUsers() -> [User] {
        let queryStatementString = "SELECT \(DatabaseDefinitions.TableRegisteredUserColumnId), \(DatabaseDefinitions.TableRegisteredUserColumnUserName) FROM \(DatabaseDefinitions.TableRegisteredUser)"
        return getRegisteredUserData(queryStatementString: queryStatementString)
    }

    func getRegisteredUser(id: String) -> User? {
        let queryStatementString = "SELECT \(DatabaseDefinitions.TableRegisteredUserColumnId), \(DatabaseDefinitions.TableRegisteredUserColumnUserName) FROM \(DatabaseDefinitions.TableRegisteredUser) WHERE \(DatabaseDefinitions.TableRegisteredUserColumnId) = '\(id)'"
        let registeredUsers = getRegisteredUserData(queryStatementString: queryStatementString)
        if registeredUsers.count > 0 {
            return getRegisteredUserData(queryStatementString: queryStatementString)[0]
        }
        return nil
    }
    
    func getRegisteredUserData(queryStatementString: String) -> [ User ] {
        var queryStatement: OpaquePointer? = nil
        var results = [User]()
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = String(describing: String(cString: sqlite3_column_text(queryStatement, 0)))
                let userName = String(describing: String(cString: sqlite3_column_text(queryStatement, 1)))
                results.append(User(id: id, userName: userName))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        
        return results
    }
    
    func createRegisteredUser(user: User) {
        let sql = "INSERT INTO \(DatabaseDefinitions.TableRegisteredUser) (\(DatabaseDefinitions.TableRegisteredUserColumnId), \(DatabaseDefinitions.TableRegisteredUserColumnUserName)) VALUES ('\(user.Id)', '\(user.UserName)')"
        var insertStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, sql, -1, &insertStatement, nil) == SQLITE_OK {
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Successfully inserted row.")
            } else {
                print("Could not insert row.")
            }
        } else {
            print("INSERT statement could not be prepared.")
        }
        sqlite3_finalize(insertStatement)
    }

    func updateRegisteredUser(user: User) {
        let sql = "UPDATE \(DatabaseDefinitions.TableRegisteredUser) SET \(DatabaseDefinitions.TableRegisteredUserColumnUserName) = '\(user.UserName)' WHERE \(DatabaseDefinitions.TableRegisteredUserColumnId) = '\(user.Id)'"
        var updateStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, sql, -1, &updateStatement, nil) == SQLITE_OK {
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("Successfully updated row.")
            } else {
                print("Could not update row.")
            }
        } else {
            print("UPDATE statement could not be prepared.")
        }
        sqlite3_finalize(updateStatement)
    }
    
    func deleteRegisteredUsers() {
        let sql = "DELETE FROM \(DatabaseDefinitions.TableRegisteredUser)"
        var deleteStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, sql, -1, &deleteStatement, nil) == SQLITE_OK {
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                print("Successfully deleted rows.")
            } else {
                print("Could not delete rows.")
            }
        } else {
            print("DELETE statement could not be prepared")
        }
        sqlite3_finalize(deleteStatement)
    }

    func deleteRegisteredUser(user: User) {
        let sql = "DELETE FROM \(DatabaseDefinitions.TableRegisteredUser) WHERE \(DatabaseDefinitions.TableRegisteredUserColumnId) = '\(user.Id)'"
        var deleteStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, sql, -1, &deleteStatement, nil) == SQLITE_OK {
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                print("Successfully deleted rows.")
            } else {
                print("Could not delete rows.")
            }
        } else {
            print("DELETE statement could not be prepared")
        }
        sqlite3_finalize(deleteStatement)
    }
}
