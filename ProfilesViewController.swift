import UIKit

class ProfilesViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, ApiDelegate {
    
    // MARK: - Constants

    let verticalPadding = 20.0
    let horizontalPadding = 20.0
    
    let heightErrorLabel = 80.0
    let heightReloadButton = 50.0

    // MARK: - Properties

    var profilesTableView: UITableView = UITableView.init(frame: CGRect.zero, style: .grouped)
    var errorContainer = UIView()
    var profiles = [Profile]()
    var topRating: Int?

    // MARK: - View Management

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get the logo image.
        let logo = UIImage(named: "Logo")

        // Let's resize the image to fit the navigation bar.
        let size: CGSize = CGSize(width: 120, height: 120)
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        logo?.draw(in: rect)
        let logo75 = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Set the navigation title as the resized image.
        let imageView = UIImageView(image: logo75)
        imageView.contentMode = .scaleAspectFill
        self.navigationItem.titleView = imageView

        // Options button on the navigation bar.
        // For the purposes of our demo, this has not action.
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Options", style: .plain, target: self, action: nil)
        
        // Set up the table view.
        self.profilesTableView.applyDefaultStyle()
        self.profilesTableView.backgroundColor = .none
        self.profilesTableView.separatorStyle = .none
        self.profilesTableView.dataSource = self
        self.profilesTableView.delegate = self
        self.view.addSubview(self.profilesTableView)
        
