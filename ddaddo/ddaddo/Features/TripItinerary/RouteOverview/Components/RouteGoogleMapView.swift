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
    let selectedMembers: Set<TripMember>
    let selectedMemberOrder: [TripMember]
    let currentMember: TripMember
    let memberOrder: [TripMember]

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var signature = ""
        var numberedMarkers: [NumberedMarker] = []
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
                    assetName: numberedMarker.assetName,
                    number: numberedMarker.number,
                    badgeColor: numberedMarker.badgeColor,
                    scale: scale
                )
            }
        }
    }

    struct NumberedMarker {
        let marker: GMSMarker
        let number: Int
        let assetName: String
        let badgeColor: UIColor
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
        let stopSignature = stops.map { stop in
            let memberSignature = memberOrder
                .filter(stop.members.contains)
                .map(\.rawValue)
                .joined(separator: ",")
            return "\(stop.id):\(stop.order):\(stop.latitude):\(stop.longitude):\(memberSignature)"
        }
        .joined(separator: "|")
        let selectionSignature = memberOrder
            .filter(selectedMembers.contains)
            .map(\.rawValue)
            .joined(separator: ",")
        let selectionOrderSignature = selectedMemberOrder
            .map(\.rawValue)
            .joined(separator: ",")
        let orderSignature = memberOrder.map(\.rawValue).joined(separator: ",")
        let signature = "\(selectionSignature)#\(selectionOrderSignature)#\(currentMember.rawValue)#\(orderSignature)#\(stopSignature)"
        guard signature != coordinator.signature else { return }
        coordinator.signature = signature
        mapView.clear()
        coordinator.numberedMarkers.removeAll()
        coordinator.markerScale = -1

        guard !stops.isEmpty else { return }

        var bounds = GMSCoordinateBounds()
        let orderedSteps = Array(Set(stops.map(\.order))).sorted()
        let numberByOrder = Dictionary(
            uniqueKeysWithValues: orderedSteps.enumerated().map { ($0.element, $0.offset + 1) }
        )

        var stopsByMarker: [RouteMarkerKey: [RouteStop]] = [:]
        var orderedMarkerKeys: [RouteMarkerKey] = []

        for stop in stops {
            let markerKey = RouteMarkerKey(stop: stop)
            if stopsByMarker[markerKey] == nil {
                orderedMarkerKeys.append(markerKey)
            }
            stopsByMarker[markerKey, default: []].append(stop)
        }

        for markerKey in orderedMarkerKeys {
            guard let groupedStops = stopsByMarker[markerKey],
                  let stop = groupedStops.first else { continue }

            let coordinate = coordinate(for: stop)
            bounds = bounds.includingCoordinate(coordinate)

            let marker = GMSMarker(position: coordinate)
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.82)
            marker.map = mapView
            let groupedMembers = groupedStops.reduce(into: Set<TripMember>()) { members, stop in
                members.formUnion(stop.members)
            }
            let style = markerStyle(for: groupedMembers)
            coordinator.numberedMarkers.append(
                NumberedMarker(
                    marker: marker,
                    number: numberByOrder[stop.order, default: 1],
                    assetName: style.assetName,
                    badgeColor: style.badgeColor
                )
            )
        }

        coordinator.updateMarkerScale(for: mapView.camera.zoom)
        drawRoutes(on: mapView)

        mapView.padding = UIEdgeInsets(top: 140, left: 44, bottom: 320, right: 28)
        mapView.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 64))
    }

    private func markerStyle(for members: Set<TripMember>) -> (assetName: String, badgeColor: UIColor) {
        if selectedMembers.isEmpty,
           Set(memberOrder).isSubset(of: members) {
            return ("DDRouteUFONeon", Self.neonMarkerColor)
        }

        let visibleMembers = selectedMembers.isEmpty
            ? members
            : members.intersection(selectedMembers)

        guard let member = representativeMember(
            in: visibleMembers,
            prioritizingRecentSelection: !selectedMembers.isEmpty
        ) else {
            return ("DDRouteUFONeon", Self.neonMarkerColor)
        }

        return (member.routeUFOAssetName, UIColor(member.routeAccentColor))
    }

    private func drawRoutes(on mapView: GMSMapView) {
        guard stops.count > 1 else { return }

        let displayedMembers = selectedMembers.isEmpty
            ? memberOrder
            : selectedMemberOrder.filter(selectedMembers.contains)

        var membersByLeg: [RouteLeg: Set<TripMember>] = [:]
        var coordinatesByLeg: [RouteLeg: (start: CLLocationCoordinate2D, end: CLLocationCoordinate2D)] = [:]
        var orderedLegs: [RouteLeg] = []

        for member in displayedMembers {
            var seenStops: Set<RouteMarkerKey> = []
            let memberStops = stops
                .filter { $0.members.contains(member) }
                .sorted {
                    if $0.order == $1.order {
                        return $0.id < $1.id
                    }
                    return $0.order < $1.order
                }
                .filter { seenStops.insert(RouteMarkerKey(stop: $0)).inserted }

            for (start, end) in zip(memberStops, memberStops.dropFirst()) {
                let leg = RouteLeg(start: start, end: end)
                if membersByLeg[leg] == nil {
                    orderedLegs.append(leg)
                    coordinatesByLeg[leg] = (
                        start: coordinate(for: start),
                        end: coordinate(for: end)
                    )
                }
                membersByLeg[leg, default: []].insert(member)
            }
        }

        if !selectedMembers.isEmpty {
            for leg in orderedLegs {
                guard let coordinates = coordinatesByLeg[leg],
                      let members = membersByLeg[leg],
                      let member = representativeMember(
                        in: members,
                        prioritizingRecentSelection: true
                      ) else { continue }

                drawPolyline(
                    coordinates: [coordinates.start, coordinates.end],
                    color: UIColor(member.routePolylineColor),
                    on: mapView
                )
            }
            return
        }

        for leg in orderedLegs {
            guard let coordinates = coordinatesByLeg[leg],
                  let members = membersByLeg[leg] else { continue }

            if Set(memberOrder).isSubset(of: members) {
                drawPolyline(
                    coordinates: [coordinates.start, coordinates.end],
                    color: Self.neonRouteColor,
                    on: mapView
                )
                continue
            }

            guard let member = representativeMember(
                in: members,
                prioritizingRecentSelection: false
            ) else { continue }
            drawPolyline(
                coordinates: [coordinates.start, coordinates.end],
                color: UIColor(member.routePolylineColor),
                on: mapView
            )
        }
    }

    private func representativeMember(
        in members: Set<TripMember>,
        prioritizingRecentSelection: Bool
    ) -> TripMember? {
        if prioritizingRecentSelection,
           let recentlySelectedMember = selectedMemberOrder.last(where: members.contains) {
            return recentlySelectedMember
        }

        if members.contains(currentMember) {
            return currentMember
        }

        return memberOrder.first(where: members.contains)
    }

    private struct RouteLeg: Hashable {
        let start: RouteCoordinateKey
        let end: RouteCoordinateKey

        init(start: RouteStop, end: RouteStop) {
            self.start = RouteCoordinateKey(stop: start)
            self.end = RouteCoordinateKey(stop: end)
        }
    }

    private struct RouteMarkerKey: Hashable {
        let order: Int
        let coordinate: RouteCoordinateKey

        init(stop: RouteStop) {
            order = stop.order
            coordinate = RouteCoordinateKey(stop: stop)
        }
    }

    private struct RouteCoordinateKey: Hashable {
        private static let precision = 100_000.0

        let latitude: Int
        let longitude: Int

        init(stop: RouteStop) {
            latitude = Int((stop.latitude * Self.precision).rounded())
            longitude = Int((stop.longitude * Self.precision).rounded())
        }
    }

    private func coordinate(for stop: RouteStop) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
    }

    private func drawPolyline(
        coordinates: [CLLocationCoordinate2D],
        color: UIColor,
        on mapView: GMSMapView
    ) {
        let path = GMSMutablePath()
        for coordinate in coordinates {
            path.add(coordinate)
        }

        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = color
        polyline.strokeWidth = 5
        polyline.map = mapView
    }

    fileprivate static func markerImage(
        assetName: String,
        number: Int,
        badgeColor: UIColor,
        scale: CGFloat
    ) -> UIImage? {
        guard let source = UIImage(named: assetName) else { return nil }
        let size = CGSize(width: 36 * scale, height: 72 * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            source.draw(
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: 36 * scale,
                    height: 54 * scale
                )
            )

            let circleRect = CGRect(
                x: 12 * scale,
                y: 60 * scale,
                width: 12 * scale,
                height: 12 * scale
            )
            badgeColor.setFill()
            UIBezierPath(ovalIn: circleRect).fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8 * scale, weight: .medium),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]
            String(number).draw(
                in: CGRect(
                    x: 12 * scale,
                    y: 61 * scale,
                    width: 12 * scale,
                    height: 10 * scale
                ),
                withAttributes: attributes
            )
        }
    }

    private static let neonMarkerColor = UIColor(
        red: 242 / 255,
        green: 1,
        blue: 96 / 255,
        alpha: 1
    )

    private static let neonRouteColor = UIColor(
        red: 182 / 255,
        green: 198 / 255,
        blue: 0,
        alpha: 1
    )

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
