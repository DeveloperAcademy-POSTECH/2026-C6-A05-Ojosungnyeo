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
    var pinnedPlaces: [PinnedPlace] = []

    final class Coordinator {
        var markerSignature = ""
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> GMSMapView {
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

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        updateSelection(on: mapView, coordinator: context.coordinator)
    }

    private func updateSelection(on mapView: GMSMapView, coordinator: Coordinator) {
        let signature = selectedPlace?.id ?? pinnedPlaces.map(\.id).joined(separator: ",")
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
