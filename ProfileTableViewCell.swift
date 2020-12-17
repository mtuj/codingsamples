import UIKit

class ProfileTableViewCell: UITableViewCell {
    // Subclass of UITableViewCell for displaying profiles in a UITableView.
    
    // MARK: - Constants

    let verticalPadding = 10.0
    let horizontalPadding = 10.0

    let verticalSpacing = 15.0
    let verticalSpacingSmall = 5.0
    let verticalSpacingNameLabel = 10.0
    let verticalSpacingContactButton = 12.5
    
    let horizontalSpacing = 15.0
    let horizontalSpacingSmall = 5.0
    let horizontalSpacingProfileImage = 20.0
    let horizontalSpacingContactButton = 20.0

    let heightHeaderLabel = 30.0
    let heightNameLabel = 20.0
    let heightDistanceLabel = 15.0
    let heightStarRating = 25.0
    let heightRatingLabel = 25.0
    let heightContactButton = 30.0
    
    let widthProfileImage = 55.0
    let widthStarRating = 25.0
    let widthContactButton = 75.0
    
    // MARK: - Properties

    var headerContainer = UIView()
    var headerLabel = UILabel()
    var profileImage = UIImageView(frame: CGRect(x: 0, y: 0, width: 55, height: 55))
    var nameLabel = UILabel()
    var distanceLabel = UILabel()
    var starImage1 = UIImageView(frame: CGRect(x: 0, y: 0, width: 25, height: 25))
    var starImage2 = UIImageView(frame: CGRect(x: 0, y: 0, width: 25, height: 25))
    var starImage3 = UIImageView(frame: CGRect(x: 0, y: 0, width: 25, height: 25))
    var ratingLabel = UILabel()
    var contactButton = UIButton(type: UIButton.ButtonType.system)
    var activityIndicator = UIActivityIndicatorView(style: .large)

    // Custom setter for the header text.
    // This is a fairly basic implementation to simply change the text and background,
    // ideally it would also contain constraint updates to completely hide the header label.
    private var _headerDescription: String?
    var headerDescription: String? {
        get {
            return _headerDescription
        }
        set(value) {
            _headerDescription = value
            if let value = value {
                self.headerLabel.text = value
                self.headerLabel.backgroundColor = .blueDark
            } else {
                self.headerLabel.text = ""
                self.headerLabel.backgroundColor = .white
            }
        }
    }

