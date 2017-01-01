//
//  ViewController.swift
//  SimpleRendezvous
//
//  Created by Masaaki Uno on 2016/12/26.
//  Copyright © 2016年 Masaaki Uno. All rights reserved.
//

import UIKit
import MapKit
import Firebase

class ViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var latLabel: UILabel!
    @IBOutlet weak var lngLabel: UILabel!

    var dbRef: FIRDatabaseReference!
    fileprivate var locHandle: FIRDatabaseHandle!
    fileprivate var rendezvouseRef: FIRDatabaseReference!
    fileprivate var rendezvouseKey = "";
    fileprivate var uid = "";
    
    // 自分自身の位置情報
    var myLatitude: String = "";
    var myLongitude: String = "";

    // 参加者の位置情報
    var userLocDic: Dictionary = Dictionary<String, Dictionary<String, String>>()

    lazy var locationManager: CLLocationManager = self.makeLocationManager()
    var initMapView: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // FIXME
        FIRAuth.auth()?.signIn(withEmail: "unokun@gmail.com", password: "111111") { (user, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
        }
        uid = (FIRAuth.auth()?.currentUser?.uid)!
        
        configureDatabase()
        rendezvouseKey = makeRendezvouse(uid: uid)
        
        // MapViewの設定
        // ユーザーの移動に合わせて地図の中心地を追従
        mapView.userTrackingMode = MKUserTrackingMode.followWithHeading
        
    }
    
    private func makeLocationManager() -> CLLocationManager {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
        manager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            manager.startUpdatingLocation()
        }
        return manager
    }
    
    private func makeRendezvouse(uid : String) -> String {
        let now = Date() // 現在日時の取得
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "ja_JP") // ロケールの設定
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        rendezvouseRef = self.dbRef.child("rendezvouses").childByAutoId()
        let rendezvousKey = rendezvouseRef.key
        
        var dic: Dictionary<String, String> = Dictionary()
        dic["created_at"] = dateFormatter.string(from: now)
        rendezvouseRef.setValue(dic)

        var userDic: Dictionary<String, Bool> = Dictionary()
        userDic[uid] = true
        let usersRef = self.dbRef.child("rendezvouses/" + rendezvousKey + "/users")
        usersRef.setValue(userDic)

        var locationDic: Dictionary<String, Dictionary<String, String>> = Dictionary()
        var locDic: Dictionary<String, String> = Dictionary()
        locDic["latitude"] = myLatitude
        locDic["longitude"] = myLongitude
        locationDic["unokun"] = locDic

        let locationsRef = self.dbRef.child("rendezvouses/" + rendezvousKey + "/locations")
        locationsRef.setValue(locationDic)
        
        // Listen for new messages in the Firebase database
        locHandle = self.dbRef.child("rendezvouses/" + rendezvousKey + "/locations").observe(.value, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            
            // みんなの位置情報を取得する
            guard let dic: Dictionary = snapshot.value as? Dictionary<String, Dictionary<String, String>> else { return }
            strongSelf.userLocDic = dic
                //            print(snapshot.key)
                //            print(snapshot.value)
                //            print(strongSelf.userLocDic)
            if let myLoc = strongSelf.userLocDic["unokun"] {
                strongSelf.myLatitude = myLoc["latitude"]!
                strongSelf.myLongitude = myLoc["longitude"]!
            }
            
            // アノテーション表示する
            strongSelf.mapView.removeAnnotations(strongSelf.mapView.annotations)
            for (user, loc) in strongSelf.userLocDic {
                let annotation = MKPointAnnotation()
                if let lat = loc["latitude"], let lng = loc["longitude"] {
                    annotation.coordinate.latitude  = atof(lat)
                    annotation.coordinate.longitude  = atof(lng)
                    annotation.title       = user
                    strongSelf.mapView.addAnnotation(annotation)
                }
                
            }
            strongSelf.mapView.showAnnotations(strongSelf.mapView.annotations, animated: true)
            strongSelf.mapView.selectAnnotation(strongSelf.mapView.annotations[0], animated: true)
            
            //            strongSelf.messages.append(snapshot)
            //            strongSelf.clientTable.insertRows(at: [IndexPath(row: strongSelf.messages.count-1, section: 0)], with: .automatic)
        })
        
        return rendezvousKey
    }
    func configureDatabase() {
        dbRef = FIRDatabase.database().reference()
        
//        // Listen for new messages in the Firebase database
//        locHandle = self.dbRef.child("rendezvouses/rendezvous001/locations").observe(.value, with: { [weak self] (snapshot) -> Void in
//            guard let strongSelf = self else { return }
//            
//            // みんなの位置情報を取得する
//            strongSelf.userLocDic = snapshot.value as! Dictionary
////            print(snapshot.key)
////            print(snapshot.value)
////            print(strongSelf.userLocDic)
//            if let myLoc = strongSelf.userLocDic["unokun"] {
//                strongSelf.myLatitude = myLoc["latitude"]!
//                strongSelf.myLongitude = myLoc["longitude"]!
//                
//            }
//            
//            // アノテーション表示する
//            strongSelf.mapView.removeAnnotations(strongSelf.mapView.annotations)
//            for (user, loc) in strongSelf.userLocDic {
//                let annotation = MKPointAnnotation()
//                annotation.coordinate.latitude  = atof(loc["latitude"])
//                annotation.coordinate.longitude  = atof(loc["longitude"])
//                annotation.title       = user
//                strongSelf.mapView.addAnnotation(annotation)
//                
//            }
//            strongSelf.mapView.showAnnotations(strongSelf.mapView.annotations, animated: true)
//            
////            strongSelf.messages.append(snapshot)
////            strongSelf.clientTable.insertRows(at: [IndexPath(row: strongSelf.messages.count-1, section: 0)], with: .automatic)
//        })
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        case .authorizedAlways, .authorizedWhenInUse:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else {
            return
        }
        
        let location:CLLocationCoordinate2D
            = CLLocationCoordinate2DMake(newLocation.coordinate.latitude, newLocation.coordinate.longitude)
        let latitude = "".appendingFormat("%.4f", location.latitude)
        let longitude = "".appendingFormat("%.4f", location.longitude)
        latLabel.text = "latitude: " + latitude
        lngLabel.text = "longitude: " + longitude
        
        let myLocRef: FIRDatabaseReference!
            = self.dbRef.child("rendezvouses/" + rendezvouseKey + "/locations/unokun")
        //        print(myLocRef.key)
        
        // update my location
        if latitude != myLatitude {
            myLocRef.child("latitude").setValue(latitude)
            
        }
        if longitude != myLongitude {
            myLocRef.child("longitude").setValue(longitude)
            
        }
    }
}



