//
//  GoogleMapView.swift
//  ddaddo
//
//  Created by sun on 10/21/26.
//

import GoogleMaps
import SwiftUI

struct GoogleMapView: UIViewRepresentable {
    var latitude: CLLocationDegrees = 37.7749
    var longitude: CLLocationDegrees = -122.4194
    var zoom: Float = 15
    var selectedPlace: PlaceDetails?
    var showsSelectedPlaceMarker = true
    var selectedCoordinate: CLLocationCoordinate2D?
    var pinnedPlaces: [PinnedPlace] = []
    var showsPinnedPlaceNumbers = false
    var placeGroups: [MapPlaceGroup] = []
    var onPinnedPlaceTapped: ((PinnedPlace) -> Void)?

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        var markerSignature = ""

        init(parent: GoogleMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard
                let place = marker.userData as? PinnedPlace,
                let onPinnedPlaceTapped = parent.onPinnedPlaceTapped
            else { return false }

            onPinnedPlaceTapped(place)
            return true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        guard GoogleMapsService.configure() else {
            return configurationErrorView
        }

        let camera = GMSCameraPosition(
            latitude: latitude,
            longitude: longitude,
            zoom: zoom
        )
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        mapView.settings.compassButton = false
        mapView.settings.myLocationButton = false
        mapView.isBuildingsEnabled = true
        mapView.mapStyle = try? GMSMapStyle(jsonString: Self.darkMapStyle)
        updateSelection(on: mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard let mapView = view as? GMSMapView else { return }
        context.coordinator.parent = self
        updateSelection(on: mapView, coordinator: context.coordinator)
    }

    private var configurationErrorView: UIView {
        let label = UILabel()
        label.backgroundColor = UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1)
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Google Maps API Key 설정을 확인해 주세요."
        return label
    }

