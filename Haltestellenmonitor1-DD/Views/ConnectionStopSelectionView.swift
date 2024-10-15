//
//  ConnectionStopSelectionView.swift
//  Haltestellenmonitor1-DD
//
//  Created by Peter Lohse on 19.04.23.
//

import SwiftUI
import CoreLocation
import Contacts

struct ConnectionStopSelectionView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var favoriteStops: FavoriteStop
    @EnvironmentObject var filter: ConnectionFilter
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel = ConnectionStopSelectionViewModel()
   
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if viewModel.addressString != "" {
                        HStack {
                            Text("🏘️ \(viewModel.addressString)")
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if (filter.start) {
                                filter.startStop = ConnectionStop(displayName: viewModel.addressString, location: StopCoordinate(latitude: viewModel.location?.coordinate.latitude ?? 0, longitude: viewModel.location?.coordinate.longitude ?? 0))
                            } else {
                                filter.endStop = ConnectionStop(displayName: viewModel.addressString, location: StopCoordinate(latitude: viewModel.location?.coordinate.latitude ?? 0, longitude: viewModel.location?.coordinate.longitude ?? 0))
                            }
                            dismiss()
                        }
                    }
                    HStack {
                        if viewModel.contactName != "" {
                            Text("📒 \(viewModel.contactName)")
                                .lineLimit(1)
                        } else {
                            Text("📒 Kontakt auswählen")
                                .foregroundColor(Color.gray)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.showPicker.toggle()
                    }
                }
                if viewModel.addresses.count > 0 {
                    Section(header: Text("Kontakt-Adressen")) {
                        List(viewModel.addresses, id: \.self) { labeledAddress in
                            HStack {
                                Text("\(labeledAddress.value.street), \(labeledAddress.value.postalCode) \(labeledAddress.value.city)")
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectContactAddress(address: labeledAddress.value)
                            }
                        }
                    }
                }
                Section(header: Text("Haltestellen")) {
                    List(searchResults, id: \.self) { stop in
                        StopRow(stop: stop)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if (filter.start) {
                                    filter.startStop = ConnectionStop(displayName: stop.getFullName(), stop: stop)
                                } else {
                                    filter.endStop = ConnectionStop(displayName: stop.getFullName(), stop: stop)
                                }
                                dismiss()
                            }
                    }
                }
            }
            .navigationTitle(filter.start ? "🏠 Startpunkt" : "🏠 Zielpunkt")
            .searchable(text: $viewModel.searchText, placement:.navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: ToolbarItemPlacement.cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: ToolbarItemPlacement.confirmationAction) {
                    Button {
                        locationManager.requestCurrentLocation()
                    } label: {
                        Label("", systemImage: "location")
                    }
                }
            }
        }
        .dynamicTypeSize(.medium ... .large)
        .task(id: viewModel.searchText) {
            viewModel.changePlace()
        }
        .alert("Bei diesem Kontakt ist keine Adresse hinterlegt.", isPresented: $viewModel.showNoAddressAlert) {
            Button {
                // do nothing
            } label: {
                Text("OK")
            }
        }
        .sheet(isPresented: $viewModel.showPicker) {
            ContactPicker { result in
                switch result {
                case .selectedContact(let contact):
                    viewModel.selectContact(contact: contact)
                case .cancelled:
                    // Handle cancellation
                    break
                }
            }
                .dynamicTypeSize(.medium ... .large)
        }
    }
    
    var searchResults: [Stop] {
        stops = stops.sorted {
            $0.distance ?? 0 < $1.distance ?? 0
        }
        
        var newStops: [Stop] = []
        stops.forEach { stop in
            if (favoriteStops.isFavorite(stopID: stop.stopID)) {
                newStops.append(stop)
            }
        }
        stops.forEach { stop in
            if (!favoriteStops.isFavorite(stopID: stop.stopID)) {
                newStops.append(stop)
            }
        }
        stops = newStops
        
        if viewModel.searchText.isEmpty {
            return stops
        } else {
            return stops.filter { $0.name.lowercased().contains(viewModel.searchText.lowercased()) }
        }
    }
    
}

struct ConnectionStopSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionStopSelectionView()
            .environmentObject(LocationManager())
            .environmentObject(FavoriteStop())
            .environmentObject(ConnectionFilter())
    }
}
