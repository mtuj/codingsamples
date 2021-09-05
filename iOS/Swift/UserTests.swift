import XCTest

class UserTests: XCTestCase {

    var users = [ User ]()
    let userCount = Int.random(in: 5..<10)
    
    /// Set up test data.
    override func setUp()
    {
        // Generate a number of random users and save them in the database.
        for _ in 0...(userCount - 1) {
            let user = User(userName: String.randomText)
            user.save()
            self.users.append(user)
        }
    }

    /// Tear down test data.
    override func tearDown()
    {
        // Remove all randomly generated users from the database.
        for user in self.users {
            user.delete()
        }
    }

    /// A test to verify that a user can be loaded from the database.
    func testCanGetUser()
    {
        // Get a random user from the array.
        guard let user = self.users.randomElement() else {
            XCTFail("Random user retrieval failed.")
            return
        }
        
        // Load the user from the database.
        guard let userFromDatabase = User(user.Id) else {
           XCTFail("Load user from database failed.")
           return
       }
        
        // Verify the loaded user has the expected properties.
        XCTAssertEqual(user.Id, userFromDatabase.Id)
        XCTAssertEqual(user.UserName, userFromDatabase.UserName)
    }

    /// A test to verify that a user can be created and persisted to the database.
    func testCanCreateUser()
    {
        // Create and save a new user.
        let user = User(userName: String.randomText)
        user.save()

         // Load the user from the database.
         guard let userFromDatabase = User(user.Id) else {
            XCTFail("Load user from database failed.")
            return
        }

        // Verify the loaded user has the expected properties.
        XCTAssertEqual(user.Id, userFromDatabase.Id)
        XCTAssertEqual(user.UserName, userFromDatabase.UserName)
    }
    
    /// A test to verify that a user can be updated and persisted to the database.
    func testCanUpdateUser()
    {
        // Create and save a new user.
        let user = User(userName: String.randomText)
        user.save()
        
        // Capture the user properties before modification.
        let userNameOriginal = user.UserName
        
        // Modify the user properties and save.
        user.UserName = String.randomText
        user.save()

         // Load the user from the database.
         guard let userFromDatabase = User(user.Id) else {
            XCTFail("Load user from database failed.")
            return
        }

        // Verify the loaded user has the expected properties.
        XCTAssertEqual(user.Id, userFromDatabase.Id)
        XCTAssertEqual(user.UserName, userFromDatabase.UserName)

        // Verify the loaded user does not have the original properties.
        XCTAssertNotEqual(userNameOriginal, userFromDatabase.UserName)
    }
    
    /// A test to verify that a user can be deleted from the database.
    func testCanDeleteUser()
    {
        // Create and save a new user.
        let user = User(userName: String.randomText)
        user.save()
        
         // Load the user from the database.
        guard User(user.Id) != nil else {
            XCTFail("Load user from database failed.")
            return
        }

        // Delete the user from the database.
        user.delete()
        
        // Attempt to load the user from the database and confirm it is nil.
        XCTAssertNil(User(user.Id))
    }
}
