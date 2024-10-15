//
//  ConnectionViewModel.swift
//  Haltestellenmonitor1-DD
//
//  Created by Kiara on 15.10.24.
//

import UIKit
import SwiftUI

class ConnectionViewModel: ObservableObject {
    @Published var day = ""
    @Published var showingSheet = false
    @Published var showingAlert = false
    @Published var showingSaveAlert = false
    @Published var dateTime = Date.now
    @Published var isArrivalTime = 0 // false
    @Published var trip: Trip? = nil
    @Published var isLoading = false
    @Published private var requestData: TripRequest?
    @Published private var numberprev = 0
    @Published private var numbernext = 0
    @Published private var favoriteName = ""
    @Published var filter: ConnectionFilter = ConnectionFilter()
    @Published var departureFilter = DepartureFilter()
    @Published var favoriteConnections = FavoriteConnection()

     func createRequestData() async {
        if (filter.startStop == nil || filter.endStop == nil) {
            showingAlert = true
            return
        }
        let standardSettings = getStandardSettings()
        
        async let startStrPromise = filter.startStop!.getDestinationString()
        async let endStrPromise = filter.endStop!.getDestinationString()
        
        let startStr = await startStrPromise
        let endStr = await endStrPromise
        
        requestData = TripRequest(time: dateTime.ISO8601Format(),isarrivaltime: isArrivalTime == 1 , origin: startStr, destination: endStr, standardSettings: standardSettings)
    }
    
    func getTripData(isNext: Bool = false) async {
        if requestData == nil {
            return
        }

        var url = URL(string: "https://webapi.vvo-online.de/tr/trips")!
        if isNext {
            url = URL(string: "https://webapi.vvo-online.de/tr/prevnext")!
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(requestData)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Haltestellenmonitor Dresden v2", forHTTPHeaderField: "User-Agent")

        do {
            let (content, _) = try await URLSession.shared.data(for: request)

            let decoder = JSONDecoder()
            numbernext = 0
            self.trip = try decoder.decode(Trip.self, from: content)

            isLoading = false
        } catch {
            print ("error: \(error)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Task {
                    await self.getTripData(isNext: isNext)
                }
            }
        }
    }
    
    func getStandardSettings() -> TripStandardSettings {
        var mot: [String] = []
        if (departureFilter.tram) {
            mot.append("Tram")
        }
        if (departureFilter.bus) {
            mot.append("CityBus")
            mot.append("IntercityBus")
            mot.append("PlusBus")
        }
        if (departureFilter.suburbanRailway) {
            mot.append("SuburbanRailway")
        }
        if (departureFilter.train) {
            mot.append("Train")
        }
        if (departureFilter.cableway) {
            mot.append("Cableway")
        }
        if (departureFilter.ferry) {
            mot.append("Ferry")
        }
        if (departureFilter.taxi) {
            mot.append("HailedSharedTaxi")
        }
        
        return TripStandardSettings(mot: mot)
    }
    
    @MainActor func saveFavorite() {
        let standardSettings = getStandardSettings()
        
        if favoriteName.isEmpty {
            favoriteName = "Standard"
        }

        let requestShort = TripRequestShort(name: favoriteName, origin: filter.startStop!, destination: filter.endStop!, standardSettings: standardSettings)
        
        favoriteName = ""
        
        favoriteConnections.add(trip: requestShort)
    }

    func showFavorite(favorite: TripRequestShort) {
        filter.startStop = favorite.origin
        filter.endStop = favorite.destination
        
        departureFilter.tram = false
        departureFilter.bus = false
        departureFilter.suburbanRailway = false
        departureFilter.train = false
        departureFilter.cableway = false
        departureFilter.ferry = false
        departureFilter.taxi = false
        
        let mots = favorite.standardSettings?.mot ?? []
        for mot in mots {
            switch mot {
            case "Tram":
                departureFilter.tram = true
                break
            case "CityBus":
                departureFilter.bus = true
                break
            case "IntercityBus":
                departureFilter.bus = true
                break
            case "PlusBus":
                departureFilter.bus = true
                break
            case "SuburbanRailway":
                departureFilter.suburbanRailway = true
                break
            case "Train":
                departureFilter.train = true
                break
            case "Cableway":
                departureFilter.cableway = true
                break
            case "Ferry":
                departureFilter.ferry = true
                break
            case "HailedSharedTaxi":
                departureFilter.taxi = true
                break
            default:
                break
            }
        }
        
        dateTime = Date.now
        
        Task {
            if isLoading {
                return
            }
            isLoading = true
            await createRequestData()
            await getTripData()
        }
    }
}