    // MARK: - Initialisation

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {

        super .init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .none
        self.contentView.backgroundColor = .none

        // Let's set up all the required views.

        // Main container.

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .white
        // Setting this to true makes the radius appear, but removes the shadow.
        // Known issue, requires custom implementation code to achieve both.
        container.layer.masksToBounds = false
        container.layer.cornerRadius = 5.0
        container.layer.shadowOffset = CGSize(width: -1, height: 1)
        container.layer.shadowOpacity = 0.3
        self.contentView.addSubview(container)

        // Section containers.

        // Header container.
        // Contains the header label.
        self.headerContainer.translatesAutoresizingMaskIntoConstraints = false
        self.headerContainer.backgroundColor = .white
        container.addSubview(self.headerContainer)

        // Top container.
        // Contains the profile image, and the name and distance labels.
        let topContainer = UIView()
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        topContainer.backgroundColor = .white
        container.addSubview(topContainer)

        // Bottom container.
        // Contains the star rating images, the rating number, and the contact button.
        let bottomContainer = UIView()
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.backgroundColor = .backgroundDefault
        container.addSubview(bottomContainer)
 
        // Header section elements.
        
        // Header label.
        self.headerLabel.translatesAutoresizingMaskIntoConstraints = false
        self.headerLabel.backgroundColor = .white
        self.headerLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        self.headerLabel.textColor = .white
        self.headerLabel.textAlignment = .center
        self.headerLabel.baselineAdjustment = .alignCenters
        self.headerContainer.addSubview(self.headerLabel)
 
        // Top section elements.

        // Profile image.
        self.profileImage.translatesAutoresizingMaskIntoConstraints = false
        self.profileImage.contentMode = .scaleAspectFit
        self.profileImage.layer.masksToBounds = false
        self.profileImage.layer.cornerRadius = CGFloat(widthProfileImage/2) // Set as half the width to give a circle radius.
        self.profileImage.clipsToBounds = true
        topContainer.addSubview(self.profileImage)
        
        // Activity indicator.
        // We start this animating immediately while the profile image begins loading.
        self.activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        topContainer.addSubview(self.activityIndicator)
        self.activityIndicator.isHidden = false
        topContainer.bringSubviewToFront(self.activityIndicator)
        self.activityIndicator.startAnimating()

        // Sub-container to hold the name and distance labels.
        let topRightContainer = UIView()
        topRightContainer.translatesAutoresizingMaskIntoConstraints = false
        topRightContainer.backgroundColor = .white
        topContainer.addSubview(topRightContainer)

        // Name label.
        self.nameLabel.translatesAutoresizingMaskIntoConstraints = false
        self.nameLabel.backgroundColor = .white
        self.nameLabel.font = UIFont.systemFont(ofSize: 19.0, weight: .bold)
        self.nameLabel.textColor = .profileName
        self.nameLabel.textAlignment = .left
        self.nameLabel.baselineAdjustment = .alignCenters
        topRightContainer.addSubview(self.nameLabel)

        // Distance label.
        self.distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        self.distanceLabel.backgroundColor = .white
        self.distanceLabel.font = UIFont.systemFont(ofSize: 14.0)
        self.distanceLabel.textColor = .profileSubtitle
        self.distanceLabel.textAlignment = .left
        self.distanceLabel.baselineAdjustment = .alignCenters
        topRightContainer.addSubview(self.distanceLabel)
        
        // Bottom section elements.

        // The three star rating images.
        // This would ideally be abstracted into a single custom view.
        self.starImage1.translatesAutoresizingMaskIntoConstraints = false
        self.starImage1.contentMode = .scaleAspectFit
        bottomContainer.addSubview(self.starImage1)
        self.starImage2.translatesAutoresizingMaskIntoConstraints = false
        self.starImage2.contentMode = .scaleAspectFit
        bottomContainer.addSubview(self.starImage2)
        self.starImage3.translatesAutoresizingMaskIntoConstraints = false
        self.starImage3.contentMode = .scaleAspectFit
        bottomContainer.addSubview(self.starImage3)

        // Rating number label.
        self.ratingLabel.translatesAutoresizingMaskIntoConstraints = false
        self.ratingLabel.backgroundColor = .backgroundDefault
        self.ratingLabel.font = UIFont.systemFont(ofSize: 14.0)
        self.ratingLabel.textColor = .profileSubtitle
        self.ratingLabel.textAlignment = .left
        self.ratingLabel.baselineAdjustment = .alignCenters
        bottomContainer.addSubview(self.ratingLabel)

        // Contact button.
        // For the purposes of our demo, it doesn't actually do anything!
        self.contactButton.translatesAutoresizingMaskIntoConstraints = false
        self.contactButton.backgroundColor = UIColor.blueDark
        self.contactButton.titleLabel?.font = UIFont.systemFont(ofSize: 11.0, weight: .bold)
        self.contactButton.layer.borderColor = UIColor.white.cgColor
        self.contactButton.layer.borderWidth = 1.0
        self.contactButton.layer.cornerRadius = 5.0
        self.contactButton.setTitle("Contact", for: UIControl.State.normal)
        self.contactButton.setTitleColor(UIColor.white, for: UIControl.State.normal)
        bottomContainer.addSubview(self.contactButton)
        
        // Layout constraints.

        // View dictionary.
        let headerContainer = self.headerContainer
        let headerLabel = self.headerLabel
        let profileImage = self.profileImage
        let activityIndicator = self.activityIndicator
        let nameLabel = self.nameLabel
        let distanceLabel = self.distanceLabel
        let starImage1 = self.starImage1
        let starImage2 = self.starImage2
        let starImage3 = self.starImage3
        let ratingLabel = self.ratingLabel
        let contactButton = self.contactButton
        let views: [String: Any] = [
            "container": container,
            "headerContainer": headerContainer,
            "topContainer": topContainer,
            "bottomContainer": bottomContainer,
            "topRightContainer": topRightContainer,
            "headerLabel": headerLabel,
            "profileImage": profileImage,
            "activityIndicator": activityIndicator,
            "nameLabel": nameLabel,
            "distanceLabel": distanceLabel,
            "starImage1": starImage1,
            "starImage2": starImage2,
            "starImage3": starImage3,
            "ratingLabel": ratingLabel,
            "contactButton": contactButton
        ]

        // Core view.
        self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(verticalPadding)-[container]-\(verticalPadding)-|", options: [], metrics: nil, views: views))
        self.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(horizontalPadding)-[container]-\(horizontalPadding)-|", options: [], metrics: nil, views: views))

        // Main container.
        container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[headerContainer][topContainer][bottomContainer]|", options: [], metrics: nil, views: views))
        container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[headerContainer]|", options: [], metrics: nil, views: views))
        container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[topContainer]|", options: [], metrics: nil, views: views))
        container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[bottomContainer]|", options: [], metrics: nil, views: views))

        // Header container.
        headerContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[headerLabel(==\(heightHeaderLabel))]|", options: [], metrics: nil, views: views))
        headerContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[headerLabel]|", options: [], metrics: nil, views: views))

        // Top container.
        topContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[profileImage]-\(verticalSpacing)-|", options: [], metrics: nil, views: views))
        topContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[topRightContainer]-\(verticalSpacing)-|", options: [], metrics: nil, views: views))
        topContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(horizontalSpacingProfileImage)-[profileImage(==\(widthProfileImage))]-\(horizontalSpacing)-[topRightContainer]-\(horizontalSpacing)-|", options: [], metrics: nil, views: views))
        topContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[activityIndicator]-|", options: [], metrics: nil, views: views))
        topContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(horizontalSpacingProfileImage)-[activityIndicator]", options: [], metrics: nil, views: views))
        topRightContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(verticalSpacingNameLabel)-[nameLabel(==\(heightNameLabel))]-[distanceLabel(\(heightDistanceLabel))]-\(verticalSpacingNameLabel)-|", options: [], metrics: nil, views: views))
        topRightContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(horizontalSpacing)-[nameLabel]-\(horizontalSpacingSmall)-|", options: [], metrics: nil, views: views))
        topRightContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(horizontalSpacing)-[distanceLabel]-\(horizontalSpacingSmall)-|", options: [], metrics: nil, views: views))

        // Bottom container.
        bottomContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(verticalSpacing)-[starImage1(==\(heightStarRating))]-\(verticalSpacing)-|", options: [], metrics: nil, views: views))
        bottomContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(verticalSpacing)-[starImage2(==\(heightStarRating))]-\(verticalSpacing)-|", options: [], metrics: nil, views: views))
        bottomContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(verticalSpacing)-[starImage3(==\(heightStarRating))]-\(verticalSpacing)-|", options: [], metrics: nil, views: views))
        bottomContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(verticalSpacing)-[ratingLabel(==\(heightRatingLabel))]-\(verticalSpacing)-|", options: [], metrics: nil, views: views))
        bottomContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(verticalSpacingContactButton)-[contactButton(\(heightContactButton))]-\(verticalSpacingContactButton)-|", options: [], metrics: nil, views: views))
        bottomContainer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(verticalSpacing)-[starImage1(==\(widthStarRating))][starImage2(==\(widthStarRating))][starImage3(==\(widthStarRating))]-\(verticalSpacing)-[ratingLabel]-[contactButton(==\(widthContactButton))]-\(horizontalSpacingContactButton)-|", options: [], metrics: nil, views: views))
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
