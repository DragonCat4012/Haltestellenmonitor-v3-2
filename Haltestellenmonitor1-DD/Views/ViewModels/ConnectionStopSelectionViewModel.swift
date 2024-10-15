//
//  ConnectionStopSelectionViewModel.swift
//  Haltestellenmonitor1-DD
//
//  Created by Kiara on 15.10.24.
//

import UIKit
import SwiftUI
import CoreLocation
import Contacts

class ConnectionStopSelectionViewModel: ObservableObject {
    @Published  var searchText = ""
    @Published  var placemarks: [CLPlacemark] = []
    @Published  var location: CLLocation?
    @Published  var addressString = ""
    @Published  var showPicker = false
    
    @Published  var showNoAddressAlert = false
    @Published  var contactName = ""
    @Published  var addresses: [CNLabeledValue<CNPostalAddress>] = []
    
    func changePlace() {
        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(searchText) { (placemarks, error) in
            guard
                let placemarks = placemarks,
                let location = placemarks.first?.location
            else {
                return
            }
            
            self.placemarks = placemarks
            self.location = location
            
            if placemarks.first != nil {
                self.addressString = "\(placemarks.first?.name ?? ""), \(placemarks.first?.postalCode ?? "") \(placemarks.first?.locality ?? "")"
            } else {
                self.addressString = ""
            }
        }
    }
    
    func selectContact(contact: CNContact) {
        if contact.givenName == "" && contact.familyName == "" && contact.organizationName != "" {
            contactName = contact.organizationName
        } else {
            contactName = "\(contact.givenName) \(contact.familyName)"
        }
        
        if contact.postalAddresses.count <= 0 {
            addresses = []
            showNoAddressAlert.toggle()
            return
        }
        
        if contact.postalAddresses.count == 1 {
            selectContactAddress(address: contact.postalAddresses.first!.value)
            return
        }
        
        addresses = contact.postalAddresses
    }
    
    func selectContactAddress(address: CNPostalAddress) {
        let addressStr = "\(address.street), \(address.postalCode) \(address.city)"
        
        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(addressStr) { (placemarks, error) in
            guard
                let placemarks = placemarks,
                let location = placemarks.first?.location
            else {
                return
            }
            
            if (filter.start) {
                filter.startStop = ConnectionStop(displayName: contactName, location: StopCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude ))
            } else {
                filter.endStop = ConnectionStop(displayName: contactName, location: StopCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
                
                if filter.startStop == nil {
                    locationManager.requestCurrentLocationComplete {
                        locationManager.lookUpCurrentLocation { placemark in
                            if placemark != nil {
                                filter.startStop = ConnectionStop(displayName: "\(placemark?.name ?? ""), \(placemark?.postalCode ?? "") \(placemark?.locality ?? "")", location: StopCoordinate(latitude: locationManager.location?.latitude ?? 0, longitude: locationManager.location?.longitude ?? 0))
                            }
                        }
                    }
                }
            }
            dismiss()
        }
    }
}