    private func updateSelection(on mapView: GMSMapView, coordinator: Coordinator) {
        let signature: String
        if let selectedPlace {
            signature = "selected:\(selectedPlace.id):marker:\(showsSelectedPlaceMarker)"
        } else if let selectedCoordinate {
            signature = "\(selectedCoordinate.latitude),\(selectedCoordinate.longitude)"
        } else if !placeGroups.isEmpty {
            signature = placeGroups.map { group in
                "\(group.id):\(group.places.map(\.id).joined(separator: ","))"
            }.joined(separator: "|")
        } else {
            signature = "numbered:\(showsPinnedPlaceNumbers):"
                + pinnedPlaces.map(\.id).joined(separator: ",")
        }
        guard coordinator.markerSignature != signature else { return }
        coordinator.markerSignature = signature
        mapView.clear()

        if let selectedPlace {
            let coordinate = CLLocationCoordinate2D(
                latitude: selectedPlace.latitude,
                longitude: selectedPlace.longitude
            )
            if showsSelectedPlaceMarker {
                addMarker(at: coordinate, to: mapView)
            } else {
                addPinnedPlaceMarkers(to: mapView)
            }
            mapView.animate(to: GMSCameraPosition(target: coordinate, zoom: 15))
            return
        }

        if let selectedCoordinate {
            addMarker(at: selectedCoordinate, to: mapView)
            mapView.animate(to: GMSCameraPosition(target: selectedCoordinate, zoom: zoom))
            return
        }

        if !placeGroups.isEmpty {
            addPlaceGroups(to: mapView)
            return
        }

        guard !pinnedPlaces.isEmpty else { return }
        var bounds = GMSCoordinateBounds()
        for (index, place) in pinnedPlaces.enumerated() {
            let coordinate = CLLocationCoordinate2D(
                latitude: place.latitude,
                longitude: place.longitude
            )
            addMarker(
                at: coordinate,
                place: place,
                number: showsPinnedPlaceNumbers ? index + 1 : nil,
                to: mapView
            )
            bounds = bounds.includingCoordinate(coordinate)
        }
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 72))
    }

    private func addPlaceGroups(to mapView: GMSMapView) {
        var bounds = GMSCoordinateBounds()

        for group in placeGroups {
            let center = CLLocationCoordinate2D(
                latitude: group.centerLatitude,
                longitude: group.centerLongitude
            )
            let circle = GMSCircle(position: center, radius: group.radius)
            circle.fillColor = UIColor(red: 242 / 255, green: 255 / 255, blue: 96 / 255, alpha: 0.45)
            circle.strokeColor = UIColor(red: 242 / 255, green: 255 / 255, blue: 96 / 255, alpha: 1)
            circle.strokeWidth = 2
            circle.map = mapView

            for place in group.places {
                let coordinate = CLLocationCoordinate2D(
                    latitude: place.latitude,
                    longitude: place.longitude
                )
                addMarker(at: coordinate, place: place, to: mapView)
                bounds = bounds.includingCoordinate(coordinate)
            }

            addGroupLabel(group.name, center: center, radius: group.radius, to: mapView)
            let latitudeOffset = group.radius / 111_000
            bounds = bounds.includingCoordinate(
                CLLocationCoordinate2D(
                    latitude: center.latitude - latitudeOffset,
                    longitude: center.longitude
                )
            )
            bounds = bounds.includingCoordinate(
                CLLocationCoordinate2D(
                    latitude: center.latitude + latitudeOffset,
                    longitude: center.longitude
                )
            )
        }

        mapView.animate(
            with: GMSCameraUpdate.fit(
                bounds,
                with: UIEdgeInsets(top: 150, left: 24, bottom: 330, right: 24)
            )
        )
    }

    private func addGroupLabel(
        _ title: String,
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        to mapView: GMSMapView
    ) {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 56, height: 20))
        label.font = UIFont(name: "Pretendard-SemiBold", size: 14)
        label.text = title
        label.textAlignment = .center
        label.textColor = UIColor(red: 242 / 255, green: 255 / 255, blue: 96 / 255, alpha: 1)

        let marker = GMSMarker(
            position: CLLocationCoordinate2D(
                latitude: center.latitude - radius / 111_000,
                longitude: center.longitude
            )
        )
        marker.iconView = label
        marker.groundAnchor = CGPoint(x: 0.5, y: 0)
        marker.map = mapView
    }

    private func addPinnedPlaceMarkers(to mapView: GMSMapView) {
        for (index, place) in pinnedPlaces.enumerated() {
            let coordinate = CLLocationCoordinate2D(
                latitude: place.latitude,
                longitude: place.longitude
            )
            addMarker(
                at: coordinate,
                place: place,
                number: showsPinnedPlaceNumbers ? index + 1 : nil,
                to: mapView
            )
        }
    }

    private func addMarker(
        at coordinate: CLLocationCoordinate2D,
        place: PinnedPlace? = nil,
        number: Int? = nil,
        to mapView: GMSMapView
    ) {
        let marker = GMSMarker(position: coordinate)
        if let number {
            marker.iconView = numberedMarkerView(number: number)
        } else {
            marker.icon = UIImage(named: "UFO")
        }
        marker.groundAnchor = CGPoint(x: 0.5, y: 1)
        marker.userData = place
        marker.map = mapView
    }

    private func numberedMarkerView(number: Int) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 48, height: 87))

        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 48, height: 72))
        imageView.image = UIImage(named: "UFO")
        imageView.contentMode = .scaleAspectFit
        container.addSubview(imageView)

        let numberLabel = UILabel(frame: CGRect(x: 16.5, y: 72, width: 15, height: 15))
        numberLabel.backgroundColor = UIColor(red: 242 / 255, green: 255 / 255, blue: 96 / 255, alpha: 1)
        numberLabel.textColor = .black
        numberLabel.font = UIFont(name: "Pretendard-Medium", size: 10)
            ?? .systemFont(ofSize: 10, weight: .medium)
        numberLabel.textAlignment = .center
        numberLabel.text = "\(number)"
        numberLabel.layer.cornerRadius = 7.5
        numberLabel.layer.masksToBounds = true
        container.addSubview(numberLabel)

        return container
    }

    private static let darkMapStyle = """
    [
      {"elementType":"geometry","stylers":[{"color":"#242424"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#242424"}]},
      {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#353535"}]},
      {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1f1f1f"}]},
      {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#777777"}]},
      {"featureType":"transit","stylers":[{"visibility":"off"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#171717"}]}
    ]
    """
}