        // We're going to use our custom profile table view cell.
        self.profilesTableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: "basicStyle")

        // Set the default full screen constraint.
        self.applyDefaultConstraints(forFullScreenView:self.profilesTableView)
        
        // Error container.
        self.errorContainer.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.errorContainer)
        self.errorContainer.isHidden = true

        // Error label container, to provide some padding for the error label.
        let errorLabelContainer = UIView()
        errorLabelContainer.translatesAutoresizingMaskIntoConstraints = false
        errorLabelContainer.backgroundColor = .redWarning
        errorContainer.addSubview(errorLabelContainer)

        // Error label.
        let errorLabel = UILabel()
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.backgroundColor = .redWarning
        errorLabel.textColor = .white
        errorLabel.textAlignment = .left
        errorLabel.baselineAdjustment = .alignCenters
        errorLabel.text = "There was an error loading the data"
        errorLabelContainer.addSubview(errorLabel)
        
        // Reload data button.
        let reloadButton = UIButton(type: UIButton.ButtonType.system)
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        reloadButton.backgroundColor = .blueDark
        reloadButton.layer.cornerRadius = 5.0
        reloadButton.setTitleColor(UIColor.white, for: UIControl.State.normal)
        reloadButton.titleLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .bold)
        reloadButton.setTitle("Retry", for: UIControl.State.normal)
        reloadButton.addTarget(self, action: #selector(loadProfiles), for: .touchUpInside)
        self.errorContainer.addSubview(reloadButton)
        
        // Layout constraints.
        
        // View dictionary.
        let errorContainer = self.errorContainer
        let views: [String: Any] = [
            "errorContainer": errorContainer,
            "errorLabelContainer": errorLabelContainer,
            "errorLabel": errorLabel,
            "reloadButton": reloadButton
        ]
        
        // Core view.
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[errorContainer]-|", options: [], metrics: nil, views: views))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[errorContainer]-|", options: [], metrics: nil, views: views))
        
        // Error container.
        self.errorContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(verticalPadding)-[errorLabelContainer(==\(heightErrorLabel))]-\(verticalPadding)-[reloadButton(==\(heightReloadButton))]", options: [], metrics: nil, views: views))
        self.errorContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(horizontalPadding)-[errorLabelContainer]-\(horizontalPadding)-|", options: [], metrics: nil, views: views))
        self.errorContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(horizontalPadding)-[reloadButton]-\(horizontalPadding)-|", options: [], metrics: nil, views: views))

        // Error label container.
        errorLabelContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(verticalPadding)-[errorLabel]-\(verticalPadding)-|", options: [], metrics: nil, views: views))
        errorLabelContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(horizontalPadding)-[errorLabel]-\(horizontalPadding)-|", options: [], metrics: nil, views: views))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reload the profiles when the view appears.
        // This includes when the login screen is dismissed.
        self.loadProfiles()
    }

    // MARK: - Instance Methods
    
    @objc func loadProfiles() {
        // Loads the profile data from the Api.

        // Hide all the elements.
        self.profiles.removeAll()
        DispatchQueue.main.async {
            self.profilesTableView.isHidden = true
            self.errorContainer.isHidden = true
            self.profilesTableView.reloadData() // Clears the table view in the background.
        }
        
        // If no user is logged in, do not show any data.
        // In a production app we would probably throw up a login screen at this point.
        let userManager = UserManager()
        if !userManager.userLoggedIn() {
            return
        }

        // Display the activity indicator.
        self.showActivityIndicator()
        
        // Construct the Api call for profiles.
        let apiManager = ApiManager()
        apiManager.delegate = self
        apiManager.getData(
            urlString: ApiDefinitions.UrlProfiles,
            requiresAuthentication: true
        )
    }
 
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.profiles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let profile = profiles[indexPath.row]

        // Dequeue a table cell.
        // This re-uses an existing one if available, to improve performance.
        let cell = tableView.dequeueReusableCell(withIdentifier: "basicStyle", for: indexPath)
 
        if let cell = cell as? ProfileTableViewCell {
            
            // Display all star rating images as empty initially.
            DispatchQueue.main.async {
                cell.starImage1.image = UIImage(named: "StarEmpty")
                cell.starImage2.image = UIImage(named: "StarEmpty")
                cell.starImage3.image = UIImage(named: "StarEmpty")
            }

            if let profileImageData = profile.profileImageData {
                // If the model already has image data stored against it, display as an image.
                // We persist this on the model once it has been loaded to prevent repeated data fetches.
                let image = UIImage(data: profileImageData)
                if let image = image {
                    DispatchQueue.main.async {
                        cell.activityIndicator.stopAnimating()
                        cell.activityIndicator.isHidden = true
                        cell.profileImage.image = image
                    }
                }
            }
            else if let profileImage = profile.profileImage {
                // If the model does not yet have image data stored against it, start an async data load.
                // This fetches the image from the Url and displays it when complete.
                // We also persist the returned data on the model to prevent repeated data fetches.
                if let url = URL(string: profileImage) {
                    let session = URLSession.shared
                    session.dataTask(with: url) { (data, response, error) in
                        if let data = data {
                            profile.profileImageData = data
                            let image = UIImage(data: data)
                            if let image = image {
                                DispatchQueue.main.async {
                                    cell.activityIndicator.stopAnimating()
                                    cell.activityIndicator.isHidden = true
                                    cell.profileImage.image = image
                                }
                            }
                        }
                    }.resume()
                }
            }
                        
            // Name label.
            if let name = profile.name {
                cell.nameLabel.text = name
            }

            // Distance label.
            if let distanceFromUser = profile.distanceFromUser {
                cell.distanceLabel.text = distanceFromUser.replacingOccurrences(of: "m", with: " miles away")
            }
            
            // Fill in the star rating images based on the star rating returned.
            if let starLevel = profile.starLevel {
                if starLevel >= 1 {
                    DispatchQueue.main.async {
                        cell.starImage1.image = UIImage(named: "StarFilled")
                    }
                }
                if starLevel >= 2 {
                    DispatchQueue.main.async {
                        cell.starImage2.image = UIImage(named: "StarFilled")
                    }
                }
                if starLevel >= 3 {
                    DispatchQueue.main.async {
                        cell.starImage3.image = UIImage(named: "StarFilled")
                    }
                }
            }
            
            // Ratings label.
            if let numRatings = profile.numRatings {
                cell.ratingLabel.text = "(\(numRatings))"

                // If the profile matches the top rating number, display the header text.
                if let topRating = self.topRating {
                    if numRatings == topRating {
                        cell.headerDescription = "TOP RATED"
                    }
                }
            }
        }

        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Do nothing for the purposes of this demo.
    }
    
    // MARK: - ApiDelegate
    
    func gotData(data: ApiResponseData) {
        // Data successfully received.

        // Hide the activity indicator.
        self.hideActivityIndicator()
        
        if let profiles = data.profiles {
            // Populate the array from the returned data.
            // Note the data has already been deserialised straight into our model object
            // so we can simply assign this directly.

            var profilesFiltered = [Profile]()
            for profile in profiles {
                if profile.enabled {
                    profilesFiltered.append(profile)
                }
            }

            self.profiles = profilesFiltered
            
            print(profiles.count)
            print(profilesFiltered.count)

            // Get the highest rating number so we can display 'Top Rated' on the cells as appropriate.
            // Note the top rating could be shared by more than one profile,
            // so here we simply get the highest number (not the first profile in the sorted array)
            // then apply to any matching profiles with that rating.
            let profilesSorted = self.profiles.sorted {
                guard let numRatings0 = $0.numRatings, let numRatings1 = $1.numRatings else { return false }
                return numRatings0 > numRatings1
            }
            if profilesSorted.count > 0 {
                self.topRating = profilesSorted[0].numRatings
            }
        }
        
        // Reload the table.
        DispatchQueue.main.async {
            self.profilesTableView.isHidden = false
            self.errorContainer.isHidden = true
            self.profilesTableView.reloadData()
        }
    }

    func unsuccessfulStatusCode(data: ApiResponseData) {
        // Unsuccessful response received from the Api.
        
        // Hide the activity indicator.
        self.hideActivityIndicator()

        // Display the error label and reload button.
        DispatchQueue.main.async {
            self.profilesTableView.isHidden = true
            self.errorContainer.isHidden = false
        }
    }
    
    func failedToGetData() {
        // Unsuccessful response received from the Api.
        
        // Hide the activity indicator.
        self.hideActivityIndicator()

        // Display the error label and reload button.
        DispatchQueue.main.async {
            self.profilesTableView.isHidden = true
            self.errorContainer.isHidden = false
        }
    }
}
