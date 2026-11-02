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

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var signature = ""
        var numberedMarkers: [(marker: GMSMarker, number: Int)] = []
        var markerScale: CGFloat = -1

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            updateMarkerScale(for: position.zoom)
        }

        func updateMarkerScale(for zoom: Float) {
            let zoomDifference = CGFloat(zoom - 13)
            let scale = min(max(pow(1.22, zoomDifference), 0.48), 1.35)
            guard abs(scale - markerScale) >= 0.05 else { return }
            markerScale = scale

            for numberedMarker in numberedMarkers {
                numberedMarker.marker.icon = RouteGoogleMapView.markerImage(
                    number: numberedMarker.number,
                    scale: scale
                )
            }
        }
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
        mapView.delegate = context.coordinator
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
        coordinator.numberedMarkers.removeAll()
        coordinator.markerScale = -1

        guard !stops.isEmpty else { return }

        let path = GMSMutablePath()
        var bounds = GMSCoordinateBounds()

        for (index, stop) in stops.enumerated() {
            let coordinate = CLLocationCoordinate2D(
                latitude: stop.latitude,
                longitude: stop.longitude
            )
            path.add(coordinate)
            bounds = bounds.includingCoordinate(coordinate)

            let marker = GMSMarker(position: coordinate)
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.82)
            marker.map = mapView
            coordinator.numberedMarkers.append((marker, index + 1))
        }

        coordinator.updateMarkerScale(for: mapView.camera.zoom)

        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = UIColor(red: 242 / 255, green: 1, blue: 96 / 255, alpha: 1)
        polyline.strokeWidth = 5
        polyline.map = mapView

        mapView.padding = UIEdgeInsets(top: 140, left: 44, bottom: 320, right: 28)
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 64))
    }

    fileprivate static func markerImage(number: Int, scale: CGFloat) -> UIImage? {
        guard let source = UIImage(named: "DDRouteUFO") else { return nil }
        let size = CGSize(width: 60 * scale, height: 96 * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            source.draw(
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: 60 * scale,
                    height: 82 * scale
                )
            )

            let circleRect = CGRect(
                x: 22.5 * scale,
                y: 79 * scale,
                width: 15 * scale,
                height: 15 * scale
            )
            UIColor(red: 242 / 255, green: 1, blue: 96 / 255, alpha: 1).setFill()
            UIBezierPath(ovalIn: circleRect).fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10 * scale, weight: .medium),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]
            String(number).draw(
                in: CGRect(
                    x: 22.5 * scale,
                    y: 80.5 * scale,
                    width: 15 * scale,
                    height: 12 * scale
                ),
                withAttributes: attributes
            )
        }
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
