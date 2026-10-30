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
    var selectedCoordinate: CLLocationCoordinate2D?
    var pinnedPlaces: [PinnedPlace] = []

    final class Coordinator {
        var markerSignature = ""
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
        mapView.settings.compassButton = false
        mapView.settings.myLocationButton = false
        mapView.isBuildingsEnabled = true
        mapView.mapStyle = try? GMSMapStyle(jsonString: Self.darkMapStyle)
        updateSelection(on: mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard let mapView = view as? GMSMapView else { return }
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
        let signature = selectedPlace?.id
            ?? selectedCoordinate.map { "\($0.latitude),\($0.longitude)" }
            ?? pinnedPlaces.map(\.id).joined(separator: ",")
        guard coordinator.markerSignature != signature else { return }
        coordinator.markerSignature = signature
        mapView.clear()

        if let selectedPlace {
            let coordinate = CLLocationCoordinate2D(
                latitude: selectedPlace.latitude,
                longitude: selectedPlace.longitude
            )
            addMarker(at: coordinate, to: mapView)
            mapView.animate(to: GMSCameraPosition(target: coordinate, zoom: 15))
            return
        }

        if let selectedCoordinate {
            addMarker(at: selectedCoordinate, to: mapView)
            mapView.animate(to: GMSCameraPosition(target: selectedCoordinate, zoom: zoom))
            return
        }

        guard !pinnedPlaces.isEmpty else { return }
        var bounds = GMSCoordinateBounds()
        for place in pinnedPlaces {
            let coordinate = CLLocationCoordinate2D(
                latitude: place.latitude,
                longitude: place.longitude
            )
            addMarker(at: coordinate, to: mapView)
            bounds = bounds.includingCoordinate(coordinate)
        }
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 72))
    }

    private func addMarker(at coordinate: CLLocationCoordinate2D, to mapView: GMSMapView) {
        let marker = GMSMarker(position: coordinate)
        marker.icon = UIImage(named: "UFO")
        marker.groundAnchor = CGPoint(x: 0.5, y: 1)
        marker.map = mapView
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
