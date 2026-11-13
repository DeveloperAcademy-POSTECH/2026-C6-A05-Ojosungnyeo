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
        var ufoMarkers: [(marker: GMSMarker, number: Int?)] = []
        var markerScale: CGFloat = -1
        var currentZoom: Float

        init(parent: GoogleMapView) {
            self.parent = parent
            currentZoom = parent.zoom
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard
                let place = marker.userData as? PinnedPlace,
                let onPinnedPlaceTapped = parent.onPinnedPlaceTapped
            else { return false }

            onPinnedPlaceTapped(place)
            return true
        }

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            updateMarkerScale(for: position.zoom)
        }

        func updateMarkerScale(for zoom: Float) {
            currentZoom = zoom
            let scale = GoogleMapView.markerScale(for: zoom)
            guard abs(scale - markerScale) >= 0.05 else { return }
            markerScale = scale

            for item in ufoMarkers {
                if let number = item.number {
                    item.marker.icon = nil
                    item.marker.iconView = GoogleMapView.numberedMarkerView(
                        number: number,
                        scale: scale
                    )
                } else {
                    item.marker.iconView = nil
                    item.marker.icon = GoogleMapView.markerImage(scale: scale)
                }
            }
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
            signature = "selected:\(selectedPlace.id)"
                + ":\(selectedPlace.latitude),\(selectedPlace.longitude)"
                + ":marker:\(showsSelectedPlaceMarker)"
        } else if let selectedCoordinate {
            signature = "\(selectedCoordinate.latitude),\(selectedCoordinate.longitude)"
        } else if !placeGroups.isEmpty {
            signature = placeGroups.map { group in
                "\(group.id):\(group.name):\(group.places.map(\.id).joined(separator: ","))"
            }.joined(separator: "|")
        } else {
            signature = "numbered:\(showsPinnedPlaceNumbers):"
                + pinnedPlaces.map(\.id).joined(separator: ",")
        }
        guard coordinator.markerSignature != signature else { return }
        coordinator.markerSignature = signature
        mapView.clear()
        coordinator.ufoMarkers.removeAll()
        coordinator.markerScale = -1

        if let selectedPlace {
            let coordinate = CLLocationCoordinate2D(
                latitude: selectedPlace.latitude,
                longitude: selectedPlace.longitude
            )
            if showsSelectedPlaceMarker {
                addMarker(
                    at: coordinate,
                    to: mapView,
                    coordinator: coordinator
                )
            } else {
                addPinnedPlaceMarkers(
                    to: mapView,
                    coordinator: coordinator
                )
            }
            mapView.animate(to: GMSCameraPosition(target: coordinate, zoom: 15))
            return
        }

        if let selectedCoordinate {
            addMarker(
                at: selectedCoordinate,
                to: mapView,
                coordinator: coordinator
            )
            coordinator.updateMarkerScale(for: coordinator.currentZoom)
            mapView.animate(to: GMSCameraPosition(target: selectedCoordinate, zoom: zoom))
            return
        }

        if !placeGroups.isEmpty {
            addPlaceGroups(to: mapView, coordinator: coordinator)
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
                to: mapView,
                coordinator: coordinator
            )
            bounds = bounds.includingCoordinate(coordinate)
        }
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 72))
        coordinator.updateMarkerScale(for: coordinator.currentZoom)
    }

    private func addPlaceGroups(
        to mapView: GMSMapView,
        coordinator: Coordinator
    ) {
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
                addMarker(
                    at: coordinate,
                    place: place,
                    to: mapView,
                    coordinator: coordinator
                )
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
        coordinator.updateMarkerScale(for: coordinator.currentZoom)
    }

    private func addGroupLabel(
        _ title: String,
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        to mapView: GMSMapView
    ) {
        let label = UILabel()
        label.font = UIFont(name: "Pretendard-SemiBold", size: 14)
        func textWidth(_ text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: label.font as Any]).width
        }

        let characters = Array(title)
        let lines: [String]
        if characters.count <= 5 {
            lines = [title]
        } else {
            var bestLines: [String]?
            var smallestWidthDifference = CGFloat.infinity
            for index in characters.indices where characters[index].isWhitespace {
                let first = String(characters[..<index])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let second = String(characters[(index + 1)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !first.isEmpty, !second.isEmpty else { continue }

                let widthDifference = abs(textWidth(first) - textWidth(second))
                if widthDifference < smallestWidthDifference {
                    smallestWidthDifference = widthDifference
                    bestLines = [first, second]
                }
            }

            if let bestLines {
                lines = bestLines
            } else {
                let midpoint = (characters.count + 1) / 2
                lines = [String(characters[..<midpoint]), String(characters[midpoint...])]
            }
        }

        label.numberOfLines = lines.count
        label.lineBreakMode = .byWordWrapping
        label.text = lines.joined(separator: "\n")
        label.textAlignment = .center
        label.textColor = UIColor(red: 242 / 255, green: 255 / 255, blue: 96 / 255, alpha: 1)
        let lineWidth = lines.map(textWidth).max() ?? 0
        label.frame = CGRect(
            x: 0,
            y: 0,
            width: max(56, ceil(lineWidth) + 8),
            height: max(20, ceil(label.font.lineHeight * CGFloat(lines.count)))
        )

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

    private func addPinnedPlaceMarkers(
        to mapView: GMSMapView,
        coordinator: Coordinator
    ) {
        for (index, place) in pinnedPlaces.enumerated() {
            let coordinate = CLLocationCoordinate2D(
                latitude: place.latitude,
                longitude: place.longitude
            )
            addMarker(
                at: coordinate,
                place: place,
                number: showsPinnedPlaceNumbers ? index + 1 : nil,
                to: mapView,
                coordinator: coordinator
            )
        }
    }

    private func addMarker(
        at coordinate: CLLocationCoordinate2D,
        place: PinnedPlace? = nil,
        number: Int? = nil,
        to mapView: GMSMapView,
        coordinator: Coordinator
    ) {
        let marker = GMSMarker(position: coordinate)
        marker.groundAnchor = CGPoint(x: 0.5, y: 1)
        marker.userData = place

        let scale = coordinator.markerScale > 0
            ? coordinator.markerScale
            : Self.markerScale(for: coordinator.currentZoom)
        if let number {
            marker.iconView = Self.numberedMarkerView(number: number, scale: scale)
        } else {
            marker.icon = Self.markerImage(scale: scale)
        }

        marker.map = mapView
        coordinator.ufoMarkers.append((marker, number))
        coordinator.updateMarkerScale(for: coordinator.currentZoom)
    }

    fileprivate static func markerScale(for zoom: Float) -> CGFloat {
        let zoomDifference = CGFloat(zoom - 13)
        return min(max(pow(1.22, zoomDifference), 0.48), 1.35)
    }

    fileprivate static func markerImage(scale: CGFloat) -> UIImage? {
        guard let source = UIImage(named: "UFO") else { return nil }
        let size = CGSize(width: 42 * scale, height: 63 * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    fileprivate static func numberedMarkerView(
        number: Int,
        scale: CGFloat
    ) -> UIView {
        let width = 42 * scale
        let ufoHeight = 63 * scale
        let numberSize = 15 * scale
        let container = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: width,
                height: ufoHeight + numberSize
            )
        )

        let imageView = UIImageView(
            frame: CGRect(x: 0, y: 0, width: width, height: ufoHeight)
        )
        imageView.image = UIImage(named: "UFO")
        imageView.contentMode = .scaleAspectFit
        container.addSubview(imageView)

        let numberLabel = UILabel(
            frame: CGRect(
                x: (width - numberSize) / 2,
                y: ufoHeight,
                width: numberSize,
                height: numberSize
            )
        )
        numberLabel.backgroundColor = UIColor(red: 242 / 255, green: 255 / 255, blue: 96 / 255, alpha: 1)
        numberLabel.textColor = .black
        numberLabel.font = UIFont(
            name: "Pretendard-Medium",
            size: 10 * scale
        ) ?? .systemFont(ofSize: 10 * scale, weight: .medium)
        numberLabel.textAlignment = .center
        numberLabel.text = "\(number)"
        numberLabel.layer.cornerRadius = numberSize / 2
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
