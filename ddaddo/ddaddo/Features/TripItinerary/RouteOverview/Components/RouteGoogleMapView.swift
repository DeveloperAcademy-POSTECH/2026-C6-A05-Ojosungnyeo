//
//  RouteGoogleMapView.swift
//  ddaddo
//
//  Created by sun on 10/30/26.
//

import GoogleMaps
import SwiftUI

struct RouteGoogleMapView: UIViewRepresentable {
    let stops: [RouteStop]

    final class Coordinator {
        var signature = ""
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        guard GoogleMapsService.configure() else {
            return configurationErrorView
        }

        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition(
            latitude: 35.6812,
            longitude: 139.7671,
            zoom: 13
        )

        let mapView = GMSMapView(options: options)
        mapView.settings.compassButton = false
        mapView.settings.myLocationButton = false
        mapView.isBuildingsEnabled = false
        mapView.mapStyle = try? GMSMapStyle(jsonString: Self.darkMapStyle)
        updateRoute(on: mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard let mapView = view as? GMSMapView else { return }
        updateRoute(on: mapView, coordinator: context.coordinator)
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

    private func updateRoute(on mapView: GMSMapView, coordinator: Coordinator) {
        let signature = stops.map { "\($0.id):\($0.latitude):\($0.longitude)" }.joined(separator: "|")
        guard signature != coordinator.signature else { return }
        coordinator.signature = signature
        mapView.clear()

        guard !stops.isEmpty else { return }

        let path = GMSMutablePath()
        var bounds = GMSCoordinateBounds()

        for stop in stops {
            let coordinate = CLLocationCoordinate2D(
                latitude: stop.latitude,
                longitude: stop.longitude
            )
            path.add(coordinate)
            bounds = bounds.includingCoordinate(coordinate)

            let marker = GMSMarker(position: coordinate)
            marker.icon = Self.markerImage
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.82)
            marker.map = mapView
        }

        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = UIColor(red: 0.40, green: 0.95, blue: 0.89, alpha: 1)
        polyline.strokeWidth = 5
        polyline.map = mapView

        mapView.padding = UIEdgeInsets(top: 140, left: 44, bottom: 320, right: 28)
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 64))
    }

    private static let markerImage: UIImage? = {
        guard let source = UIImage(named: "DDRouteUFO") else { return nil }
        let size = CGSize(width: 60, height: 82)
        return UIGraphicsImageRenderer(size: size).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
    }()

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
