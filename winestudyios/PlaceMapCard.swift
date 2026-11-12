//
//  PlaceMapCard.swift
//  winestudyios
//
//  Small Apple map shown under the feedback after an answer, with a pin on the
//  question's `place`. Only shown when the question has a place.
//

import UIKit
import MapKit

final class PlaceMapCard: UIView, MKMapViewDelegate {

    private static let pinPink  = UIColor(red: 227/255, green: 59/255, blue: 142/255, alpha: 1)  // Volo hot pink
    private static let edgePink = UIColor(red: 247/255, green: 195/255, blue: 222/255, alpha: 1)

    /// How much area the map shows around the pin (degrees of latitude/longitude).
    private static let span = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)

    private let mapView = MKMapView()
    private let pin = MKPointAnnotation()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 16
        layer.borderWidth = 2
        layer.borderColor = PlaceMapCard.edgePink.cgColor
        clipsToBounds = true

        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        // Pinch to zoom and drag to slide (Jill, 12 Nov). A swipe that starts on the map moves the map;
        // swipe above or below it to scroll the page. Each new answer re-centres on its pin.
        mapView.isScrollEnabled = true
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: topAnchor),
            mapView.bottomAnchor.constraint(equalTo: bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        mapView.addAnnotation(pin)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Moves the map and pin to this place.
    func show(_ place: QuestionPlace) {
        let centre = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
        // Re-add the pin so its label refreshes with the new name.
        mapView.removeAnnotation(pin)
        pin.coordinate = centre
        pin.title = place.name
        mapView.addAnnotation(pin)
        mapView.setRegion(MKCoordinateRegion(center: centre, span: PlaceMapCard.span), animated: false)
    }

    // Volo-pink pin with the wine-glasses icon, name always shown.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let id = "place"
        let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        view.annotation = annotation
        view.markerTintColor = PlaceMapCard.pinPink
        view.glyphImage = UIImage(named: "glasses")
        view.titleVisibility = .visible
        return view
    }
}
