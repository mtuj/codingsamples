import Foundation

class User: Codable {
    // Model definition for a User object.

    var Id : String
    var UserName : String

    /// Initialiser by Id.
    init?(_ id: String) {
	// By passing an id, by convention we are loading the object from the Sqlite database.
        let databaseManager = DatabaseManager()
        if let user = databaseManager.getRegisteredUser(id: id) {
            self.Id = user.Id
            self.UserName = user.UserName
        } else {
	    // No persisted record found so return nil.
            return nil
        }
    }

    /// Initialiser by Id (optional) and Name.
    init(id: String? = nil, userName: String) {
	// Populate the object with the supplied properties.
        if let id = id {
            Id = id
        } else {
	    // If no id supplied, generate a new UUID.
            Id = UUID().uuidString
        }
        UserName = userName
    }
    
    /// Save the User object.
    func save() {
        let databaseManager = DatabaseManager()
        if databaseManager.getRegisteredUser(id: self.Id) != nil {
	    // Record exists in the Sqlite database, so update.
            databaseManager.updateRegisteredUser(user: self)
        } else {
	    // No record exists in the Sqlite database, so create.
            databaseManager.createRegisteredUser(user: self)
        }
    }

    /// Delete  the User object from the database.
    func delete() {
        let databaseManager = DatabaseManager()
        databaseManager.deleteRegisteredUser(user: self)
    }
}
