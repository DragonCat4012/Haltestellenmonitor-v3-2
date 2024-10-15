//
//  ConnectionView.swift
//  Haltestellenmonitor1-DD
//
//  Created by Peter Lohse on 19.04.23.
//

import SwiftUI
import CoreLocation

struct ConnectionView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var stopManager: StopManager
    @ObservedObject var viewModel = ConnectionViewModel()   

    var body: some View {
        NavigationStack(path: $stopManager.presentedStops) {
            VStack {
                Form {
                    Section {
                        if favoriteConnections.favorites.count > 0 {
                            DisclosureGroup("Favoriten") {
                                List(favoriteConnections.favorites, id: \.id) { favoriteConnection in
                                    HStack {
                                        Text(favoriteConnection.name)
                                            .swipeActions(edge: .trailing) {
                                                Button {
                                                    favoriteConnections.remove(trip: favoriteConnection)
                                                } label: {
                                                    Label("Löschen", systemImage: "trash")
                                                }
                                                .tint(.red)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.showFavorite(favorite: favoriteConnection)
                                    }
                                }
                            }
                        }
                        HStack {
                            HStack {
                                Text("Startpunkt")
                                    .lineLimit(1)
                                Spacer()
                                Text(filter.startStop == nil ? "Keine Auswahl" : filter.startStop?.displayName ?? "Keine Auswahl")
                                    .foregroundColor(Color.gray)
                                    .lineLimit(1)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                filter.start = true
                                viewModel.showingSheet = true
                            }

                            Button {
                                locationManager.requestCurrentLocationComplete {
                                    locationManager.lookUpCurrentLocation { placemark in
                                        if placemark != nil {
                                            filter.startStop = ConnectionStop(displayName: "\(placemark?.name ?? ""), \(placemark?.postalCode ?? "") \(placemark?.locality ?? "")", location: StopCoordinate(latitude: locationManager.location?.latitude ?? 0, longitude: locationManager.location?.longitude ?? 0))
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "location")
                            }
                        }

                        HStack {
                            HStack {
                                Text("Zielpunkt")
                                    .lineLimit(1)
                                Spacer()
                                Text(filter.endStop == nil ? "Keine Auswahl" : filter.endStop?.displayName ?? "Keine Auswahl")
                                    .foregroundColor(Color.gray)
                                    .lineLimit(1)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                filter.start = false
                                viewModel.showingSheet = true
                            }

                            Button {
                                locationManager.requestCurrentLocationComplete {
                                    locationManager.lookUpCurrentLocation { placemark in
                                        if placemark != nil {
                                            filter.endStop = ConnectionStop(displayName: "\(placemark?.name ?? ""), \(placemark?.postalCode ?? "") \(placemark?.locality ?? "")", location: StopCoordinate(latitude: locationManager.location?.latitude ?? 0, longitude: locationManager.location?.longitude ?? 0))
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "location")
                            }
                        }
                        
                        DisclosureGroup("Verkehrsmittel") {
                            DepartureDisclosureSection()
                        }
                        
                        VStack {
                            HStack {
                                DatePicker("Zeit", selection: $viewModel.dateTime)
                                Button {
                                    viewModel.dateTime = Date.now
                                } label: {
                                    Text("Jetzt")
                                }
                            }
                            Picker("", selection: $isArrivalTime) {
                                Text("Abfahrt").tag(0)
                                Text("Ankunft").tag(1)
                            }.pickerStyle(.segmented)
                        }
                        
                        Button {
                            Task {
                                if isLoading {
                                    return
                                }
                                isLoading = true
                                await viewModel.createRequestData()
                                await viewModel.getTripData()
                            }
                        } label: {
                            Text("Verbindungen anzeigen")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    if (trip?.Routes != nil) {
                        Button {
                            showingSaveAlert.toggle()
                        } label: {
                            Text("Als Favorit speichern")
                        }
                        .frame(maxWidth: .infinity)
                        
                        ForEach(trip?.Routes ?? [], id: \.self) { route in
                            TripSection(vm: TripSectionViewModel(route: route))
                        }
                        
                        Button {
                            if isLoading || requestData == nil || self.trip == nil {
                                return
                            }
                            isLoading = true
                            numbernext = numbernext + 1
                            
                            requestData!.sessionId = self.trip!.SessionId
                            requestData!.numberprev = 0
                            requestData!.numbernext = numbernext
                            
                            Task {
                                await viewModel.getTripData(isNext: true)
                            }
                        } label: {
                            Text("später")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .sheet(isPresented: $viewModel.showingSheet, content: {
                    ConnectionStopSelectionView()
                })
            }
            .navigationTitle("🏘️ Verbindungen")
            .toolbar {
                ToolbarItem(placement: ToolbarItemPlacement.cancellationAction) {
                    if (isLoading) {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: ToolbarItemPlacement.confirmationAction) {
                    Button("Zurücksetzen") {
                        if (isLoading) {
                            return
                        }
                        filter.startStop = nil
                        filter.endStop = nil
                        trip = nil
                        requestData = nil
                        numbernext = 0
                        viewModel.dateTime = Date.now
                    }
                }
            }
            .alert("Es muss ein Start- und Endziel ausgewählt werden", isPresented: $viwModel.showingAlert) {
                Button {
                    isLoading = false
                } label: {
                    Text("OK")
                }
            }
            .alert("Wie soll der Favorit gespeichert werden?", isPresented: $showingSaveAlert) {
                TextField("Name", text: $favoriteName)
                Button {
                    viewModel.saveFavorite()
                } label: {
                    Text("OK")
                }
            }
            .navigationDestination(for: Stop.self) { stop in
                DepartureView(stop: stop)
            }
        }
        .environmentObject(filter)
        .environmentObject(departureFilter)
    }
}

struct ConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionView(trip: tripTmp)
            .environmentObject(LocationManager())
            .environmentObject(StopManager())
    }
}
